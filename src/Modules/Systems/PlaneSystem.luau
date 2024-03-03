local CollectionService: CollectionService = game:GetService("CollectionService")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plane = require(ReplicatedStorage.Modules.Classes.Plane)
local SmokeEmitter = require(ReplicatedStorage.Modules.Libraries.SmokeEmitter)
local MathExtensions = require(ReplicatedStorage.Modules.Libraries.MathExtensions)

local PlaneSystem = {}
PlaneSystem.__index = PlaneSystem

PlaneSystem.Planes = {} :: { Plane.Plane }

PlaneSystem.TAG_NAME = "Plane" :: string
PlaneSystem.MAX_FORWARD_SPEED = 100 :: number

PlaneSystem.CAMERA_OFFSET = Vector3.new(0, 5, 14)

PlaneSystem.DEFAULT_CAMERA_FOV = workspace.CurrentCamera.FieldOfView
PlaneSystem.MAX_ADDITIONAL_FOV = 10 :: number
PlaneSystem.MINIMUM_CAMERA_FOV = workspace.CurrentCamera.FieldOfView - 10 :: number

PlaneSystem.SELF_DETONATE_TIME = 10 :: number

PlaneSystem.CurrentPlane = nil :: Plane.Plane?

PlaneSystem.CurrentForwardSpeed = 0.0 :: number
PlaneSystem.CurrentThrust = 0.0 :: number -- forward speed from vehicleseat translated to plane pitch
PlaneSystem.CurrentSteer = 0.0 :: number -- side speed from vehicleseat translated to yaw/roll

PlaneSystem.HumanoidSeatedConnection = nil :: RBXScriptConnection?

PlaneSystem.ServerHeartbeatConnection = nil :: RBXScriptConnection?
PlaneSystem.ClientHeartbeatConnection = nil :: RBXScriptConnection?

local IS_SERVER = RunService:IsServer()
local FREEZE_INPUT_ACTION = "freezeInput"

local localPlayer: Player = Players.LocalPlayer
local playerWasInPlaneSeat: boolean = false

local nextCameraCFrame: CFrame = CFrame.new()

local initialY: number = 0.0

function PlaneSystem:InitializeServer(): boolean
	for _, planeInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		self:OnPlaneAdded(planeInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(planeInstance: Instance)
		self:OnPlaneAdded(planeInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(planeInstance: Instance)
		self:OnPlaneRemoved(planeInstance :: Model)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

			humanoid.Seated:Connect(function(active: boolean, seatPart: Seat | VehicleSeat)
				self:SetSeatNetworkOwner(active, seatPart, player)
			end)
		end)
	end)

	self.ServerHeartbeatConnection = RunService.Heartbeat:Connect(function(_dt: number)
		for k: Model, v: Plane.Plane in pairs(self.Planes) do
			if v.selfDetonateEnabled == false then
				continue
			end

			if v.planeSeat.Occupant ~= nil then
				v.startTickTime = tick()
			else
				v.selfDetonateTimerValue.Value = tick() - v.startTickTime
				if v.selfDetonateTimerValue.Value >= self.SELF_DETONATE_TIME then
					k:RemoveTag(self.TAG_NAME)
				end
			end
		end
	end)

	return true
end

function PlaneSystem:InitializeClient(): boolean
	for _, planeInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		self:OnPlaneAdded(planeInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(planeInstance: Instance)
		self:OnPlaneAdded(planeInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(planeInstance: Instance)
		self:OnPlaneRemoved(planeInstance :: Model)
	end)

	local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

	self.HumanoidSeatedConnection = humanoid.Seated:Connect(function(active: boolean, seatPart: Seat | VehicleSeat)
		self:OnHumanoidSeated(active, seatPart)
	end)

	return true
end

function PlaneSystem:OnPlaneAdded(planeInstance: Model)
	local planeObject: Plane.Plane = Plane.new(planeInstance, false)
	self.Planes[planeInstance] = planeObject
end

function PlaneSystem:OnPlaneRemoved(planeInstance: Model)
	if planeInstance == nil then
		return
	end

	if IS_SERVER then
		SmokeEmitter:EmitSmoke(planeInstance:GetPivot().Position)
		planeInstance:Destroy()
	end

	self.Planes[planeInstance] = nil
end

function PlaneSystem:OnHumanoidSeated(active: boolean, seatPart: VehicleSeat): ()
	if
		active
		and (seatPart.Parent.Parent ~= nil and seatPart.Parent.Parent:HasTag("Plane"))
		and (seatPart:IsA("VehicleSeat") and seatPart.Name == "PlaneSeat")
	then
		playerWasInPlaneSeat = true

		self:StartVehicle(seatPart)

		self.ClientHeartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
			self:OnHeartbeat(dt)
		end)

		self.CurrentPlane.planeSeat.Changed:Connect(function(property: string)
			self:OnPlaneSeatChanged(property)
		end)
	elseif not active and playerWasInPlaneSeat == true then
		self:StopVehicle()
	end
end

function PlaneSystem:StartVehicle(seatPart: VehicleSeat)
	local planeModel: Model = seatPart.Parent.Parent
	local planeObject: Plane.Plane = self.Planes[planeModel]

	self.CurrentPlane = planeObject

	local _X, Y, _Z = planeModel:GetPivot():ToOrientation()
	initialY = Y

	self.CurrentPlane.alignOrientation.Enabled = true
	self.CurrentPlane.alignOrientation.CFrame = CFrame.fromOrientation(0, initialY, 0)

	self.CurrentPlane.alignOrientation.MaxTorque = math.huge
	self.CurrentPlane.linearVelocity.MaxForce = math.huge

	local startTurningTween: Tween =
		TweenService:Create(self.CurrentPlane.hingeConstraint, TweenInfo.new(2), { AngularVelocity = 25.0 })
	startTurningTween:Play()

	self:FreezePlayerInput()

	-- set up camera
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

	local FovTween: Tween = TweenService:Create(
		workspace.CurrentCamera,
		TweenInfo.new(0.55, Enum.EasingStyle.Quart),
		{ FieldOfView = self.MINIMUM_CAMERA_FOV }
	)
	FovTween:Play()

	nextCameraCFrame = CFrame.fromEulerAnglesXYZ(self.CurrentPlane.planeSeat.CFrame:ToEulerAnglesXYZ())
		* CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0)
		* CFrame.new(self.CAMERA_OFFSET)

	local cameraTween: Tween =
		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {
			CFrame = self.CurrentPlane.planeSeat.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0) * CFrame.new(
				self.CAMERA_OFFSET
			),
		})

	cameraTween:Play()
	cameraTween.Completed:Connect(function(_)
		self:UnfreezePlayerInput()
	end)

	cameraTween.Completed:Wait()
end

function PlaneSystem:StopVehicle()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

	local FovTween: Tween = TweenService:Create(
		workspace.CurrentCamera,
		TweenInfo.new(0.55, Enum.EasingStyle.Quart),
		{ FieldOfView = self.DEFAULT_CAMERA_FOV }
	)
	FovTween:Play()

	-- reset to previous camera distance
	-- quite hacky but apparently theres no other solution
	localPlayer.CameraMinZoomDistance -= 0.1
	localPlayer.CameraMinZoomDistance += 0.1

	playerWasInPlaneSeat = false

	if self.ClientHeartbeatConnection ~= nil then
		self.ClientHeartbeatConnection:Disconnect()
		self.ClientHeartbeatConnection = nil
	end

	local _X, Y, _Z = self.CurrentPlane.alignOrientation.CFrame:ToWorldSpace(CFrame.new()):ToOrientation()

	self.CurrentPlane.alignOrientation.Enabled = false
	self.CurrentPlane.alignOrientation.CFrame = CFrame.new() * CFrame.fromOrientation(0, Y, 0)

	self.CurrentPlane.linearVelocity.MaxForce = 0.0
	self.CurrentPlane.linearVelocity.VectorVelocity = Vector3.zero

	self.CurrentForwardSpeed, self.CurrentThrust, self.CurrentSteer = 0.0, 0.0, 0.0

	local stopRotatingTween: Tween =
		TweenService:Create(self.CurrentPlane.hingeConstraint, TweenInfo.new(2), { AngularVelocity = 0.0 })
	stopRotatingTween:Play()

	if self.CurrentPlane ~= nil then
		self.CurrentPlane = nil
	end
end

function PlaneSystem:OnHeartbeat(dt: number)
	-- handle velocity and stuff
	self.CurrentThrust += (self.CurrentPlane.planeSeat.ThrottleFloat / 1.5) * dt
	self.CurrentSteer -= self.CurrentPlane.planeSeat.SteerFloat * 1 * dt

	if self.CurrentForwardSpeed < self.MAX_FORWARD_SPEED then
		self.CurrentForwardSpeed += 30 * dt
	else
		self.CurrentForwardSpeed = self.MAX_FORWARD_SPEED
	end

	self.CurrentPlane.linearVelocity.VectorVelocity = Vector3.new(0, 0, -self.CurrentForwardSpeed)

	self.CurrentPlane.alignOrientation.CFrame = CFrame.fromOrientation(
		self.CurrentThrust,
		initialY + self.CurrentSteer,
		self.CurrentPlane.cosmeticSteerValue.Value
	)

	-- change fov based on velocity
	local additionalFov: number =
		MathExtensions:Remap(0, 60.0, 0, self.MAX_ADDITIONAL_FOV, self.CurrentPlane.planeSeat.Velocity.Magnitude)

	workspace.CurrentCamera.FieldOfView =
		MathExtensions:Lerp(workspace.CurrentCamera.FieldOfView, self.MINIMUM_CAMERA_FOV + additionalFov, dt * 8.0)

	-- update camera cframe
	local smallerRemappedVelocity: number =
		MathExtensions:Remap(0, self.MAX_FORWARD_SPEED, 0, 1, self.CurrentPlane.planeSeat.Velocity.Magnitude)
	local X, Y, Z: number = self.CurrentPlane.planeSeat.CFrame:ToEulerAnglesXYZ()

	local rawCameraCFrame = CFrame.fromEulerAnglesXYZ(X, Y, Z)
		* CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0)
		* CFrame.new(self.CAMERA_OFFSET)
	nextCameraCFrame = nextCameraCFrame:Lerp(rawCameraCFrame, dt * 5.0)

	workspace.CurrentCamera.CFrame = CFrame.new(self.CurrentPlane.planeSeat.CFrame.Position)
		* CFrame.new(Vector3.new(0, smallerRemappedVelocity, 0))
		* nextCameraCFrame
end

function PlaneSystem:OnPlaneSeatChanged(property: string)
	if property == "SteerFloat" then
		local planeTurningTween: Tween = TweenService:Create(
			self.CurrentPlane.cosmeticSteerValue,
			TweenInfo.new(1),
			{ Value = -self.CurrentPlane.planeSeat.SteerFloat / 2 }
		)
		planeTurningTween:Play()
	end
end

function PlaneSystem:SetSeatNetworkOwner(_active: boolean, seatPart: VehicleSeat, player: Player)
	if seatPart == nil then
		return
	end
	if not seatPart:IsA("VehicleSeat") and seatPart.Name ~= "PlaneSeat" then
		return
	end

	seatPart:SetNetworkOwner(player)
end

function PlaneSystem:FreezePlayerInput()
	ContextActionService:BindAction(FREEZE_INPUT_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, unpack(Enum.PlayerActions:GetEnumItems()))
end

function PlaneSystem:UnfreezePlayerInput()
	ContextActionService:UnbindAction(FREEZE_INPUT_ACTION)
end

return PlaneSystem

local CollectionService: CollectionService = game:GetService("CollectionService")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local Players: Players = game:GetService("Players")

local SmokeEmitter = require(ReplicatedStorage.Modules.Libraries.SmokeEmitter)
local MathExtensions = require(ReplicatedStorage.Modules.Libraries.MathExtensions)
local Car = require(ReplicatedStorage.Modules.Classes.Car)

local CarSystem = {}
CarSystem.__index = CarSystem

CarSystem.Cars = {} :: { Car.Car }

CarSystem.TAG_NAME = "Car"

CarSystem.DEFAULT_CAMERA_FOV = workspace.CurrentCamera.FieldOfView
CarSystem.MAXIMUM_ADDITIONAL_FOV = 15 :: number
CarSystem.MINIMUM_CAMERA_FOV = workspace.CurrentCamera.FieldOfView - 10 :: number

CarSystem.CAMERA_OFFSET = Vector3.new(1.638, 5, 14)

CarSystem.SIN_TIME_MULTIPLIER = 1.5 -- basically decides how fast the shaking is
CarSystem.SIN_TIME_DIVIDER = 1.5 -- the higher it is, the less intense it is

CarSystem.SELF_DETONATE_TIME = 10 :: number

CarSystem.WHEEL_STEER_TIME = 0.5 :: number

CarSystem.CurrentCar = nil :: Car.Car?

CarSystem.HumanoidSeatedConnection = nil :: RBXScriptConnection?
CarSystem.ServerHeartbeatConnection = nil :: RBXScriptConnection?
CarSystem.ClientHeartbeatConnection = nil :: RBXScriptConnection?

local IS_SERVER: boolean = RunService:IsServer()
local FREEZE_INPUT_ACTION: string = "freezeInput"

local localPlayer: Player = Players.LocalPlayer
local nextCameraCFrame: CFrame = CFrame.new()

local storedSmokePart: BasePart? = nil

local particleEmitterEvent: RemoteEvent =
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ParticleEmitterEvent") :: RemoteEvent

function CarSystem:InitializeServer(): boolean
	for _, carInstance: Instance in ipairs(CollectionService:GetTagged(CarSystem.TAG_NAME)) do
		self:OnCarAdded(carInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(carInstance: Instance)
		self:OnCarAdded(carInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(carInstance: Instance)
		self:OnCarRemoved(carInstance :: Model)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

			humanoid.Seated:Connect(function(active: boolean, seatPart: Seat | VehicleSeat)
				self:SetSeatNetworkOwner(active, seatPart, player)
			end)
		end)
	end)

	particleEmitterEvent.OnServerEvent:Connect(function(player: Player, smokePart: BasePart, active: boolean)
		self:OnParticleEmitterEvent(player, smokePart, active)
	end)

	self.ServerHeartbeatConnection = RunService.Heartbeat:Connect(function(_dt: number)
		for k: Model, v: Car.Car in pairs(self.Cars) do
			if v.selfDetonateEnabled == false then
				continue
			end

			if v.carSeat.Occupant ~= nil then
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

function CarSystem:InitializeClient(): boolean
	for _, carInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		self:OnCarAdded(carInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(carInstance: Instance)
		self:OnCarAdded(carInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(carInstance: Instance)
		self:OnCarRemoved(carInstance :: Model)
	end)

	local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

	self.HumanoidSeatedConnection = humanoid.Seated:Connect(function(active: boolean, seatPart: Seat | VehicleSeat)
		self:OnHumanoidSeated(active, seatPart)
	end)

	return true
end

function CarSystem:OnCarAdded(carInstance: Model): ()
	local carObject: Car.Car = Car.new(carInstance, false)
	self.Cars[carInstance] = carObject
end

function CarSystem:OnCarRemoved(carInstance: Model): ()
	if carInstance == nil then
		return
	end

	if IS_SERVER then
		SmokeEmitter:EmitSmoke(carInstance:GetPivot().Position)
		carInstance:Destroy()
	end

	self.Cars[carInstance] = nil
end

function CarSystem:OnHumanoidSeated(active: boolean, seatPart: VehicleSeat): ()
	if
		active
		and (seatPart.Parent.Parent ~= nil and seatPart.Parent.Parent:HasTag("Car"))
		and (seatPart:IsA("VehicleSeat") and seatPart.Name == "CarSeat")
	then
		self:StartVehicle(seatPart)

		self.ClientHeartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
			self:OnHeartbeat(dt)
		end)

		self.CurrentCar.carSeat.Changed:Connect(function(property: string)
			self:OnCarSeatChanged(property)
		end)
	elseif not active then
		self:StopVehicle()
	end
end

function CarSystem:StartVehicle(seatPart: VehicleSeat)
	local carModel: Instance = seatPart.Parent.Parent
	local carObject: Car.Car = self.Cars[carModel]

	self.CurrentCar = carObject
	storedSmokePart = self.CurrentCar.smokePart

	particleEmitterEvent:FireServer(storedSmokePart, true)

	self:FreezePlayerInput()

	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

	local FovTween: Tween = TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.55,Enum.EasingStyle.Quart), { FieldOfView = self.MINIMUM_CAMERA_FOV })
	FovTween:Play()

	nextCameraCFrame = CFrame.fromEulerAnglesXYZ(self.CurrentCar.carSeat.CFrame:ToEulerAnglesXYZ())
		* CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0)
		* CFrame.new(self.CAMERA_OFFSET)

	local cameraTween: Tween =
		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.55, Enum.EasingStyle.Quart), {
			CFrame = self.CurrentCar.carSeat.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0) * CFrame.new(
				self.CAMERA_OFFSET - Vector3.new(0, 1, 0)
			),
		})

	cameraTween:Play()
	cameraTween.Completed:Connect(function(_)
		self:UnfreezePlayerInput()
	end)

	cameraTween.Completed:Wait()
end

function CarSystem:StopVehicle()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	
	local FovTween: Tween = TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.35,Enum.EasingStyle.Quart), { FieldOfView = self.DEFAULT_CAMERA_FOV })
	FovTween:Play()

	-- reset to previous camera distance
	-- quite hacky but apparently theres no other solution
	localPlayer.CameraMinZoomDistance -= 0.1
	localPlayer.CameraMinZoomDistance += 0.1

	if self.ClientHeartbeatConnection ~= nil then
		self.ClientHeartbeatConnection:Disconnect()
		self.ClientHeartbeatConnection = nil
	end

	if self.CurrentCar ~= nil then
		self.CurrentCar = nil
	end

	if storedSmokePart ~= nil then
		particleEmitterEvent:FireServer(storedSmokePart, false)
		storedSmokePart = nil
	end
end

function CarSystem:OnHeartbeat(dt: number)
	local largerRemappedVelocity: number = MathExtensions:Remap(
		0,
		self.CurrentCar.carSeat.MaxSpeed,
		0,
		self.MAXIMUM_ADDITIONAL_FOV,
		self.CurrentCar.carSeat.AssemblyLinearVelocity.Magnitude
	)
	workspace.CurrentCamera.FieldOfView = MathExtensions:Lerp(
		workspace.CurrentCamera.FieldOfView,
		self.MINIMUM_CAMERA_FOV + largerRemappedVelocity,
		dt * 8.0
	)

	local smallerRemappedVelocity: number = MathExtensions:Remap(
		0,
		self.CurrentCar.carSeat.MaxSpeed,
		0,
		1,
		self.CurrentCar.carSeat.AssemblyLinearVelocity.Magnitude
	)
	local X, Y, Z: number = self.CurrentCar.carSeat.CFrame:ToEulerAnglesXYZ()

	local rawCameraCFrame = CFrame.fromEulerAnglesXYZ(X, Y, Z)
		* CFrame.fromEulerAnglesXYZ(math.rad(-15), 0, 0)
		* CFrame.new(self.CAMERA_OFFSET)
	nextCameraCFrame = nextCameraCFrame:Lerp(rawCameraCFrame, dt * 10.0)

	workspace.CurrentCamera.CFrame = CFrame.new(self.CurrentCar.carSeat.CFrame.Position)
		* CFrame.new(
			Vector3.new(
				0,
				((math.sin(tick() * self.SIN_TIME_MULTIPLIER)) / self.SIN_TIME_DIVIDER * smallerRemappedVelocity),
				0
			)
		)
		* nextCameraCFrame
end

function CarSystem:OnCarSeatChanged(property: string)
	if property == "SteerFloat" then -- left and right
		local orientation: Vector3 =
			Vector3.new(0, -self.CurrentCar.carSeat.SteerFloat * self.CurrentCar.carSeat.TurnSpeed, 90)

		TweenService:Create(
			self.CurrentCar.frontLeftCarAttachment,
			TweenInfo.new(self.WHEEL_STEER_TIME),
			{ Orientation = orientation }
		):Play()
		TweenService:Create(
			self.CurrentCar.frontRightCarAttachment,
			TweenInfo.new(self.WHEEL_STEER_TIME),
			{ Orientation = orientation }
		):Play()
	elseif property == "ThrottleFloat" then -- forward and backward
		local torque: number = math.abs(self.CurrentCar.carSeat.ThrottleFloat) * self.CurrentCar.carSeat.Torque

		if torque == 0.0 then
			torque = 2000.0
		end

		local backLeftCylindricalConstraint: CylindricalConstraint =
			self.CurrentCar.backLeftWheel:WaitForChild("CylindricalConstraint")
		local backRightCylindricalConstraint: CylindricalConstraint =
			self.CurrentCar.backRightWheel:WaitForChild("CylindricalConstraint")

		local angularVelocity: number = math.sign(self.CurrentCar.carSeat.ThrottleFloat)
			* (self.CurrentCar.carSeat.MaxSpeed / (self.CurrentCar.backRightWheel.Size.Y / 2))

		backLeftCylindricalConstraint.MotorMaxTorque = torque
		backRightCylindricalConstraint.MotorMaxTorque = torque

		backLeftCylindricalConstraint.AngularVelocity = angularVelocity
		backRightCylindricalConstraint.AngularVelocity = angularVelocity
	end
end

function CarSystem:SetSeatNetworkOwner(_active: boolean, seatPart: VehicleSeat, player: Player)
	if seatPart == nil then
		return
	end
	if not seatPart:IsA("VehicleSeat") and seatPart.Name ~= "CarSeat" then
		return
	end

	seatPart:SetNetworkOwner(player)
end

function CarSystem:OnParticleEmitterEvent(_player: Player, smokePart: BasePart, active: boolean)
	if not smokePart then
		return
	end

	local emitter: ParticleEmitter =
		smokePart:WaitForChild("Attachment"):WaitForChild("ParticleEmitter") :: ParticleEmitter

	if emitter.Enabled == active then
		return
	end

	emitter.Enabled = active
end

function CarSystem:FreezePlayerInput()
	ContextActionService:BindAction(FREEZE_INPUT_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, unpack(Enum.PlayerActions:GetEnumItems()))
end

function CarSystem:UnfreezePlayerInput()
	ContextActionService:UnbindAction(FREEZE_INPUT_ACTION)
end

return CarSystem

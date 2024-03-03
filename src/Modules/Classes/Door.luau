--local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

local SmokeEmitter = require(ReplicatedStorage.Modules.Libraries.SmokeEmitter)
local TweenInfoData = require(ReplicatedStorage.Modules.Libraries.TweenInfoData)

--local localPlayer: Player = Players.LocalPlayer
local spawnObjectsFolder: Folder = ReplicatedStorage:WaitForChild("SpawnObjects") :: Folder

local tweenDoorEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TweenDoorEvent")
local spawnObjectEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpawnObjectEvent")
local despawnObjectEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DespawnObjectEvent")
local destroyPlanesEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DestroyPlanesEvent")

local Door = {}
Door.__index = Door

type self = {
	doorInstance: Instance,
	detectionPart: BasePart,

	assignedObjectName: string?,

	defaultOrientation: Vector3?,
	triggeredOrientation: Vector3?,

	defaultPosition: Vector3?,
	triggeredPosition: Vector3?,

	tweensOrientation: boolean,
	tweensPosition: boolean,

	openTweenInfoIndex: number,
	closeTweenInfoIndex: number,

	detectVehicles: boolean,

	isPlayerInDetectionPart: boolean,

	currentTween: Tween?,
}

export type Door = typeof(setmetatable({} :: self, Door))

function Door.new(
	doorInstance: Instance, 
	detectionPart: BasePart,
	assignedObjectName: string?,
	defaultOrientation: Vector3?,
	triggeredOrientation: Vector3?,
	defaultPosition: Vector3?,
	triggeredPosition: Vector3?,
	openTweenInfoIndex: number,
	closeTweenInfoIndex: number,
	detectVehicles: boolean?
): Door
	local self = setmetatable({} :: self, Door)

	self.doorInstance = doorInstance
	self.detectionPart = detectionPart

	self.assignedObjectName = assignedObjectName

	self.defaultOrientation = defaultOrientation
	self.triggeredOrientation = triggeredOrientation
	self.defaultPosition = defaultPosition
	self.triggeredPosition = triggeredPosition

	self.openTweenInfoIndex = openTweenInfoIndex
	self.closeTweenInfoIndex = closeTweenInfoIndex

	self.detectVehicles = detectVehicles or false

	self.isPlayerInDetectionPart = false
	self.currentTween = nil

	self.tweensOrientation = (self.defaultOrientation ~= nil and self.triggeredOrientation ~= nil)
	self.tweensPosition = (self.defaultPosition ~= nil and self.triggeredPosition ~= nil)

	return self
end

function Door.onEveryCheckInterval(self: Door, _: number, humanoidRootParts: {}): ()
	local overlapParams: OverlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = humanoidRootParts

	local partsInBox: { BasePart } =
		workspace:GetPartBoundsInBox(self.detectionPart.CFrame, self.detectionPart.Size, overlapParams)

	if #partsInBox ~= 0 then
		if self.isPlayerInDetectionPart == true then
			return
		end
		self.isPlayerInDetectionPart = true
		tweenDoorEvent:FireAllClients(self.doorInstance :: Model, true)
		--self:onPlayerEnteringDetectionPart()
	else
		if self.isPlayerInDetectionPart == false then
			return
		end

		self.isPlayerInDetectionPart = false
		tweenDoorEvent:FireAllClients(self.doorInstance :: Model, false)
		--self:onPlayerLeavingDetectionPart()
	end
end

function Door.onPlayerEnteringDetectionPart(self: Door): ()
	if self.currentTween ~= nil then
		self.currentTween:Cancel()
		self.currentTween = nil
	end

	if self.tweensOrientation and not self.tweensPosition then
		self.currentTween = self._tweenToOrientation(
			self.doorInstance,
			self.defaultOrientation,
			self.triggeredOrientation,
			TweenInfoData.Door[self.openTweenInfoIndex]
		)
	elseif self.tweensPosition and not self.tweensOrientation then
		self.currentTween = self._tweenToPosition(
			self.doorInstance,
			self.defaultPosition,
			self.triggeredPosition,
			TweenInfoData.Door[self.openTweenInfoIndex]
		)
	elseif self.tweensOrientation and self.tweensPosition then
		self.currentTween = self._tweenToCFrame(
			self.doorInstance,
			self.defaultOrientation,
			self.triggeredOrientation,
			self.defaultPosition,
			self.triggeredPosition,
			TweenInfoData.Door[self.openTweenInfoIndex]
		)
	end

	if self.assignedObjectName and self.currentTween ~= nil then
		self.currentTween.Completed:Wait()
		spawnObjectEvent:FireServer(self.doorInstance :: Model, self.assignedObjectName)
		--self._spawnObject(self.assignedObjectName)
	end
end

function Door.onPlayerLeavingDetectionPart(self: Door): ()
	if self.currentTween ~= nil then
		self.currentTween:Cancel()
		self.currentTween = nil
	end

	if self.assignedObjectName then
		despawnObjectEvent:FireServer(self.doorInstance :: Model, self.assignedObjectName)
		--self._despawnObject(self.assignedObjectName)
	end

	if self.detectVehicles == true then
		destroyPlanesEvent:FireServer(self.doorInstance :: Model)
		--self:destroyPlanesInDetectionPart()
	end

	if self.tweensOrientation and not self.tweensPosition then
		self.currentTween = self._tweenToOrientation(
			self.doorInstance,
			self.triggeredOrientation,
			self.defaultOrientation,
			TweenInfoData.Door[self.closeTweenInfoIndex]
		)
	elseif self.tweensPosition and not self.tweensOrientation then
		self.currentTween = self._tweenToPosition(
			self.doorInstance,
			self.triggeredPosition,
			self.defaultPosition,
			TweenInfoData.Door[self.closeTweenInfoIndex]
		)
	elseif self.tweensOrientation and self.tweensPosition then
		self.currentTween = self._tweenToCFrame(
			self.doorInstance,
			self.triggeredOrientation,
			self.defaultOrientation,
			self.triggeredPosition,
			self.defaultPosition,
			TweenInfoData.Door[self.closeTweenInfoIndex]
		)
	end
end

function Door.destroyPlanesInDetectionPart(self: Door, character: Model): ()
	local overlapParams: OverlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {}

	for _, v in ipairs(character:GetChildren()) do
		table.insert(overlapParams.FilterDescendantsInstances, v)
	end

	for _, v in ipairs(self.doorInstance:GetChildren()) do
		table.insert(overlapParams.FilterDescendantsInstances, v)
	end

	local partsInBox: { BasePart } =
		workspace:GetPartBoundsInBox(self.detectionPart.CFrame, self.detectionPart.Size, overlapParams)

	for _, part: BasePart in ipairs(partsInBox) do
		local possiblePlaneModel: Model = part:FindFirstAncestorWhichIsA("Model") :: Model

		if possiblePlaneModel ~= nil and possiblePlaneModel:HasTag("Plane") then
			local planeSeat: VehicleSeat = possiblePlaneModel:WaitForChild("Engine"):WaitForChild("PlaneSeat")
			
			if planeSeat.Occupant ~= nil then
				return
			end

			local vehicleCFrame = possiblePlaneModel:GetPivot()
			possiblePlaneModel:Destroy()

			SmokeEmitter:EmitSmoke(vehicleCFrame * CFrame.new(Vector3.new(0, 2, 0)).Position)

			break
		end
	end
end

function Door._spawnObject(objectName: string)
	if not spawnObjectsFolder:FindFirstChild(objectName) then
		print("Object not found")
		return
	end

	local objectToSpawn: Model = spawnObjectsFolder:FindFirstChild(objectName) :: Model

	if objectToSpawn.Parent == workspace then
		print("Object already spawned")
		return
	end

	objectToSpawn.Parent = workspace
	SmokeEmitter:EmitSmoke(objectToSpawn:GetPivot().Position)
end

function Door._despawnObject(objectName: string)
	if not workspace:FindFirstChild(objectName) then
		print("Object not found")
		return
	end

	local objectToDespawn: Model = workspace:FindFirstChild(objectName)

	if objectToDespawn.Parent == ReplicatedStorage:FindFirstChild("SpawnObjects") then
		print("Object already despawned")
		return
	end

	SmokeEmitter:EmitSmoke(objectToDespawn:GetPivot().Position)

	objectToDespawn.Parent = ReplicatedStorage:FindFirstChild("SpawnObjects")
end

function Door._tweenToOrientation(
	doorInstance: Model,
	initialOrientation: Vector3,
	finalOrientation: Vector3,
	tweenInfo: TweenInfo
): Tween
	doorInstance:PivotTo(
		CFrame.new(doorInstance:GetPivot().Position)
			* CFrame.fromOrientation(
				math.rad(initialOrientation.X),
				math.rad(initialOrientation.Y),
				math.rad(initialOrientation.Z)
			)
	)

	local orientationCFrameValue: CFrameValue = Instance.new("CFrameValue")
	orientationCFrameValue.Value = doorInstance:GetPivot()

	orientationCFrameValue:GetPropertyChangedSignal("Value"):Connect(function(_)
		doorInstance:PivotTo(orientationCFrameValue.Value)
	end)

	local tween: Tween = TweenService:Create(orientationCFrameValue, tweenInfo, {
		Value = CFrame.new(doorInstance:GetPivot().Position) * CFrame.fromOrientation(
			math.rad(finalOrientation.X),
			math.rad(finalOrientation.Y),
			math.rad(finalOrientation.Z)
		),
	})
	tween:Play()

	tween.Completed:Connect(function(_)
		orientationCFrameValue:Destroy()
	end)

	return tween
end

function Door._tweenToPosition(
	doorInstance: Model,
	initialPosition: Vector3,
	finalPosition: Vector3,
	tweenInfo: TweenInfo
): Tween
	local X, Y, Z = doorInstance:GetPivot():ToOrientation()
	doorInstance:PivotTo(CFrame.new(initialPosition) * CFrame.fromOrientation(X, Y, Z))

	local positionCFrameValue: CFrameValue = Instance.new("CFrameValue")
	positionCFrameValue.Value = doorInstance:GetPivot()

	positionCFrameValue:GetPropertyChangedSignal("Value"):Connect(function(_)
		doorInstance:PivotTo(positionCFrameValue.Value)
	end)

	local tween: Tween = TweenService:Create(positionCFrameValue, tweenInfo, {
		Value = CFrame.new(finalPosition) * CFrame.fromOrientation(X, Y, Z),
	})

	tween:Play()

	tween.Completed:Connect(function(_)
		positionCFrameValue:Destroy()
	end)

	return tween
end

function Door._tweenToCFrame(
	doorInstance: Model,
	initialOrientation: Vector3,
	finalOrientation: Vector3,
	defaultPosition: Vector3,
	triggeredPosition: Vector3,
	tweenInfo: TweenInfo
): Tween
	doorInstance:PivotTo(
		CFrame.new(defaultPosition)
			* CFrame.fromOrientation(initialOrientation.X, initialOrientation.Y, initialOrientation.Z)
	)

	local cFrameValue: CFrameValue = Instance.new("CFrameValue")
	cFrameValue.Value = doorInstance:GetPivot()

	cFrameValue:GetPropertyChangedSignal("Value"):Connect(function(_)
		doorInstance:PivotTo(cFrameValue.Value)
	end)

	local tween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
		Value = CFrame.new(triggeredPosition) * CFrame.fromOrientation(
			math.rad(finalOrientation.X),
			math.rad(finalOrientation.Y),
			math.rad(finalOrientation.Z)
		),
	})
	tween:Play()

	tween.Completed:Connect(function(_)
		cFrameValue:Destroy()
	end)

	return tween
end

return Door

local CollectionService: CollectionService = game:GetService("CollectionService")
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Door = require(ReplicatedStorage.Modules.Classes.Door)

local humanoidRootParts: {} = {}
local tweenDoorEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TweenDoorEvent")
local spawnObjectEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpawnObjectEvent")
local despawnObjectEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DespawnObjectEvent")
local destroyPlanesEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DestroyPlanesEvent")

local DoorSystem = {}

DoorSystem.TAG_NAME = "Door" :: string
DoorSystem.DETECTION_PART_CHECK_INTERVAL = 0.095 :: number

DoorSystem.Doors = {} :: {}

DoorSystem.SumOfDeltaTime = 0 :: number
DoorSystem.HeartbeatConnection = nil :: RBXScriptConnection?


function DoorSystem:InitializeServer(): boolean
	for _, doorInstance: Instance in ipairs(CollectionService:GetTagged(DoorSystem.TAG_NAME)) do
		if not doorInstance:IsA("Model") then
			return false
		end

		self:OnDoorAdded(doorInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(doorInstance: Instance)
		if not doorInstance:IsA("Model") then
			return false
		end

		self:OnDoorAdded(doorInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(doorInstance: Instance)
		self:OnDoorRemoved(doorInstance :: Model)
	end)

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		self:OnHeartbeat(dt)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			local character: Model = player.Character or player.CharacterAdded:Wait()
			local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart")
			table.insert(humanoidRootParts, humanoidRootPart)
		end)
	end)

	spawnObjectEvent.OnServerEvent:Connect(function(_player: Player, doorInstance: Model, assignedObjectName: string)
		local doorObject: Door.Door = self.Doors[doorInstance]

		doorObject._spawnObject(assignedObjectName)
	end)

	despawnObjectEvent.OnServerEvent:Connect(function(_player: Player, doorInstance: Model, assignedObjectName: string)
		local doorObject: Door.Door = self.Doors[doorInstance]

		doorObject._despawnObject(assignedObjectName)
	end)

	destroyPlanesEvent.OnServerEvent:Connect(function(player: Player, doorInstance: Model)
		print(doorInstance.Name)
		local doorObject: Door.Door = self.Doors[doorInstance]
		local character: Model = player.Character or player.CharacterAdded:Wait()

		doorObject:destroyPlanesInDetectionPart(character)
	end)

	return true
end

function DoorSystem:InitializeClient(): boolean
	for _, doorInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		if not doorInstance:IsA("Model") then
			return false
		end

		self:OnDoorAdded(doorInstance :: Model)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(doorInstance: Instance)
		if not doorInstance:IsA("Model") then
			return false
		end

		self:OnDoorAdded(doorInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(doorInstance: Instance)
		self:OnDoorRemoved(doorInstance :: Model)
	end)

	tweenDoorEvent.OnClientEvent:Connect(function(doorInstance: Model, playerEntering: boolean)
		local doorObject: Door.Door = self.Doors[doorInstance]

		if playerEntering == true then
			doorObject:onPlayerEnteringDetectionPart()
		else
			doorObject:onPlayerLeavingDetectionPart()
		end
	end)

	return true
end

function DoorSystem:OnDoorAdded(doorInstance: Model): ()
	local detectionPart: BasePart =
		workspace:WaitForChild("DetectionParts"):WaitForChild(doorInstance:GetAttribute("DetectionPartName"))

	local doorObject: Door.Door = Door.new(
		doorInstance,
		detectionPart,
		doorInstance:GetAttribute("SpawnObjectName"),
		doorInstance:GetAttribute("DefaultOrientation"),
		doorInstance:GetAttribute("TriggeredOrientation"),
		doorInstance:GetAttribute("DefaultPosition"),
		doorInstance:GetAttribute("TriggeredPosition"),
		doorInstance:GetAttribute("OpenTweenInfoIndex"),
		doorInstance:GetAttribute("CloseTweenInfoIndex"),
		doorInstance:GetAttribute("DetectVehicles")
	)

	self.Doors[doorInstance] = doorObject
end

function DoorSystem:OnDoorRemoved(doorInstance: Model): ()
	if doorInstance == nil then
		return
	end

	doorInstance:Destroy()
	local doorObject: Door.Door = self.Doors[doorInstance]

	doorObject.touchedConnection:Disconnect()
	doorObject.renderSteppedConnection:Disconnect()

	self.Doors[doorInstance] = nil
end

function DoorSystem:OnHeartbeat(dt: number): ()
	self.SumOfDeltaTime += dt
	if self.SumOfDeltaTime < self.DETECTION_PART_CHECK_INTERVAL then
		return
	end

	for _, doorObject: Door.Door in pairs(self.Doors) do
		doorObject:onEveryCheckInterval(dt, humanoidRootParts)
	end

	self.SumOfDeltaTime = 0
end

return DoorSystem

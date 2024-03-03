local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SmokeEmitter = require(ReplicatedStorage.Modules.Libraries.SmokeEmitter)

local carSpawnPrompt: ProximityPrompt = workspace:WaitForChild("CarSpawn"):WaitForChild("ProximityPrompt")
local planeSpawnPrompt: ProximityPrompt =
	workspace:WaitForChild("Doors"):WaitForChild("PlaneDoor"):WaitForChild("SpawnPlane"):WaitForChild("ProximityPrompt")

local vehiclesFolder: Folder = ReplicatedStorage:WaitForChild("Vehicles") :: Folder

local VehicleSpawningSystem = {}

function VehicleSpawningSystem:InitializeServer(): boolean
	carSpawnPrompt.Triggered:Connect(function(_)
		local clonedVehicleInstance: Model = vehiclesFolder:WaitForChild("Car"):Clone() :: Model
		clonedVehicleInstance.Parent = workspace

		SmokeEmitter:EmitSmoke(clonedVehicleInstance:GetPivot().Position, 90)

		clonedVehicleInstance:AddTag("Car")
	end)

	planeSpawnPrompt.Triggered:Connect(function(_)
		local clonedVehicleInstance: Model = vehiclesFolder:WaitForChild("Plane"):Clone() :: Model
		clonedVehicleInstance.Parent = workspace

		SmokeEmitter:EmitSmoke(clonedVehicleInstance:GetPivot().Position, 90)

		clonedVehicleInstance:AddTag("Plane")
	end)

	return true
end

return VehicleSpawningSystem

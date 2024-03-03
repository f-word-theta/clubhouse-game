--[[ FRAMEWORK MADE BY @THETA1SM ]]

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SystemsFolder: Folder = ReplicatedStorage.Modules.Systems
local BaseSystem = require(ReplicatedStorage.Modules.Systems.BaseSystem)

for _, module in ipairs(SystemsFolder:GetChildren()) do
	local loaded: BaseSystem.BaseSystem = require(module)

	if loaded.InitializeServer ~= nil then
		local result: boolean = loaded:InitializeServer()

		if result == true then
			print('✅ "' .. module.Name .. '"' .. " loaded successfully from server.")
		else
			print('❌ "' .. module.Name .. '"' .. " failed to load from server.")
		end
	end
end

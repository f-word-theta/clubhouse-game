--[[ FRAMEWORK MADE BY @THETA1SM ]]

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SystemsFolder: Folder = ReplicatedStorage.Modules.Systems
local BaseSystem = require(ReplicatedStorage.Modules.Systems.BaseSystem)

for _, module in ipairs(SystemsFolder:GetChildren()) do
	local loaded: BaseSystem.BaseSystem = require(module)

	if loaded.InitializeClient ~= nil then
		local result: boolean = loaded:InitializeClient()

		if result == true then
			print('✅ "' .. module.Name .. '"' .. " loaded successfully on client.")
		else
			print('❌ "' .. module.Name .. '"' .. " failed to load on client.")
		end
	end
end

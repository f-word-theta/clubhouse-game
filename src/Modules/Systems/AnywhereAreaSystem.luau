local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")

local anywhereAreaModel: Model = game.Workspace:WaitForChild("AnywhereArea")
local switchModel: Model = game.Workspace:WaitForChild("AnywhereSwitch")
local handleModel: Model = switchModel:WaitForChild("Handle") :: Model
local prompt: ProximityPrompt =
	switchModel:WaitForChild("Handle"):WaitForChild("SwitchHandle"):WaitForChild("ProximityPrompt") :: ProximityPrompt

local roomsFolder: Folder = ReplicatedStorage:WaitForChild("Rooms") :: Folder

local AnywhereAreaSystem = {}

AnywhereAreaSystem.TWEEN_COOLDOWN = 0.1

AnywhereAreaSystem.FORWARD_ANGLE_SEQUENCE = { 0, -45, -90, -135, -180 }
AnywhereAreaSystem.BACKWARD_ANGLE_SEQUENCE = { 180, 135, 90, 45, 0 }
AnywhereAreaSystem.SWITCH_ANGLE_SEQUENCE = { 25, 10, -5, -20, -35 }

AnywhereAreaSystem.DEFAULT_LIGHT_MATERIAL = Enum.Material.Plastic
AnywhereAreaSystem.GLOWING_LIGHT_MATERIAL = Enum.Material.Neon

AnywhereAreaSystem.TopsideRoom = anywhereAreaModel:WaitForChild("Living")
AnywhereAreaSystem.UndersideRoom = anywhereAreaModel:WaitForChild("PlaceholderRoom")

AnywhereAreaSystem.TweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, false, 0)
AnywhereAreaSystem.InitialHandleTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

AnywhereAreaSystem.AngleLightDictionary = {
	[-35] = switchModel:FindFirstChild("1Light"),
	[-20] = switchModel:FindFirstChild("2Light"),
	[-5] = switchModel:FindFirstChild("3Light"),
	[10] = switchModel:FindFirstChild("4Light"),
	[25] = switchModel:FindFirstChild("5Light"),
}

function AnywhereAreaSystem:InitializeClient(): boolean
	prompt.Triggered:Connect(function(_)
		self:OnPromptActivated()
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		self:OnHeartbeat(dt)
	end)
	
	return true
end

function AnywhereAreaSystem:OnHeartbeat(_dt: number)
	local switchX, switchY, switchZ = handleModel:GetPivot():ToOrientation()
	local degX, _degY, _degZ = math.deg(switchX), math.deg(switchY), math.deg(switchZ)

	for angle: number, light: Instance in pairs(self.AngleLightDictionary) do
		if math.round(degX) >= angle - 7 and math.round(degX) <= angle + 7 then
			for _, part: Instance | BasePart in ipairs(light:GetChildren()) do
				if not part:IsA("BasePart") then
					return
				end

				part.Material = self.GLOWING_LIGHT_MATERIAL
			end
		else
			for _, part: Instance | BasePart in ipairs(light:GetChildren()) do
				if not part:IsA("BasePart") then
					return
				end

				part.Material = self.DEFAULT_LIGHT_MATERIAL
			end
		end
	end
end

function AnywhereAreaSystem:OnPromptActivated()
	prompt.Enabled = false

	local randomRoom: Model = self:PickRandomRoom():Clone()
	randomRoom.Parent = anywhereAreaModel

	randomRoom:PivotTo(self.UndersideRoom:GetPivot())
	self.UndersideRoom:Destroy()
	self.UndersideRoom = nil

	self:StartTween(randomRoom)
end

function AnywhereAreaSystem:StartTween(randomRoom: Model)
	local _switchX, switchY, switchZ = handleModel:GetPivot():ToOrientation()

	local handleModelCFrameValue: CFrameValue = Instance.new("CFrameValue")
	handleModelCFrameValue.Value = handleModel:GetPivot()

	handleModelCFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
		handleModel:PivotTo(handleModelCFrameValue.Value)
	end)

	local _anywhereX, _anywhereY, anywhereZ = anywhereAreaModel:GetPivot():ToEulerAnglesXYZ()

	local anywhereModelCFrameValue: CFrameValue = Instance.new("CFrameValue")
	anywhereModelCFrameValue.Value = anywhereAreaModel:GetPivot()

	anywhereModelCFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
		anywhereAreaModel:PivotTo(anywhereModelCFrameValue.Value)
	end)

	local initialHandleTween: Tween = TweenService:Create(handleModelCFrameValue, self.InitialHandleTweenInfo, {
		Value = CFrame.new(handleModel:GetPivot().Position)
			* CFrame.fromOrientation(math.rad(self.SWITCH_ANGLE_SEQUENCE[1]), switchY, switchZ),
	}) :: Tween

	initialHandleTween:Play()
	initialHandleTween.Completed:Wait()

	local finalTween: Tween = nil

	if math.round(math.abs(anywhereZ)) == 0 then
		finalTween = self:TweenFromTable(self.FORWARD_ANGLE_SEQUENCE, anywhereModelCFrameValue, handleModelCFrameValue)
		finalTween:Play()
	else
		finalTween = self:TweenFromTable(self.BACKWARD_ANGLE_SEQUENCE, anywhereModelCFrameValue, handleModelCFrameValue)
		finalTween:Play()
	end

	finalTween.Completed:Connect(function(_)
		--local _nextX, _nextY, nextZ = anywhereAreaModel:GetPivot():ToEulerAnglesXYZ()

		anywhereModelCFrameValue:Destroy()
		handleModelCFrameValue:Destroy()

		self.UndersideRoom = self.TopsideRoom
		self.TopsideRoom = randomRoom

		task.wait(0.2)

		prompt.Enabled = true
	end)
end

-- this function is specific for this system
function AnywhereAreaSystem:TweenFromTable(
	table: { any },
	_anywhereModelCFrameValue: CFrameValue,
	_handleModelCFrameValue: CFrameValue
): Tween?
	local _X, Y, Z = handleModel:GetPivot():ToOrientation()
	local finalTween: Tween = nil

	for i, v in ipairs(table) do
		if i == 1 then
			continue
		end

		if i == #table then
			finalTween = TweenService:Create(_anywhereModelCFrameValue, self.TweenInfo, {
				Value = CFrame.new(anywhereAreaModel:GetPivot().Position) * CFrame.Angles(0, 0, math.rad(v)),
			}) :: Tween

			local handleTween: Tween = TweenService:Create(_handleModelCFrameValue, self.TweenInfo, {
				Value = CFrame.new(handleModel:GetPivot().Position)
					* CFrame.fromOrientation(math.rad(self.SWITCH_ANGLE_SEQUENCE[i]), Y, Z),
			})

			coroutine.wrap(function()
				handleTween:Play()
			end)()

			return finalTween
		end

		local anywhereTween: Tween = TweenService:Create(_anywhereModelCFrameValue, self.TweenInfo, {
			Value = CFrame.new(anywhereAreaModel:GetPivot().Position) * CFrame.Angles(0, 0, math.rad(v)),
		}) :: Tween

		local handleTween: Tween = TweenService:Create(_handleModelCFrameValue, self.TweenInfo, {
			Value = CFrame.new(handleModel:GetPivot().Position)
				* CFrame.fromOrientation(math.rad(self.SWITCH_ANGLE_SEQUENCE[i]), Y, Z),
		})

		anywhereTween:Play()
		coroutine.wrap(function()
			handleTween:Play()
		end)()

		anywhereTween.Completed:Wait()
		task.wait(self.TWEEN_COOLDOWN)
	end

	return
end

function AnywhereAreaSystem:PickRandomRoom(): Model?
	if #roomsFolder:GetChildren() == 0 then
		print("No rooms found")
		return
	end

	local random: number = nil

	while
		not random
		or (
			roomsFolder:GetChildren()[random].Name == self.TopsideRoom.Name
			or roomsFolder:GetChildren()[random] == self.UndersideRoom.Name
		)
	do
		random = math.random(1, #roomsFolder:GetChildren())
	end

	return roomsFolder:GetChildren()[random] :: Model
end

return AnywhereAreaSystem

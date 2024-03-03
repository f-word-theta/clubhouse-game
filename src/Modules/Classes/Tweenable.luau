local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenInfoData = require(ReplicatedStorage.Modules.Libraries.TweenInfoData)

local Tweenable = {}
Tweenable.__index = Tweenable

export type TweenableInstance = Model | BasePart

type self = {
	tweenableInstance: TweenableInstance,

	defaultOrientation: Vector3?,
	nextOrientation: Vector3?,

	firstPosition: Vector3?,
	secondPosition: Vector3?,

	tweenInfoIndex: number,
	tweenDelay: number,
	extraTweenDelay: number,

	tweenByInterval: boolean?,

	startTween: (self: Tweenable) -> (),
}

export type Tweenable = typeof(setmetatable({} :: self, Tweenable))

function Tweenable.new(
	tweenableInstance: TweenableInstance,
	defaultOrientation: Vector3?,
	nextOrientation: Vector3?,
	firstPosition: Vector3?,
	secondPosition: Vector3?,
	tweenInfoIndex: number,
	tweenDelay: number?,
	extraTweenDelay: number?,
	tweenByInterval: boolean?
): Tweenable
	local self = setmetatable({} :: self, Tweenable)

	self.tweenableInstance = tweenableInstance

	self.defaultOrientation = defaultOrientation
	self.nextOrientation = nextOrientation

	self.firstPosition = firstPosition
	self.secondPosition = secondPosition

	self.tweenInfoIndex = tweenInfoIndex
	self.tweenDelay = if tweenDelay then tweenDelay else 0.0
	self.extraTweenDelay = if extraTweenDelay then extraTweenDelay else 0.0

	self.tweenByInterval = if tweenByInterval then tweenByInterval else false

	return self
end

function Tweenable.startTween(self: Tweenable): ()
	if self.tweenableInstance:IsA("Model") then
		local cFrameValue: CFrameValue = Instance.new("CFrameValue")
		cFrameValue.Value = self.tweenableInstance:GetPivot()

		cFrameValue:GetPropertyChangedSignal("Value"):Connect(function(_)
			self.tweenableInstance:PivotTo(cFrameValue.Value)
		end)

		self._tweenModel(
			cFrameValue,
			self.tweenableInstance :: Model,
			self.defaultOrientation,
			self.nextOrientation,
			self.firstPosition,
			self.secondPosition,
			TweenInfoData.Tweenable[self.tweenInfoIndex],
			self.tweenDelay,
			self.extraTweenDelay,
			self.tweenByInterval
		)
	elseif self.tweenableInstance:IsA("BasePart") then
		self._tweenPart(
			self.tweenableInstance :: BasePart,
			self.defaultOrientation,
			self.nextOrientation,
			self.firstPosition,
			self.secondPosition,
			TweenInfoData.Tweenable[self.tweenInfoIndex],
			self.tweenDelay,
			self.tweenByInterval
		)
	end
end

function Tweenable._tweenModel(
	cFrameValue: CFrameValue,
	model: Model,
	defaultOrientation: Vector3?,
	nextOrientation: Vector3?,
	firstPosition: Vector3?,
	secondPosition: Vector3?,
	tweenInfo: TweenInfo,
	delayBeforeNextTween: number,
	delayThatIsVerySpecificToOneObjectAndIHaveNoIdeaWhy: number,
	tweenByInterval: boolean
): ()
	if defaultOrientation ~= nil and nextOrientation ~= nil then
		local firstTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = CFrame.new(model:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(nextOrientation.X),
				math.rad(nextOrientation.Y),
				math.rad(nextOrientation.Z)
			),
		})

		local secondTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = CFrame.new(model:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(defaultOrientation.X),
				math.rad(defaultOrientation.Y),
				math.rad(defaultOrientation.Z)
			),
		})

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			firstTween:Play()
		end)
	elseif firstPosition ~= nil and secondPosition ~= nil then
		local X, Y, Z = model:GetPivot():ToOrientation()

		local firstTween: Tween = TweenService:Create(
			cFrameValue,
			tweenInfo,
			{ Value = CFrame.new(secondPosition) * CFrame.fromOrientation(X, Y, Z) }
		)

		local secondTween: Tween = TweenService:Create(
			cFrameValue,
			tweenInfo,
			{ Value = CFrame.new(firstPosition) * CFrame.fromOrientation(X, Y, Z) }
		)

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			task.wait(delayThatIsVerySpecificToOneObjectAndIHaveNoIdeaWhy)
			firstTween:Play()
		end)
	elseif tweenByInterval == true then
		local firstTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = model:GetPivot() * CFrame.fromOrientation(
				math.rad(0),
				math.rad(90),
				math.rad(0)
			),
		})

		local secondTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = model:GetPivot() * CFrame.fromOrientation(
				math.rad(0),
				math.rad(180),
				math.rad(0)
			),
		})

		local thirdTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = model:GetPivot() * CFrame.fromOrientation(
				math.rad(0),
				math.rad(-90),
				math.rad(0)
			),
		})

		local fourthTween: Tween = TweenService:Create(cFrameValue, tweenInfo, {
			Value = model:GetPivot() * CFrame.fromOrientation(
				math.rad(0),
				math.rad(0),
				math.rad(0)
			),
		})

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			thirdTween:Play()
		end)
		thirdTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			fourthTween:Play()
		end)
		fourthTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			firstTween:Play()
		end)
	end
end

function Tweenable._tweenPart(
	part: BasePart,
	defaultOrientation: Vector3?,
	nextOrientation: Vector3?,
	firstPosition: Vector3?,
	secondPosition: Vector3?,
	tweenInfo: TweenInfo,
	delayBeforeNextTween: number,
	tweenByInterval: boolean
): ()
	if defaultOrientation ~= nil and nextOrientation ~= nil then
		local firstTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(nextOrientation.X),
				math.rad(nextOrientation.Y),
				math.rad(nextOrientation.Z)
			),
		})

		local secondTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(defaultOrientation.X),
				math.rad(defaultOrientation.Y),
				math.rad(defaultOrientation.Z)
			),
		})

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			firstTween:Play()
		end)
	elseif firstPosition ~= nil and secondPosition ~= nil then
		local X, Y, Z: number = part:GetPivot():ToOrientation()

		local firstTween: Tween = TweenService:Create(
			part,
			tweenInfo,
			{ CFrame = CFrame.new(secondPosition) * CFrame.fromOrientation(X, Y, Z) }
		)

		local secondTween: Tween = TweenService:Create(
			part,
			tweenInfo,
			{ CFrame = CFrame.new(firstPosition) * CFrame.fromOrientation(X, Y, Z) }
		)

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			firstTween:Play()
		end)
	elseif tweenByInterval == true then
		local firstTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(0),
				math.rad(90),
				math.rad(0)
			),
		})

		local secondTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(0),
				math.rad(180),
				math.rad(0)
			),
		})

		local thirdTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(0),
				math.rad(-90),
				math.rad(0)
			),
		})

		local fourthTween: Tween = TweenService:Create(part, tweenInfo, {
			CFrame = CFrame.new(part:GetPivot().Position) * CFrame.fromOrientation(
				math.rad(0),
				math.rad(0),
				math.rad(0)
			),
		})

		firstTween:Play()
		firstTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			secondTween:Play()
		end)
		secondTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			thirdTween:Play()
		end)
		thirdTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			fourthTween:Play()
		end)
		fourthTween.Completed:Connect(function(_)
			task.wait(delayBeforeNextTween)
			firstTween:Play()
		end)
	end
end

return Tweenable

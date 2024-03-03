local CollectionService: CollectionService = game:GetService("CollectionService")
local RunService: RunService = game:GetService("RunService")

local walkAnimation: Animation = Instance.new("Animation")
walkAnimation.AnimationId = "rbxassetid://15005624911"

local eatAnimation: Animation = Instance.new("Animation")
eatAnimation.AnimationId = "rbxassetid://15005882216"

local CowAISystem = {}
CowAISystem.__index = CowAISystem

CowAISystem.TAG_NAME = "Cow"
CowAISystem.Cows = {} :: {}

local timeSum: number = 0

function CowAISystem:InitializeServer(): boolean
	math.randomseed(tick())

	for _, cowInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		self:OnCowAdded(cowInstance)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(cowInstance: Instance)
		self:OnCowAdded(cowInstance :: Model)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(cowInstance: Instance)
		self:OnCowRemoved(cowInstance :: Model)
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		timeSum += dt
		if timeSum <= 0.1 then
			return
		end
		timeSum = 0.0

		local randomCowInstance: Model = CollectionService:GetTagged(self.TAG_NAME)[math.random(
			1,
			#CollectionService:GetTagged(self.TAG_NAME)
		)] :: Model
		local randomCowObject = self.Cows[randomCowInstance]

		local randomNumber: number = math.random(1, 3)

		if randomNumber == 1 then -- walk
			randomCowObject.walkAnimationTrack:Play()

			randomCowObject.humanoid:MoveTo(
				randomCowInstance:GetPivot().Position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			)

			randomCowObject.humanoid.MoveToFinished:Connect(function()
				randomCowObject.walkAnimationTrack:Stop()
			end)
		elseif randomNumber == 2 then -- eat
			randomCowObject.eatAnimationTrack:Play()
			randomCowObject.eatAnimationTrack.Ended:Wait()
		elseif randomNumber == 3 then
			return
		end
	end)

	return true
end

function CowAISystem.newCow(cowInstance: Model)
	local self = {}
	setmetatable(self, CowAISystem)

	self.cowInstance = cowInstance :: Model
	self.humanoid = cowInstance:WaitForChild("Humanoid") :: Humanoid
	self.animator = self.humanoid:WaitForChild("Animator") :: Animator

	self.walkAnimationTrack = self.animator:LoadAnimation(walkAnimation) :: AnimationTrack
	self.eatAnimationTrack = self.animator:LoadAnimation(eatAnimation) :: AnimationTrack

	return self
end

function CowAISystem:OnCowAdded(cowInstance: Model)
	local cowObject = self.newCow(cowInstance)
	self.Cows[cowInstance] = cowObject
end

function CowAISystem:destroyCar(cowInstance: Model)
	if not cowInstance then
		return
	end

	cowInstance:Destroy()
	self.Cows[cowInstance] = nil
end

function CowAISystem:OnCarRemoved(cowInstance: Model)
	self.Cows[cowInstance].destroyCar()
end

return CowAISystem

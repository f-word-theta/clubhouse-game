local CollectionService: CollectionService = game:GetService("CollectionService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tweenable = require(ReplicatedStorage.Modules.Classes.Tweenable)

local TweenableSystem = {}
TweenableSystem.__index = TweenableSystem

TweenableSystem.TAG_NAME = "Tweenable" :: string

TweenableSystem.Tweenables = {} :: {}

function TweenableSystem:InitializeClient(): boolean
	for _, tweenableInstance: Instance in ipairs(CollectionService:GetTagged(self.TAG_NAME)) do
		self:OnTweenableAdded(tweenableInstance :: Tweenable.TweenableInstance)
	end

	CollectionService:GetInstanceAddedSignal(self.TAG_NAME):Connect(function(tweenableInstance: Instance)
		self:OnTweenableAdded(tweenableInstance :: Tweenable.TweenableInstance)
	end)

	CollectionService:GetInstanceRemovedSignal(self.TAG_NAME):Connect(function(tweenableInstance: Instance)
		self:OnTweenableRemoved(tweenableInstance :: Tweenable.TweenableInstance)
	end)

	return true
end

function TweenableSystem:OnTweenableAdded(tweenableInstance: Tweenable.TweenableInstance): ()
	local tweenableObject: Tweenable.Tweenable = Tweenable.new(
		tweenableInstance,
		tweenableInstance:GetAttribute("DefaultOrientation"),
		tweenableInstance:GetAttribute("NextOrientation"),
		tweenableInstance:GetAttribute("FirstPosition"),
		tweenableInstance:GetAttribute("SecondPosition"),
		tweenableInstance:GetAttribute("TweenInfoIndex"),
		tweenableInstance:GetAttribute("TweenDelay"),
		tweenableInstance:GetAttribute("ExtraTweenDelay"),
		tweenableInstance:GetAttribute("TweenByInterval")
	)
	self.Tweenables[tweenableInstance] = tweenableObject

	tweenableObject:startTween()
end

function TweenableSystem:OnTweenableRemoved(tweenableInstance: Tweenable.TweenableInstance): ()
	if tweenableInstance == nil then
		return
	end

	tweenableInstance:Destroy()
	TweenableSystem.Tweenables[tweenableInstance] = nil
end

return TweenableSystem

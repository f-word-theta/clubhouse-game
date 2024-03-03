local RunService: RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Car = {}
Car.__index = Car

type self = {
	carInstance: Model,

	selfDetonateTimerValue: NumberValue?,
	selfDetonateEnabled: boolean,

	startTickTime: number,

	engineModel: Model,
	mainModel: Model,

	carSeat: VehicleSeat,

	frontLeftWheel: BasePart,
	frontRightWheel: BasePart,
	backLeftWheel: BasePart,
	backRightWheel: BasePart,
	frontLeftCarAttachment: Attachment,
	frontRightCarAttachment: Attachment,

	smokePart: BasePart,
}

export type Car = typeof(setmetatable({} :: self, Car))

function Car.new(carInstance: Model, selfDetonateEnabled: boolean): Car
	local self = setmetatable({} :: self, Car)

	self.carInstance = carInstance
	
	self.engineModel = carInstance:WaitForChild("Engine")
	self.mainModel = carInstance:WaitForChild("Main")

	self.carSeat = self.engineModel:WaitForChild("CarSeat")
	
	self.frontLeftWheel = self.engineModel:WaitForChild("FrontLeftWheel")
	self.frontRightWheel = self.engineModel:WaitForChild("FrontRightWheel")
	self.backLeftWheel = self.engineModel:WaitForChild("BackLeftWheel")
	self.backRightWheel = self.engineModel:WaitForChild("BackRightWheel")

	self.frontLeftCarAttachment = self.mainModel:WaitForChild("FrontLeftAttachmentPart"):WaitForChild("Attachment0")
	self.frontRightCarAttachment = self.mainModel:WaitForChild("FrontRightAttachmentPart"):WaitForChild("Attachment0")
	
	self.smokePart = self.mainModel:WaitForChild("SmokePart")

	self.selfDetonateEnabled = selfDetonateEnabled
	self.selfDetonateTimerValue = carInstance:WaitForChild("Timer")
	self.startTickTime = if IS_SERVER then tick() else nil

	return self
end

return Car

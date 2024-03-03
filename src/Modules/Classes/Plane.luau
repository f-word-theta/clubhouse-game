local RunService: RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Plane = {}
Plane.__index = Plane

type self = {
	planeInstance: Model,
	planeSeat: VehicleSeat,

	selfDetonateTimerValue: NumberValue?,
	selfDetonateEnabled: boolean,

	startTickTime: number,

	alignOrientation: AlignOrientation,
	linearVelocity: LinearVelocity,

	hingeConstraint: HingeConstraint,

	cosmeticSteerValue: NumberValue,
}

export type Plane = typeof(setmetatable({} :: self, Plane))

function Plane.new(planeInstance: Model, selfDetonateEnabled: boolean)
	local self = setmetatable({} :: self, Plane)

	self.planeInstance = planeInstance
	self.planeSeat = planeInstance:WaitForChild("Engine"):WaitForChild("PlaneSeat")

	self.selfDetonateTimerValue = planeInstance:WaitForChild("Timer")
	self.selfDetonateEnabled = selfDetonateEnabled
	
	self.startTickTime = if IS_SERVER then tick() else nil

	self.alignOrientation = self.planeSeat:WaitForChild("AlignOrientation")
	self.linearVelocity = self.planeSeat:WaitForChild("LinearVelocity")
	self.cosmeticSteerValue = self.planeSeat:WaitForChild("CosmeticSteerValue")

	self.hingeConstraint = planeInstance:WaitForChild("Main"):WaitForChild("Propeller"):WaitForChild("InsidePlanePrope"):WaitForChild("HingeConstraint")

	return self
end

return Plane
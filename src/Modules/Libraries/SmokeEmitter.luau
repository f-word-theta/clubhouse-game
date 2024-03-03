local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SmokeEmitter = {}

SmokeEmitter.EmitterPart = ReplicatedStorage:WaitForChild("SpawnParticles") :: BasePart

function SmokeEmitter:EmitSmoke(pos: Vector3, amount: number?)
	coroutine.wrap(function()
		local clonedEmitterPart: BasePart = self.EmitterPart:Clone()
		clonedEmitterPart.Parent = workspace
		clonedEmitterPart.CFrame = CFrame.new(pos)

		local emitter: ParticleEmitter = clonedEmitterPart:WaitForChild("Attachment"):WaitForChild("ParticleEmitter")

		emitter:Emit(amount or 40)
		task.wait(1)

		clonedEmitterPart:Destroy()
	end)()
end

return SmokeEmitter

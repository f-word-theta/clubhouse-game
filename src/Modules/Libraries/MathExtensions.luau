local MathExtensions = {}

function MathExtensions:Lerp(a, b, t)
	return a + (b - a) * t
end

function MathExtensions:InverseLerp(a, b, x)
	return (x - a) / (b - a)
end

function MathExtensions:Remap(in1, in2, out1, out2, x)
	return self:Lerp(out1, out2, self:InverseLerp(in1, in2, x))
end

return MathExtensions
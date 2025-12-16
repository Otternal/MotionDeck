--!strict
-- MathsUtil

local MathsUtil = {}

-- One full turn in radians
MathsUtil.tau = 2 * math.pi

-- y(t) = amp * sin(tau * freq * t + phase)
-- t = time in seconds
-- freq	= cycles per second (Hz)
-- amp = amplitude (in radians)
-- phase = offset along the wave (in radians)
function MathsUtil.sin(t: number, freq: number, amp: number, phase: number?): number
	return math.sin(MathsUtil.tau * freq * t + (phase or 0)) * amp
end

return MathsUtil

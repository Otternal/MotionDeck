--!strict
-- MathsUtil

local MathsUtil = {}

-- One full turn in radians
MathsUtil.tau = 2 * math.pi

-- y(t) = amp * sin(tau * freq * t + phase)
-- t = time in seconds
-- freq = cycles per second (Hz)
-- amp = amplitude (in radians)
-- phase = offset along the wave (in radians)
function MathsUtil.sin(t: number, freq: number, amp: number, phase: number?): number
	return math.sin(MathsUtil.tau * freq * t + (phase or 0)) * amp
end

-- Loopable Perlin noise
-- Maps time to a point on a SMALL circle so noise variation is gentler
function MathsUtil.loopableNoise(t: number, duration: number, seed: number?): number
	if duration <= 0 then
		return 0
	end

	-- Map time to angle around a circle (0 to 2π over one loop)
	local angle = (t / duration) * MathsUtil.tau

	-- Use a small radius so we sample less noise variation
	-- Smaller radius = gentler noise
	local radius = 0.5

	local x = math.cos(angle) * radius
	local y = math.sin(angle) * radius

	return math.noise(x, y, seed or 0)
end

return MathsUtil

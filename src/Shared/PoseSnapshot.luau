--!strict
-- PoseSnapshot
-- Manages custom pose snapshots that procedural motion is layered on top of

local PoseSnapshot = {}

export type Pose = { [string]: CFrame }

-- The currently active pose snapshot (nil means no pose captured)
local activePose: Pose? = nil

function PoseSnapshot.capture(motors: { [string]: Motor6D })
	local pose: Pose = {}

	for motorName, motor in motors do
		if motor and motor.Parent then
			pose[motorName] = motor.C0
		end
	end

	activePose = pose
end

function PoseSnapshot.getBaseC0(motorName: string, fallback: CFrame): CFrame
	if activePose and activePose[motorName] then
		return activePose[motorName]
	end
	return fallback
end

-- Clear the captured pose (reset to default)
function PoseSnapshot.clear()
	activePose = nil
end

-- Check if a pose is currently captured
function PoseSnapshot.hasActivePose(): boolean
	return activePose ~= nil
end

-- Get the number of motors in the current pose (testing and status)
function PoseSnapshot.getPoseMotorCount(): number
	if not activePose then
		return 0
	end

	local count = 0
	for _ in activePose do
		count += 1
	end
	return count
end

return PoseSnapshot

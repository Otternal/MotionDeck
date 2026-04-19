--!strict
-- Constants

local Constants = {}

-- Maximum values for motion intensity
Constants.MAX_HEAD_ROTATION = 0.15 -- Max head pitch in radians
Constants.MAX_TORSO_PITCH = 0.08 -- Max torso rotation in radians
Constants.MAX_TORSO_LIFT = 0.1 -- Max torso Y movement in studs
Constants.MAX_ARM_SWING = 0.3 -- Max arm rotation in radians
Constants.MAX_ARM_BREATHING = 0.2 -- Max arm Y movement in studs
Constants.MAX_ARM_SPREAD = 0.3 -- Max arm spread rotation in radians
Constants.MAX_NOISE = 0.05 -- Max noise amplitude

-- Max delay in seconds
Constants.MAX_DELAY_SECONDS = 1.0

-- Leg IK
Constants.HIP_CENTER_ADJUSTMENT = 0.5
Constants.LEG_TILT_FACTOR = 2.0 -- How much the leg tilts per stud
Constants.MAX_LEG_TILT = 0.15 -- Maximum tilt in radians

-- Bake settings
Constants.BAKE_DURATION_SECONDS = 4.0 -- Fallback duration
Constants.BAKE_FPS = 60 -- Frames per second

-- Factory R6 motor C0 values
Constants.R6_FACTORY_C0 = {
	RootJoint = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0),
	Neck = CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi),
	LeftShoulder = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	RightShoulder = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
	LeftHip = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	RightHip = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0),
}

-- Factory R6 motor C1 values
Constants.R6_FACTORY_C1 = {
	RootJoint = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0),
	Neck = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi),
	LeftShoulder = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	RightShoulder = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
	LeftHip = CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	RightHip = CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0),
}

return Constants

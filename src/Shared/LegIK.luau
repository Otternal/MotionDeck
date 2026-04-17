--!strict
-- LegIK
-- R6 rig leg inverse kinematics solver
-- Keeps feet planted whilst the torso moves

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.MotionDeckShared.Constants)

local LegIK = {}

export type FootPlantData = {
	motor: Motor6D,
	legPart: BasePart,
	targetWorld: Vector3,
}

function LegIK.getLegBottomWorldPosition(legPart: BasePart): Vector3
	return (legPart.CFrame * CFrame.new(0, -legPart.Size.Y * 0.5, 0)).Position
end

-- Solves leg IK to keep the foot planted at targetWorld while the torso moves
function LegIK.solveR6PlantedLeg(hipMotor: Motor6D, legPart: BasePart, targetWorld: Vector3, originalHipC0: CFrame)
	local part0 = hipMotor.Part0
	if not part0 then
		return
	end

	local hipWorld = (part0.CFrame * originalHipC0).Position

	-- Adjust hip position inward towardS torso centre for more natural leg angle
	-- This compensates for R6 hips being offset to the sides of the torso (by 0.5)
	local torsoCenter = part0.Position
	local hipToCenter = (torsoCenter - hipWorld) * Vector3.new(1, 0, 1)
	local adjustedHipWorld = hipWorld + hipToCenter * Constants.HIP_CENTER_ADJUSTMENT

	local toTarget = targetWorld - adjustedHipWorld
	local distance = toTarget.Magnitude

	if distance < 1e-4 then
		hipMotor.C0 = originalHipC0
		return
	end

	local legLength = legPart.Size.Y

	if distance > legLength * 0.99 then
		distance = legLength * 0.99
	end

	local legDirection = toTarget.Unit

	local desiredCenter = adjustedHipWorld + legDirection * (legLength * 0.5)

	local legFront = part0.CFrame.RightVector

	local legUp = -legDirection

	local legRight = legFront:Cross(legUp)
	if legRight.Magnitude < 1e-4 then
		-- Fallback if front and up are parallel
		legFront = part0.CFrame.LookVector
		legRight = legFront:Cross(legUp)
	end
	legRight = legRight.Unit

	-- Recalculate front to be perpendicular
	legFront = legUp:Cross(legRight)

	-- Construct the leg's desired world CFrame
	local desiredLegWorld = CFrame.fromMatrix(desiredCenter, legRight, legUp, -legFront)

	-- Convert to C0 space (relative to torso)
	local newC0 = part0.CFrame:ToObjectSpace(desiredLegWorld * hipMotor.C1)

	hipMotor.C0 = newC0
end

return LegIK

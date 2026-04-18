--!strict
-- LegIK
-- R6 rig leg inverse kinematics solver

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

-- Solves leg IK
function LegIK.solveR6PlantedLeg(hipMotor: Motor6D, legPart: BasePart, targetWorld: Vector3, originalHipC0: CFrame)
	local part0 = hipMotor.Part0
	if not part0 then
		return
	end

	local hipWorld = (part0.CFrame * originalHipC0).Position

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
		legFront = part0.CFrame.LookVector
		legRight = legFront:Cross(legUp)
	end
	legRight = legRight.Unit

	-- Recalculate front to be perpendicular
	legFront = legUp:Cross(legRight)

	local desiredLegWorld = CFrame.fromMatrix(desiredCenter, legRight, legUp, -legFront)

	local newC0 = part0.CFrame:ToObjectSpace(desiredLegWorld * hipMotor.C1)

	hipMotor.C0 = newC0
end

return LegIK

--!strict
-- MotionDeck main
-- By Theodore McKenzie

-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

-----------------------------
-- MODULES --
-----------------------------
local MathsUtil = require(ReplicatedStorage.MotionDeckShared.MathsUtil)
local ParamDefs = require(ReplicatedStorage.MotionDeckShared.ParamDefs)
local Constants = require(ReplicatedStorage.MotionDeckShared.Constants)
local LegIK = require(ReplicatedStorage.MotionDeckShared.LegIK)

-----------------------------
-- PLUGIN SETUP --
-----------------------------
local toolbar = plugin:CreateToolbar("MotionDeck")
local button = toolbar:CreateButton("MotionDeck", "Open the MotionDeck interface", "rbxassetid://0")
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 400, 300, 200, 200)

local pluginGui = plugin:CreateDockWidgetPluginGuiAsync("MotionDeckUI", widgetInfo)
pluginGui.Title = "MotionDeck"

-----------------------------
-- UI MOUNT --
-----------------------------
local uiFolder = script.Parent:WaitForChild("UI")
local uiTemplateInst = uiFolder:WaitForChild("MainUI")

local activeModel: Model? = nil

local sliderConnections: { RBXScriptConnection } = {}

if not uiTemplateInst:IsA("Frame") then
	error("MotionDeck: MainUI must be a Frame")
end
local uiTemplate = uiTemplateInst :: Frame

local ui = uiTemplate:Clone()
ui.Parent = pluginGui
ui.Size = UDim2.fromScale(1, 1)
ui.Position = UDim2.fromScale(0, 0)

local function getRequiredFrame(parent: Instance, frameName: string): Frame
	local inst = parent:WaitForChild(frameName)

	if not inst:IsA("Frame") then
		error(`MotionDeck: {frameName} exists but is not a Frame`)
	end

	return inst
end

-- Frames
local rigFrame = getRequiredFrame(ui, "RigFrame")
local sliderFrame = getRequiredFrame(ui, "SliderFrame")
local statusFrame = getRequiredFrame(ui, "StatusFrame")
local previewFrame = getRequiredFrame(ui, "PreviewFrame")

-- Rig section
local targetLabel = rigFrame:WaitForChild("TargetLabel") :: TextLabel
local useSelectedBtn = rigFrame:WaitForChild("RigButton") :: TextButton

-- Sliders section
local paramsScroll = sliderFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame
paramsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- Status section
local statusLabel = statusFrame:WaitForChild("StateLabel") :: TextLabel

-- Preview section
local startPreviewBtn = previewFrame:WaitForChild("StartPreviewButton") :: TextButton
local stopPreviewBtn = previewFrame:WaitForChild("StopPreviewButton") :: TextButton
local bakePlayBtn = previewFrame:WaitForChild("BakeButton") :: TextButton

-----------------------------
-- STATE --
-----------------------------
local paramState: ParamDefs.ParamState = ParamDefs.makeDefaultState()

local activeMotors: { [string]: Motor6D } = {}
local t = 0

local lastSelectedModel: Model? = nil
local currentTrack: AnimationTrack? = nil
local originalC0Values: { [Motor6D]: CFrame } = {}

local footPlants: { [string]: LegIK.FootPlantData } = {}

print("MotionDeck plugin loaded successfully")

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function findMotor(parent: Instance, motorName: string): Motor6D?
	local m = parent:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
end

local function getSelectedModel(): Model?
	local sel = Selection:Get()
	if #sel == 0 then
		return nil
	end

	local inst = sel[1]
	if inst:IsA("Model") then
		return inst
	end

	return inst:FindFirstAncestorOfClass("Model")
end

local function getR6MotorsFromCharacter(model: Model): { [string]: Motor6D }
	local motors: { [string]: Motor6D } = {}

	local hrp = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("Torso")

	if hrp and hrp:IsA("BasePart") then
		local hrpPart = hrp :: BasePart

		local rootJoint = findMotor(hrpPart, "RootJoint")
		if rootJoint then
			motors.RootJoint = rootJoint
		end
	end

	if torso and torso:IsA("BasePart") then
		local torsoPart = torso :: BasePart

		local neck = findMotor(torsoPart, "Neck")
		if neck then
			motors.Neck = neck
		end

		local leftShoulder = findMotor(torsoPart, "Left Shoulder")
		if leftShoulder then
			motors.LeftShoulder = leftShoulder
		end

		local rightShoulder = findMotor(torsoPart, "Right Shoulder")
		if rightShoulder then
			motors.RightShoulder = rightShoulder
		end

		local leftHip = findMotor(torsoPart, "Left Hip")
		if leftHip then
			motors.LeftHip = leftHip
		end

		local rightHip = findMotor(torsoPart, "Right Hip")
		if rightHip then
			motors.RightHip = rightHip
		end
	end

	return motors
end

local function getR6PartsFromCharacter(model: Model): { [string]: BasePart }
	local parts: { [string]: BasePart } = {}

	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		parts.Torso = torso :: BasePart
	end

	local leftLeg = model:FindFirstChild("Left Leg")
	if leftLeg and leftLeg:IsA("BasePart") then
		parts.LeftLeg = leftLeg :: BasePart
	end

	local rightLeg = model:FindFirstChild("Right Leg")
	if rightLeg and rightLeg:IsA("BasePart") then
		parts.RightLeg = rightLeg :: BasePart
	end

	return parts
end

local function getOrCreateAnimator(model: Model): Animator?
	local humanoidInst = model:FindFirstChildOfClass("Humanoid")
	if not humanoidInst or not humanoidInst:IsA("Humanoid") then
		return nil
	end
	local humanoid = humanoidInst

	local animatorInst = humanoid:FindFirstChildOfClass("Animator")
	if animatorInst and animatorInst:IsA("Animator") then
		return animatorInst
	end

	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

local function resetPreviewTransforms()
	-- Restore original C0 values for all motors
	for motor, originalC0 in originalC0Values do
		if motor and motor.Parent then
			motor.C0 = originalC0
		end
	end
	table.clear(originalC0Values)
end

local previewConn: RBXScriptConnection? = nil

local function stopPreview()
	if previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end

	resetPreviewTransforms()
	t = 0
	table.clear(footPlants)
end

local function startPreview(motors: { [string]: Motor6D })
	stopPreview()

	activeMotors = motors

	table.clear(originalC0Values)
	for _, motor in motors do
		originalC0Values[motor] = motor.C0
	end

	table.clear(footPlants)

	if activeModel then
		local parts = getR6PartsFromCharacter(activeModel)

		if motors.LeftHip and parts.LeftLeg then
			footPlants.Left = {
				motor = motors.LeftHip,
				legPart = parts.LeftLeg,
				targetWorld = LegIK.getLegBottomWorldPosition(parts.LeftLeg),
			}
		end

		if motors.RightHip and parts.RightLeg then
			footPlants.Right = {
				motor = motors.RightHip,
				legPart = parts.RightLeg,
				targetWorld = LegIK.getLegBottomWorldPosition(parts.RightLeg),
			}
		end
	end

	local isEdit = RunService:IsEdit()
	local updateEvent = if isEdit then RunService.PreRender else RunService.Heartbeat

	previewConn = updateEvent:Connect(function(dt: number)
		local timeSpeed = paramState.TimeSpeed :: number
		t += dt * timeSpeed

		local freq = paramState.BreathingRate :: number

		local noiseIntensity = paramState.NoiseIntensity :: number

		local headIntensity = paramState.HeadIntensity :: number
		local headDelay = paramState.HeadDelay :: number

		local torsoPitchIntensity = paramState.TorsoPitchIntensity :: number
		local torsoPitchDelay = paramState.TorsoPitchDelay :: number

		local torsoLiftIntensity = paramState.TorsoLiftIntensity :: number
		local torsoLiftDelay = paramState.TorsoLiftDelay :: number

		local armSwingIntensity = paramState.ArmSwingIntensity :: number
		local armSwingDelay = paramState.ArmSwingDelay :: number

		local armBreathingIntensity = paramState.ArmBreathingIntensity :: number
		local armBreathingDelay = paramState.ArmBreathingDelay :: number

		local armSpreadIntensity = paramState.ArmSpreadIntensity :: number
		local armSpreadDelay = paramState.ArmSpreadDelay :: number

		local noiseAmp = noiseIntensity * Constants.MAX_NOISE

		local loopDuration = if freq > 0 then 1 / freq else 1

		local neckPitch = MathsUtil.sin(
			t,
			freq,
			headIntensity * Constants.MAX_HEAD_ROTATION,
			-headDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 1) * noiseAmp

		local torsoPitch = MathsUtil.sin(
			t,
			freq,
			torsoPitchIntensity * Constants.MAX_TORSO_PITCH,
			-torsoPitchDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 2) * noiseAmp

		local torsoY = -MathsUtil.sin(
			t,
			freq,
			torsoLiftIntensity * Constants.MAX_TORSO_LIFT,
			-torsoLiftDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 3) * noiseAmp

		local armSwing = MathsUtil.sin(
			t,
			freq,
			armSwingIntensity * Constants.MAX_ARM_SWING,
			-armSwingDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 4) * noiseAmp

		local armBounce = -MathsUtil.sin(
			t,
			freq,
			armBreathingIntensity * Constants.MAX_ARM_BREATHING,
			-armBreathingDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 5) * noiseAmp

		local armSpread = -MathsUtil.sin(
			t,
			freq,
			armSpreadIntensity * Constants.MAX_ARM_SPREAD,
			-armSpreadDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(t, loopDuration, 6) * noiseAmp

		if activeMotors.Neck then
			local origC0 = originalC0Values[activeMotors.Neck]
			if origC0 then
				activeMotors.Neck.C0 = origC0 * CFrame.Angles(neckPitch, 0, 0)
			end
		end

		if activeMotors.RootJoint then
			local origC0 = originalC0Values[activeMotors.RootJoint]
			if origC0 then
				activeMotors.RootJoint.C0 = origC0 * CFrame.new(0, 0, torsoY) * CFrame.Angles(torsoPitch, 0, 0)
			end
		end

		if activeMotors.LeftShoulder then
			local origC0 = originalC0Values[activeMotors.LeftShoulder]
			if origC0 then
				activeMotors.LeftShoulder.C0 = origC0
					* CFrame.new(0, armBounce, 0)
					* CFrame.Angles(-armSpread, 0, armSwing)
			end
		end

		if activeMotors.RightShoulder then
			local origC0 = originalC0Values[activeMotors.RightShoulder]
			if origC0 then
				activeMotors.RightShoulder.C0 = origC0
					* CFrame.new(0, armBounce, 0)
					* CFrame.Angles(-armSpread, 0, -armSwing)
			end
		end

		-- Leg IK
		if footPlants.Left and activeMotors.LeftHip then
			local origHipC0 = originalC0Values[activeMotors.LeftHip]
			if origHipC0 then
				LegIK.solveR6PlantedLeg(
					footPlants.Left.motor,
					footPlants.Left.legPart,
					footPlants.Left.targetWorld,
					origHipC0
				)
			end
		end

		if footPlants.Right and activeMotors.RightHip then
			local origHipC0 = originalC0Values[activeMotors.RightHip]
			if origHipC0 then
				LegIK.solveR6PlantedLeg(
					footPlants.Right.motor,
					footPlants.Right.legPart,
					footPlants.Right.targetWorld,
					origHipC0
				)
			end
		end
	end)
end

local function getLoopDurationFromBreathing(state: ParamDefs.ParamState, cycles: number): number
	local freq = state.BreathingRate :: number
	if freq <= 0 then
		return Constants.BAKE_DURATION_SECONDS
	end
	return (1 / freq) * cycles
end

local function bakeKeyframeSequence(state: ParamDefs.ParamState, duration: number, fps: number): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "MotionDeck_Baked"
	seq.Loop = true

	if not activeModel then
		return seq
	end

	local motors = getR6MotorsFromCharacter(activeModel)
	local restC0s: { [Motor6D]: CFrame } = {}
	local restC1s: { [Motor6D]: CFrame } = {}
	for _, motor in motors do
		restC0s[motor] = motor.C0
		restC1s[motor] = motor.C1
	end

	-- Set up foot plants from the rig's current foot positions
	local bakeFootPlants: { [string]: LegIK.FootPlantData } = {}
	local parts = getR6PartsFromCharacter(activeModel)
	if motors.LeftHip and parts.LeftLeg then
		bakeFootPlants.Left = {
			motor = motors.LeftHip,
			legPart = parts.LeftLeg,
			targetWorld = LegIK.getLegBottomWorldPosition(parts.LeftLeg),
		}
	end
	if motors.RightHip and parts.RightLeg then
		bakeFootPlants.Right = {
			motor = motors.RightHip,
			legPart = parts.RightLeg,
			targetWorld = LegIK.getLegBottomWorldPosition(parts.RightLeg),
		}
	end

	local frameCount = math.max(1, math.round(duration * fps))
	local dt = 1 / fps

	local freq = state.BreathingRate :: number
	local noiseIntensity = state.NoiseIntensity :: number
	local noiseAmp = noiseIntensity * Constants.MAX_NOISE
	local headIntensity = state.HeadIntensity :: number
	local headDelay = state.HeadDelay :: number
	local torsoPitchIntensity = state.TorsoPitchIntensity :: number
	local torsoPitchDelay = state.TorsoPitchDelay :: number
	local torsoLiftIntensity = state.TorsoLiftIntensity :: number
	local torsoLiftDelay = state.TorsoLiftDelay :: number
	local armSwingIntensity = state.ArmSwingIntensity :: number
	local armSwingDelay = state.ArmSwingDelay :: number
	local armBreathingIntensity = state.ArmBreathingIntensity :: number
	local armBreathingDelay = state.ArmBreathingDelay :: number
	local armSpreadIntensity = state.ArmSpreadIntensity :: number
	local armSpreadDelay = state.ArmSpreadDelay :: number

	local function applyFrame(time: number): { [string]: CFrame }
		local neckPitch = MathsUtil.sin(
			time,
			freq,
			headIntensity * Constants.MAX_HEAD_ROTATION,
			-headDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 1) * noiseAmp

		local torsoPitch = MathsUtil.sin(
			time,
			freq,
			torsoPitchIntensity * Constants.MAX_TORSO_PITCH,
			-torsoPitchDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 2) * noiseAmp

		local torsoY = -MathsUtil.sin(
			time,
			freq,
			torsoLiftIntensity * Constants.MAX_TORSO_LIFT,
			-torsoLiftDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 3) * noiseAmp

		local armSwing = MathsUtil.sin(
			time,
			freq,
			armSwingIntensity * Constants.MAX_ARM_SWING,
			-armSwingDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 4) * noiseAmp

		local armBounce = -MathsUtil.sin(
			time,
			freq,
			armBreathingIntensity * Constants.MAX_ARM_BREATHING,
			-armBreathingDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 5) * noiseAmp

		local armSpread = -MathsUtil.sin(
			time,
			freq,
			armSpreadIntensity * Constants.MAX_ARM_SPREAD,
			-armSpreadDelay * Constants.MAX_DELAY_SECONDS
		) + MathsUtil.loopableNoise(time, duration, 6) * noiseAmp

		local finalC0s: { [string]: CFrame } = {}

		if motors.Neck then
			local rest = restC0s[motors.Neck]
			if rest then
				local newC0 = rest * CFrame.Angles(neckPitch, 0, 0)
				motors.Neck.C0 = newC0
				finalC0s.Neck = newC0
			end
		end

		if motors.RootJoint then
			local rest = restC0s[motors.RootJoint]
			if rest then
				local newC0 = rest * CFrame.new(0, 0, torsoY) * CFrame.Angles(torsoPitch, 0, 0)
				motors.RootJoint.C0 = newC0
				finalC0s.RootJoint = newC0
			end
		end

		if motors.LeftShoulder then
			local rest = restC0s[motors.LeftShoulder]
			if rest then
				local newC0 = rest * CFrame.new(0, armBounce, 0) * CFrame.Angles(-armSpread, 0, armSwing)
				motors.LeftShoulder.C0 = newC0
				finalC0s.LeftShoulder = newC0
			end
		end

		if motors.RightShoulder then
			local rest = restC0s[motors.RightShoulder]
			if rest then
				local newC0 = rest * CFrame.new(0, armBounce, 0) * CFrame.Angles(-armSpread, 0, -armSwing)
				motors.RightShoulder.C0 = newC0
				finalC0s.RightShoulder = newC0
			end
		end

		if bakeFootPlants.Left and motors.LeftHip then
			local restHip = restC0s[motors.LeftHip]
			if restHip then
				LegIK.solveR6PlantedLeg(
					bakeFootPlants.Left.motor,
					bakeFootPlants.Left.legPart,
					bakeFootPlants.Left.targetWorld,
					restHip
				)
				finalC0s.LeftHip = motors.LeftHip.C0
			end
		end

		if bakeFootPlants.Right and motors.RightHip then
			local restHip = restC0s[motors.RightHip]
			if restHip then
				LegIK.solveR6PlantedLeg(
					bakeFootPlants.Right.motor,
					bakeFootPlants.Right.legPart,
					bakeFootPlants.Right.targetWorld,
					restHip
				)
				finalC0s.RightHip = motors.RightHip.C0
			end
		end

		return finalC0s
	end

	local function toPoseCFrame(motorName: string, finalC0: CFrame?): CFrame
		if not finalC0 then
			return CFrame.identity
		end

		local factoryC0 = Constants.R6_FACTORY_C0[motorName]
		local factoryC1 = Constants.R6_FACTORY_C1[motorName]
		if not factoryC0 or not factoryC1 then
			return CFrame.identity
		end

		local motor = motors[motorName]
		if not motor then
			return CFrame.identity
		end

		local liveC1 = restC1s[motor]
		if not liveC1 then
			return CFrame.identity
		end

		return factoryC0:Inverse() * finalC0 * liveC1:Inverse() * factoryC1
	end

	local function addKeyframeFromC0s(time: number, finalC0s: { [string]: CFrame })
		local kf = Instance.new("Keyframe")
		kf.Time = time
		kf.Parent = seq

		local hrpPose = Instance.new("Pose")
		hrpPose.Name = "HumanoidRootPart"
		hrpPose.CFrame = CFrame.identity
		hrpPose.Parent = kf

		local torsoPose = Instance.new("Pose")
		torsoPose.Name = "Torso"
		torsoPose.CFrame = toPoseCFrame("RootJoint", finalC0s.RootJoint)
		torsoPose.Parent = hrpPose

		local headPose = Instance.new("Pose")
		headPose.Name = "Head"
		headPose.CFrame = toPoseCFrame("Neck", finalC0s.Neck)
		headPose.Parent = torsoPose

		local leftArmPose = Instance.new("Pose")
		leftArmPose.Name = "Left Arm"
		leftArmPose.CFrame = toPoseCFrame("LeftShoulder", finalC0s.LeftShoulder)
		leftArmPose.Parent = torsoPose

		local rightArmPose = Instance.new("Pose")
		rightArmPose.Name = "Right Arm"
		rightArmPose.CFrame = toPoseCFrame("RightShoulder", finalC0s.RightShoulder)
		rightArmPose.Parent = torsoPose

		local leftLegPose = Instance.new("Pose")
		leftLegPose.Name = "Left Leg"
		leftLegPose.CFrame = toPoseCFrame("LeftHip", finalC0s.LeftHip)
		leftLegPose.Parent = torsoPose

		local rightLegPose = Instance.new("Pose")
		rightLegPose.Name = "Right Leg"
		rightLegPose.CFrame = toPoseCFrame("RightHip", finalC0s.RightHip)
		rightLegPose.Parent = torsoPose
	end

	for i = 0, frameCount - 1 do
		local time = i * dt
		local finalC0s = applyFrame(time)
		addKeyframeFromC0s(time, finalC0s)
	end

	do
		local finalC0s = applyFrame(duration)
		addKeyframeFromC0s(duration, finalC0s)
	end

	-- Restore the rig to its pre-bake state
	for motor, rest in restC0s do
		if motor and motor.Parent then
			motor.C0 = rest
		end
	end

	return seq
end

local function playBakedOnRig(model: Model, seq: KeyframeSequence)
	local animator = getOrCreateAnimator(model)
	if not animator then
		warn("MotionDeck: No Humanoid/Animator found!")
		return
	end

	local animId: string
	local success, result = pcall(function()
		return KeyframeSequenceProvider:RegisterActiveKeyframeSequence(seq)
	end)

	if success then
		animId = result
	else
		animId = KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	if currentTrack then
		currentTrack:Stop(0)
		currentTrack:Destroy()
		currentTrack = nil
	end

	local track = animator:LoadAnimation(anim)
	currentTrack = track

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.1)
end

local function getOrCreateFolder(): Folder
	local exports = ReplicatedStorage:FindFirstChild("MotionDeckExports")
	if exports then
		if exports:IsA("Folder") then
			return exports
		end
		error("MotionDeck: ReplicatedStorage.MotionDeckExports exists but is not a Folder")
	end

	local folder = Instance.new("Folder")
	folder.Name = "MotionDeckExports"
	folder.Parent = ReplicatedStorage
	return folder
end

local function exportKeyframeSequence(seq: KeyframeSequence, rigName: string): KeyframeSequence
	local exportsFolder = getOrCreateFolder()

	local clone = seq:Clone()

	local stamp = os.date("!%Y%m%d_%H%M%S")
	clone.Name = string.format("%s_%s", rigName, stamp)

	clone.Parent = exportsFolder
	return clone
end

local function setStatus(text: string)
	statusLabel.Text = "Status: " .. text
end

local function setTarget(model: Model?)
	activeModel = model
	if model then
		targetLabel.Text = "Target: " .. model.Name
	else
		targetLabel.Text = "Target: None"
	end
end

local function roundToStep(x: number, step: number): number
	return math.floor((x / step) + 0.5) * step
end

local function formatValue(x: number, unit: string?): string
	local s = string.format("%.3f", x)
	if unit and unit ~= "" then
		return s .. " " .. unit
	end
	return s
end

local function disconnectSliders()
	for _, c in sliderConnections do
		c:Disconnect()
	end
	table.clear(sliderConnections)
end

local function buildParamSliders(paramsScroll: ScrollingFrame)
	disconnectSliders()

	local templateInst = paramsScroll:WaitForChild("SliderRowTemplate")
	if not templateInst:IsA("Frame") then
		error("MotionDeck: SliderRowTemplate must be a Frame")
	end
	local template = templateInst :: Frame
	template.Visible = false

	for _, child in paramsScroll:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end

	paramState = ParamDefs.sanitiseState(paramState)

	for _, id in ParamDefs.getOrderedParamIds() do
		local def = ParamDefs.Defs[id]
		if def.kind ~= "number" then
			continue
		end
		local ndef = def :: ParamDefs.ParamNumberDef

		local row = template:Clone()
		row.Name = id
		row.Visible = true
		row.Parent = paramsScroll

		local paramLabel = row:WaitForChild("ParamLabel") :: TextLabel
		local valueLabel = row:WaitForChild("ValueLabel") :: TextLabel
		local bar = row:WaitForChild("Bar") :: Frame
		local knob = bar:WaitForChild("Knob") :: Frame

		if ndef.unit and ndef.unit ~= "" then
			paramLabel.Text = string.format("%s (%s)", ndef.label, ndef.unit)
		else
			paramLabel.Text = ndef.label
		end

		local step = ndef.step or 0.01

		local function setValue(newValue: number)
			newValue = math.clamp(newValue, ndef.min, ndef.max)
			newValue = roundToStep(newValue, step)
			newValue = math.clamp(newValue, ndef.min, ndef.max)

			paramState[id] = newValue
			valueLabel.Text = string.format("%.3f", newValue)

			local alpha = 0
			if ndef.max > ndef.min then
				alpha = (newValue - ndef.min) / (ndef.max - ndef.min)
			end

			knob.Position = UDim2.fromScale(alpha, 0.5)
		end

		local current = paramState[id]
		if typeof(current) ~= "number" then
			current = ndef.default
		end
		setValue(current :: number)

		local dragging = false

		local function valueFromMouseX(mouseX: number): number
			local x0 = bar.AbsolutePosition.X
			local w = bar.AbsoluteSize.X
			if w <= 0 then
				return ndef.default
			end

			local alpha = math.clamp((mouseX - x0) / w, 0, 1)
			return ndef.min + alpha * (ndef.max - ndef.min)
		end

		local function onInputBegan(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				setValue(valueFromMouseX(input.Position.X))
			end
		end

		local function onInputChanged(input: InputObject)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				setValue(valueFromMouseX(input.Position.X))
			end
		end

		local function onInputEnded(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end

		table.insert(sliderConnections, bar.InputBegan:Connect(onInputBegan))
		table.insert(sliderConnections, knob.InputBegan:Connect(onInputBegan))

		table.insert(sliderConnections, bar.InputChanged:Connect(onInputChanged))
		table.insert(sliderConnections, knob.InputChanged:Connect(onInputChanged))

		table.insert(sliderConnections, bar.InputEnded:Connect(onInputEnded))
		table.insert(sliderConnections, knob.InputEnded:Connect(onInputEnded))

		table.insert(
			sliderConnections,
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
		)
	end

	local layout = paramsScroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		paramsScroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y)
	else
		warn("MotionDeck: No UIListLayout found in paramsScroll")
	end
end

-----------------------------
-- HANDLERS --
-----------------------------
Selection.SelectionChanged:Connect(function()
	local current = getSelectedModel()
	if current ~= lastSelectedModel then
		stopPreview()
		lastSelectedModel = current
	end
end)

useSelectedBtn.MouseButton1Click:Connect(function()
	local model = getSelectedModel()
	if not model then
		setTarget(nil)
		setStatus("No selection")
		return
	end

	local motors = getR6MotorsFromCharacter(model)
	if not (motors.RootJoint or motors.Neck) then
		setTarget(nil)
		setStatus("Selection is not a valid R6 rig")
		return
	end

	setTarget(model)
	setStatus("Target set")
end)

startPreviewBtn.MouseButton1Click:Connect(function()
	if not activeModel then
		setStatus("No target set")
		return
	end

	paramState = ParamDefs.sanitiseState(paramState)
	if not (paramState.EnablePreview :: boolean) then
		setStatus("Preview disabled")
		return
	end

	local motors = getR6MotorsFromCharacter(activeModel)
	if not (motors.RootJoint or motors.Neck) then
		setTarget(nil)
		setStatus("Target invalid")
		return
	end

	startPreview(motors)
	setStatus("Previewing")
end)

stopPreviewBtn.MouseButton1Click:Connect(function()
	stopPreview()
	setStatus("Stopped")
end)

bakePlayBtn.MouseButton1Click:Connect(function()
	if not activeModel then
		setStatus("No target set")
		return
	end

	paramState = ParamDefs.sanitiseState(paramState)

	stopPreview()

	local duration = getLoopDurationFromBreathing(paramState, 1)
	local seq = bakeKeyframeSequence(paramState, duration, Constants.BAKE_FPS)
	local exported = exportKeyframeSequence(seq, activeModel.Name)

	setStatus("Baked and exported animation")

	Selection:Set({ exported })
end)

button.Click:Connect(function()
	pluginGui.Enabled = not pluginGui.Enabled
end)

-----------------------------
-- MAIN --
-----------------------------
setTarget(nil)
setStatus("Idle")
buildParamSliders(paramsScroll)

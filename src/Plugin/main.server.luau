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

-- Demo bake settings
local BAKE_DURATION_SECONDS = 4.0
local BAKE_FPS = 60

-- Neck motion delay
local NECK_LAG = 0.35

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
		local rootJoint = findMotor(hrp, "RootJoint")
		if rootJoint then
			motors.RootJoint = rootJoint
		end
	end

	if torso and torso:IsA("BasePart") then
		local neck = findMotor(torso, "Neck")
		if neck then
			motors.Neck = neck
		end
	end

	return motors
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
	if activeMotors.Neck then
		activeMotors.Neck.Transform = CFrame.identity
	end
	if activeMotors.RootJoint then
		activeMotors.RootJoint.Transform = CFrame.identity
	end
end

local previewConn: RBXScriptConnection? = nil

local function stopPreview()
	if previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end

	resetPreviewTransforms()
	t = 0
end

local function startPreview(motors: { [string]: Motor6D })
	stopPreview()

	activeMotors = motors

	previewConn = RunService.Heartbeat:Connect(function(dt: number)
		local timeSpeed = paramState.TimeSpeed :: number
		t += dt * timeSpeed

		local neckFreq = paramState.NeckPitchFreq :: number
		local neckAmp = paramState.NeckPitchAmp :: number
		local neckPhase = paramState.NeckPitchPhase :: number

		local rootFreq = paramState.RootRollFreq :: number
		local rootAmp = paramState.RootRollAmp :: number
		local rootPhase = paramState.RootRollPhase :: number

		local torsoPitchAmp = paramState.TorsoPitchAmp :: number
		local torsoYAmp = paramState.TorsoYAmp :: number

		local neckPitch = MathsUtil.sin(t, neckFreq, neckAmp, neckPhase - NECK_LAG)
		local rootRoll = MathsUtil.sin(t, neckFreq, rootAmp, rootPhase)
		local torsoPitch = MathsUtil.sin(t, neckFreq, torsoPitchAmp, neckPhase)
		local torsoY = -MathsUtil.sin(t, neckFreq, torsoYAmp, neckPhase)

		if activeMotors.Neck then
			activeMotors.Neck.Transform = CFrame.Angles(neckPitch, 0, 0)
		end
		if activeMotors.RootJoint then
			activeMotors.RootJoint.Transform = CFrame.new(0, 0, torsoY) * CFrame.Angles(torsoPitch, 0, rootRoll)
		end
	end)
end

local function getLoopDurationFromBreathing(state: ParamDefs.ParamState, cycles: number): number
	local freq = state.NeckPitchFreq :: number
	if freq <= 0 then
		return BAKE_DURATION_SECONDS
	end

	local period = 1 / freq
	return period * cycles
end

local function bakeKeyframeSequence(state: ParamDefs.ParamState, duration: number, fps: number): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "MotionDeck_Baked"
	seq.Loop = true

	local frameCount = math.floor(duration * fps)
	local dt = 1 / fps

	-- Read params
	local neckFreq = state.NeckPitchFreq :: number
	local neckAmp = state.NeckPitchAmp :: number
	local neckPhase = state.NeckPitchPhase :: number

	local rootFreq = state.RootRollFreq :: number
	local rootAmp = state.RootRollAmp :: number
	local rootPhase = state.RootRollPhase :: number

	local torsoPitchAmp = state.TorsoPitchAmp :: number
	local torsoYAmp = state.TorsoYAmp :: number

	local function addKeyframe(time: number, neckPitch: number, rootRoll: number, torsoPitch: number, torsoY: number)
		local kf = Instance.new("Keyframe")
		kf.Time = time
		kf.Parent = seq

		-- Pose hierarchy
		local hrpPose = Instance.new("Pose")
		hrpPose.Name = "HumanoidRootPart"
		hrpPose.CFrame = CFrame.identity
		hrpPose.Parent = kf

		local torsoPose = Instance.new("Pose")
		torsoPose.Name = "Torso"
		torsoPose.CFrame = CFrame.new(0, 0, torsoY) * CFrame.Angles(torsoPitch, 0, rootRoll)
		torsoPose.Parent = hrpPose

		local headPose = Instance.new("Pose")
		headPose.Name = "Head"
		headPose.CFrame = CFrame.Angles(neckPitch, 0, 0)
		headPose.Parent = torsoPose
	end

	for i = 0, frameCount - 1 do
		local time = i * dt

		local neckPitch = MathsUtil.sin(time, neckFreq, neckAmp, neckPhase - NECK_LAG)
		local rootRoll = MathsUtil.sin(time, neckFreq, rootAmp, rootPhase)
		local torsoPitch = MathsUtil.sin(time, neckFreq, torsoPitchAmp, neckPhase)
		local torsoY = -MathsUtil.sin(time, neckFreq, torsoYAmp, neckPhase)

		addKeyframe(time, neckPitch, rootRoll, torsoPitch, torsoY)
	end

	do
		local time = duration

		local neckPitch = MathsUtil.sin(time, neckFreq, neckAmp, neckPhase - NECK_LAG)
		local rootRoll = MathsUtil.sin(time, neckFreq, rootAmp, rootPhase)
		local torsoPitch = MathsUtil.sin(time, neckFreq, torsoPitchAmp, neckPhase)
		local torsoY = -MathsUtil.sin(time, neckFreq, torsoYAmp, neckPhase)

		addKeyframe(time, neckPitch, rootRoll, torsoPitch, torsoY)
	end

	return seq
end

local function playBakedOnRig(model: Model, seq: KeyframeSequence)
	local animator = getOrCreateAnimator(model)
	if not animator then
		warn("MotionDeck: No Humanoid/Animator found!")
		return
	end

	-- Register a local test animation id
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

	-- Stop previous track
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

	-- Template
	local templateInst = paramsScroll:WaitForChild("SliderRowTemplate")
	if not templateInst:IsA("Frame") then
		error("MotionDeck: SliderRowTemplate must be a Frame")
	end
	local template = templateInst :: Frame
	template.Visible = false

	-- Clear previously created rows
	for _, child in paramsScroll:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end

	-- Making sure paramState is valid
	paramState = ParamDefs.sanitiseState(paramState)

	for _, id in ParamDefs.getOrderedParamIds() do
		local def = ParamDefs.Defs[id]
		if def.kind ~= "number" then
			continue
		end
		local ndef = def :: ParamDefs.ParamNumberDef

		-- Clone row template
		local row = template:Clone()
		row.Name = id
		row.Visible = true
		row.Parent = paramsScroll

		-- Get all UI elements
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

			-- Centre knob
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end

		-- Initiate from state
		local current = paramState[id]
		if typeof(current) ~= "number" then
			current = ndef.default
		end
		setValue(current :: number)

		-- Drag logic
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

		-- Connect once per slider
		table.insert(sliderConnections, bar.InputBegan:Connect(onInputBegan))
		table.insert(sliderConnections, knob.InputBegan:Connect(onInputBegan))

		table.insert(sliderConnections, bar.InputChanged:Connect(onInputChanged))
		table.insert(sliderConnections, knob.InputChanged:Connect(onInputChanged))

		table.insert(sliderConnections, bar.InputEnded:Connect(onInputEnded))
		table.insert(sliderConnections, knob.InputEnded:Connect(onInputEnded))

		-- Safety inclusion
		table.insert(
			sliderConnections,
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
		)
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
	local seq = bakeKeyframeSequence(paramState, duration, BAKE_FPS)
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

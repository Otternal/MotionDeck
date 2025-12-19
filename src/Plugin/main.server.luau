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

if not uiTemplateInst:IsA("Frame") then
	error("MotionDeck: MainUI must be a Frame")
end
local uiTemplate = uiTemplateInst :: Frame

local ui = uiTemplate:Clone()
ui.Parent = pluginGui
ui.Size = UDim2.fromScale(1, 1)
ui.Position = UDim2.fromScale(0, 0)

-----------------------------
-- STATE --
-----------------------------
local paramState: ParamDefs.ParamState = ParamDefs.makeDefaultState()

local activeMotors: { [string]: Motor6D } = {}
local t = 0

local activeModel: Model? = nil
local lastSelectedModel: Model? = nil
local currentTrack: AnimationTrack? = nil

-- Demo bake settings
local BAKE_DURATION_SECONDS = 4.0
local BAKE_FPS = 30

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

-- NOTE: live preview loop exists but is intentionally not called in the current demo build
-- TODO: renable live preview in UI
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

		local neckPitch = MathsUtil.sin(t, neckFreq, neckAmp, neckPhase)
		local rootRoll = MathsUtil.sin(t, rootFreq, rootAmp, rootPhase)

		if activeMotors.Neck then
			activeMotors.Neck.Transform = CFrame.Angles(neckPitch, 0, 0)
		end
		if activeMotors.RootJoint then
			activeMotors.RootJoint.Transform = CFrame.Angles(0, 0, rootRoll)
		end
	end)
end

local function bakeKeyframeSequence(state: ParamDefs.ParamState, duration: number, fps: number): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "MotionDeck_Baked"

	local frameCount = math.floor(duration * fps)
	local dt = 1 / fps

	-- Read params
	local neckFreq = state.NeckPitchFreq :: number
	local neckAmp = state.NeckPitchAmp :: number
	local neckPhase = state.NeckPitchPhase :: number

	local rootFreq = state.RootRollFreq :: number
	local rootAmp = state.RootRollAmp :: number
	local rootPhase = state.RootRollPhase :: number

	local function addKeyframe(time: number, neckPitch: number, rootRoll: number)
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
		torsoPose.CFrame = CFrame.Angles(0, 0, rootRoll)
		torsoPose.Parent = hrpPose

		local headPose = Instance.new("Pose")
		headPose.Name = "Head"
		headPose.CFrame = CFrame.Angles(neckPitch, 0, 0)
		headPose.Parent = torsoPose
	end

	for i = 0, frameCount - 1 do
		local time = i * dt

		local neckPitch = MathsUtil.sin(time, neckFreq, neckAmp, neckPhase)
		local rootRoll = MathsUtil.sin(time, rootFreq, rootAmp, rootPhase)

		addKeyframe(time, neckPitch, rootRoll)
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

-----------------------------
-- HANDLERS --
-----------------------------
Selection.SelectionChanged:Connect(function()
	local current = getSelectedModel()
	if current ~= lastSelectedModel then
		stopPreview()
		lastSelectedModel = current
		print("Selection changed: preview stopped + transforms reset")
	end
end)

button.Click:Connect(function()
	pluginGui.Enabled = not pluginGui.Enabled
	-- Toolbar button toggles UI
	-- pluginGui.Enabled = not pluginGui.Enabled
	-- print("Button pressed!")

	-- local model = getSelectedModel()
	-- if not model then
	-- 	print("No model selected.")
	-- 	return
	-- end
	-- lastSelectedModel = model

	-- Validate state
	-- paramState = ParamDefs.sanitiseState(paramState)

	-- local motors = getR6MotorsFromCharacter(model)
	-- For testing purposes
	-- print("Selected model:", model:GetFullName())
	-- print(
	-- 	"Found motors:",
	-- 	"RootJoint =",
	-- 	motors.RootJoint and motors.RootJoint:GetFullName() or "nil",
	-- 	"Neck =",
	-- 	motors.Neck and motors.Neck:GetFullName() or "nil"
	-- )

	-- local enable = paramState.EnablePreview :: boolean
	-- if not enable then
	-- 	stopPreview()
	-- 	print("Preview disabled")
	-- 	return
	-- end

	-- if not (motors.RootJoint or motors.Neck) then
	-- 	stopPreview()
	-- 	print("No valid R6 motors found")
	-- 	return
	-- end

	-- FOR TESTING PURPOSES! bake & play immediately.
	-- TODO: use UI
	-- stopPreview()
	-- local seq = bakeKeyframeSequence(paramState, BAKE_DURATION_SECONDS, BAKE_FPS)
	-- playBakedOnRig(model, seq)
	-- print("Baked and playing")
end)

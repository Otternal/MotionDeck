--!strict
-- MotionDeck main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathsUtil = require(ReplicatedStorage.MotionDeckShared.MathsUtil)
local ParamDefs = require(ReplicatedStorage.MotionDeckShared.ParamDefs)

local RunService = game:GetService("RunService")

local toolbar = plugin:CreateToolbar("MotionDeck")
local button = toolbar:CreateButton("MotionDeck", "Open the MotionDeck interface", "rbxassetid://0")
button.ClickableWhenViewportHidden = true

local paramState = ParamDefs.makeDefaultState()
local activeMotors: { [string]: Motor6D } = {}
local previewConn: RBXScriptConnection? = nil
local previewTask: thread? = nil
local previewRunning = false
local t = 0

-- For testing purposes to see if the plugin has loaded
print("MotionDeck plugin loaded successfully")

-- Plugin widget
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 400, 300, 200, 200)

local pluginGui = plugin:CreateDockWidgetPluginGuiAsync("MotionDeckUI", widgetInfo)
pluginGui.Title = "MotionDeck"

-- BUTTON GOES HERE

local Selection = game:GetService("Selection")

local function getSelectedModel(): Model?
	local sel = Selection:Get()
	if #sel == 0 then
		return nil
	end

	-- If part is selected inside the rig, find the ancestor model
	local inst = sel[1]
	local model = inst:FindFirstAncestorOfClass("Model")
	if model then
		return model
	end
	if inst:IsA("Model") then
		return inst
	end
	return nil
end

local function findMotor(parent: Instance, motorName: string): Motor6D?
	local m = parent:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
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

local function resetPreviewTransforms()
	if activeMotors.Neck then
		activeMotors.Neck.Transform = CFrame.identity
	end
	if activeMotors.RootJoint then
		activeMotors.RootJoint.Transform = CFrame.identity
	end
end

local function stopPreview()
	previewRunning = false

	if previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end

	previewTask = nil

	resetPreviewTransforms()
	t = 0
end

local function startPreview(motors: { [string]: Motor6D })
	stopPreview() -- Prevents multiple loops from stacking

	activeMotors = motors
	t = 0
	previewRunning = true

	local last = os.clock()

	previewTask = task.spawn(function()
		while previewRunning do
			local now = os.clock()
			local dt = now - last
			last = now

			local timeSpeed = paramState.TimeSpeed :: number
			t += dt * timeSpeed

			-- Read parameters
			local neckFreq = paramState.NeckPitchFreq :: number
			local neckAmp = paramState.NeckPitchAmp :: number
			local neckPhase = paramState.NeckPitchPhase :: number

			local rootFreq = paramState.RootRollFreq :: number
			local rootAmp = paramState.RootRollAmp :: number
			local rootPhase = paramState.RootRollPhase :: number

			-- Calculate procedural values
			local neckPitch = MathsUtil.sin(t, neckFreq, neckAmp, neckPhase)
			local rootRoll = MathsUtil.sin(t, rootFreq, rootAmp, rootPhase)

			-- Apply transforms
			if activeMotors.Neck then
				activeMotors.Neck.Transform = CFrame.Angles(neckPitch, 0, 0)
			end
			if activeMotors.RootJoint then
				activeMotors.RootJoint.Transform = CFrame.Angles(0, 0, rootRoll)
			end

			task.wait()
		end
	end)
end

-- Toggle visibility
button.Click:Connect(function()
	pluginGui.Enabled = not pluginGui.Enabled
	print("Button pressed!")

	local model = getSelectedModel()
	if not model then
		print("No model selected.")
		return
	end

	local motors = getR6MotorsFromCharacter(model)
	print("Selected model:", model:GetFullName())
	print(
		"Found motors:",
		"RootJoint =",
		motors.RootJoint and motors.RootJoint:GetFullName() or "nil",
		"Neck =",
		motors.Neck and motors.Neck:GetFullName() or "nil"
	)

	-- Update state from default values
	paramState = ParamDefs.sanitiseState(paramState)

	local enable = paramState.EnablePreview :: boolean
	if not enable then
		stopPreview()
		print("Preview disabled")
		return
	end

	if motors.RootJoint or motors.Neck then
		startPreview(motors)
		print("Preview started")
		print(t)
	else
		stopPreview()
		print("No valid R6 motors found")
	end
end)

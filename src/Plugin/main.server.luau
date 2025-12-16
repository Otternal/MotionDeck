--!strict
-- MotionDeck main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathsUtil = require(ReplicatedStorage.MotionDeckShared.MathsUtil)
local ParamDefs = require(ReplicatedStorage.MotionDeckShared.ParamDefs)

local toolbar = plugin:CreateToolbar("MotionDeck")
local button = toolbar:CreateButton("MotionDeck", "Open the MotionDeck interface", "rbxassetid://0")
button.ClickableWhenViewportHidden = true

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
end)

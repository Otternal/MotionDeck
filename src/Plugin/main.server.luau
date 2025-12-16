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

-- Toggle visibility
button.Click:Connect(function()
	pluginGui.Enabled = not pluginGui.Enabled
	print("Button pressed!")
end)

local defaultState = ParamDefs.makeDefaultState()
print("Default param state:")
print(defaultState)

local messy = { NeckPitchAmp = 999, EnablePreview = "yeah" }
local clean = ParamDefs.sanitiseState(messy :: any)
print("Sanitised state:")
print(clean)

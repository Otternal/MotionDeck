--!strict
-- ParamDefs
-- Defines all animation parameters such as defaults and ranges,
-- and provides helpers to create a parameter state table.

export type ParamNumberDef = {
	kind: "number",
	label: string,
	order: number,

	default: number,
	min: number,
	max: number,

	-- UI
	step: number?,
	unit: string?,
}

export type ParamBoolDef = {
	kind: "bool",
	label: string,
	order: number,

	default: boolean,
}

export type ParamDef = ParamNumberDef | ParamBoolDef
export type ParamId = string

export type ParamState = { [ParamId]: number | boolean }

local Params = {}

Params.Defs = {
	-- Global
	TimeSpeed = {
		kind = "number",
		label = "Preview Speed",
		order = 1,
		default = 1.0,
		min = 0.1,
		max = 3.0,
		step = 0.1,
		unit = "x",
	} :: ParamNumberDef,

	BreathingRate = {
		kind = "number",
		label = "Breathing Rate",
		order = 2,
		default = 0.25,
		min = 0.125,
		max = 1.0,
		step = 0.125,
		unit = "Hz",
	} :: ParamNumberDef,

	-- Head
	HeadIntensity = {
		kind = "number",
		label = "Head Intensity",
		order = 10,
		default = 0.5,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	HeadDelay = {
		kind = "number",
		label = "Head Delay",
		order = 11,
		default = 0.85,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Torso Pitch
	TorsoPitchIntensity = {
		kind = "number",
		label = "Torso Pitch Intensity",
		order = 20,
		default = 0.4,
		min = 0.0,
		max = 2.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	TorsoPitchDelay = {
		kind = "number",
		label = "Torso Pitch Delay",
		order = 21,
		default = 0.5,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Torso Lift
	TorsoLiftIntensity = {
		kind = "number",
		label = "Torso Lift Intensity",
		order = 22,
		default = 0.4,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	TorsoLiftDelay = {
		kind = "number",
		label = "Torso Lift Delay",
		order = 23,
		default = 0.0,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Arm Swing
	ArmSwingIntensity = {
		kind = "number",
		label = "Arm Swing Intensity",
		order = 30,
		default = 0.3,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	ArmSwingDelay = {
		kind = "number",
		label = "Arm Swing Delay",
		order = 31,
		default = 0.85,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Arm Breathing
	ArmBreathingIntensity = {
		kind = "number",
		label = "Arm Breathing Intensity",
		order = 32,
		default = 0.3,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	ArmBreathingDelay = {
		kind = "number",
		label = "Arm Breathing Delay",
		order = 33,
		default = 0.15,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Arm Spread
	ArmSpreadIntensity = {
		kind = "number",
		label = "Arm Spread Intensity",
		order = 34,
		default = 0.2,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	ArmSpreadDelay = {
		kind = "number",
		label = "Arm Spread Delay",
		order = 35,
		default = 0.3,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Noise
	NoiseIntensity = {
		kind = "number",
		label = "Motion Randomness",
		order = 40,
		default = 0.2,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Debugging
	EnablePreview = {
		kind = "bool",
		label = "Enable Preview",
		order = 3,
		default = true,
	} :: ParamBoolDef,
} :: { [ParamId]: ParamDef }

-- Makes a table containing all default parameters
function Params.makeDefaultState(): ParamState
	local state: ParamState = {}
	for id, def in Params.Defs do
		state[id] = def.default
	end
	return state
end

-- Validate an inputted state
function Params.sanitiseState(input: ParamState?): ParamState
	local out: ParamState = {}

	for id, def in Params.Defs do
		local value = if input ~= nil then input[id] else nil

		if def.kind == "number" then
			if typeof(value) == "number" then
				out[id] = math.clamp(value :: number, def.min, def.max)
			else
				out[id] = def.default
			end
		else
			if typeof(value) == "boolean" then
				out[id] = value :: boolean
			else
				out[id] = def.default
			end
		end
	end

	return out
end

-- Get definitions sorted by order
function Params.getOrderedParamIds(): { ParamId }
	local ids: { ParamId } = {}
	for id in Params.Defs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Params.Defs[a].order < Params.Defs[b].order
	end)
	return ids
end

return Params

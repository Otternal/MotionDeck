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
	-- Time/preview controls
	TimeSpeed = {
		kind = "number",
		label = "Preview Speed",
		order = 1,
		default = 1.0,
		min = 0.0,
		max = 3.0,
		step = 0.01,
		unit = "x",
	} :: ParamNumberDef,

	-- Breathing (Neck)
	NeckPitchFreq = {
		kind = "number",
		label = "Neck Pitch Frequency",
		order = 10,
		default = 0.25,
		min = 0.125,
		max = 2.0,
		step = 0.125,
		unit = "Hz",
	} :: ParamNumberDef,

	NeckPitchAmp = {
		kind = "number",
		label = "Neck Pitch Amplitude",
		order = 11,
		default = 0.06,
		min = 0.0,
		max = 0.25,
		step = 0.001,
		unit = "rad",
	} :: ParamNumberDef,

	NeckPitchPhase = {
		kind = "number",
		label = "Neck Pitch Phase",
		order = 12,
		default = 0.0,
		min = -math.pi,
		max = math.pi,
		step = 0.01,
		unit = "rad",
	} :: ParamNumberDef,

	-- Torso sway
	RootRollFreq = {
		kind = "number",
		label = "Root Roll Frequency",
		order = 20,
		default = 0.25,
		min = 0.125,
		max = 2.0,
		step = 0.125,
		unit = "Hz",
	} :: ParamNumberDef,

	RootRollAmp = {
		kind = "number",
		label = "Root Roll Amplitude",
		order = 21,
		default = 0.04,
		min = 0.0,
		max = 0.25,
		step = 0.001,
		unit = "rad",
	} :: ParamNumberDef,

	RootRollPhase = {
		kind = "number",
		label = "Root Roll Phase",
		order = 22,
		default = 0.0,
		min = -math.pi,
		max = math.pi,
		step = 0.01,
		unit = "rad",
	} :: ParamNumberDef,

	TorsoPitchAmp = {
		kind = "number",
		label = "Torso Pitch Amplitude",
		order = 13,
		default = 0.03,
		min = 0.0,
		max = 0.20,
		step = 0.001,
		unit = "rad",
	} :: ParamNumberDef,

	TorsoYAmp = {
		kind = "number",
		label = "Torso Y Amplitude",
		order = 14,
		default = 0.03,
		min = 0.0,
		max = 0.20,
		step = 0.001,
		unit = "stud",
	} :: ParamNumberDef,

	-- Arm sway
	ArmSwingFreq = {
		kind = "number",
		label = "Arm Swing Frequency",
		order = 30,
		default = 0.25,
		min = 0.125,
		max = 2.0,
		step = 0.125,
		unit = "Hz",
	} :: ParamNumberDef,

	ArmSwingAmp = {
		kind = "number",
		label = "Arm Swing Amplitude",
		order = 31,
		default = 0.08,
		min = 0.0,
		max = 0.4,
		step = 0.001,
		unit = "rad",
	} :: ParamNumberDef,

	ArmSwingPhase = {
		kind = "number",
		label = "Arm Swing Phase",
		order = 32,
		default = 0.0,
		min = -math.pi,
		max = math.pi,
		step = 0.01,
		unit = "rad",
	} :: ParamNumberDef,

	ArmBounceFactor = {
		kind = "number",
		label = "Arm Breathing Amplitude",
		order = 33,
		default = 0.3,
		min = 0.0,
		max = 1.0,
		step = 0.01,
		unit = "",
	} :: ParamNumberDef,

	-- Debugging
	EnablePreview = {
		kind = "bool",
		label = "Enable Preview",
		order = 2,
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

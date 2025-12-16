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

local Params = {}

return Params

local table = require 'table'

local function makeAccessorName(prefix: string, fieldName: string): string
  local s: string = fieldName:upper()
  return table.concat({prefix, s:sub(1, 1), fieldName:sub(2)}, '')
end

local function makeFieldVarName(fieldName: string): string
  local s: string = fieldName:upper()
  return table.concat({'m', s:sub(1, 1), fieldName:sub(2)}, '')
end

return {
  makeAccessorName = makeAccessorName,
  makeFieldVarName = makeFieldVarName
}

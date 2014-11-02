local table = require 'table'

local _M = {}

function _M.makeAccessorName(prefix: string, fieldName: string)
  return table.concat({prefix, fieldName:upper():sub(1, 1), fieldName:sub(2)}, '')
end

function _M.makeFieldVarName(fieldName: string)
  return table.concat({'m', fieldName:upper():sub(1, 1), fieldName:sub(2)}, '')
end

return _M

local table = require("table")
local _M = {}
_M["makeAccessorName"] = function (prefix, fieldName)
  return table["concat"]({prefix, fieldName:upper():sub(1,1), fieldName:sub(2)},"")
end
_M["makeFieldVarName"] = function (fieldName)
  return table["concat"]({"m", fieldName:upper():sub(1,1), fieldName:sub(2)},"")
end
return _M


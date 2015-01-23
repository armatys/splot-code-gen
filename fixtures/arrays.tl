local _M = {}

_M.a1 = {1, 2, 3, 4}

local _a2: {number} = {1, 2, 3, 4}
_M.a2 = _a2

_M.a3 = {'a', 'b', 'c'}

local _a4: {string} = {'a', 'b', 'c'}
_M.a4 = _a4

return _M

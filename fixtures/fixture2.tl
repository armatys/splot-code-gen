local _M = {}

function _M.hello()
  print("Hello!")
end

function _M.hi(name: string): (string?, integer)
  return "Hi " .. name, #name
end

return _M

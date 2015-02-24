local _M = {}

function _M.hello()
  print("Hello!")
end

function _M.hi(name: string): string
  return "Hi " .. name
end

return _M

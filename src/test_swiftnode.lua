local SwiftNode = require 'swiftnode'
local table = require 'table'

describe('Test Swift code generator.', function()
  it('should work', function()
    local result = 42
    assert.is.equals(42, result)
  end)
end)

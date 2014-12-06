local Node = require 'node'
local table = require 'table'

local function makecode(fn)
  local ct = Node:new()
  if fn then
    fn(ct)
  end
  return table.concat(ct:tree(), '\n')
end

describe('Test codetree generator.', function()
  it('should produce an empty string', function()
    local code = Node:new():code()
    assert.are.equals('', code)
  end)

  it('should produce an empty block', function()
    local code = Node:new()
      :insertleft '{'
      :insertright '}'
      :code()
    assert.are.equals('{\n}', code)
  end)

  it('should produce an empty block', function()
    local code = Node:new():insertleft '{\n}':code()
    assert.are.equals('{\n}', code)
  end)

  it('should produce an empty block', function()
    local code = Node:new():insertright '{\n}':code()
    assert.are.equals('{\n}', code)
  end)

  it('should produce an indented statement', function()
    local code = Node:new()
      :child(Node:new():insertleft 'int a = 5;')
      :code()
    assert.are.equals('  int a = 5;', code)
  end)

  it('should produce a statement inside a block', function()
    local code = Node:new()
      :insertleft '{'
      :child(Node:new():insertleft 'int a = 5;')
      :insertright '}'
      :code()
    assert.are.equals('{\n  int a = 5;\n}', code)
  end)

  it('should produce a statement inside a block (even when adding the code in different order)', function()
    local code = Node:new()
      :insertright '}'
      :child(Node:new():insertleft 'int a = 5;')
      :insertleft 'while (0)'
      :insertleft '{'
      :code()
    assert.are.equals('while (0)\n{\n  int a = 5;\n}', code)
  end)

  it('should produce multiple-level blocks', function()
    local code = Node:new()
      :insertleft '{'
      :child(Node:new():insertleft 'int a = 5;')
      :child(Node:new():insertleft 'int b = 6;')
      :child(Node:new()
        :insertleft 'if (a > b) {'
        :insertright '}'
        :child(Node:new():insertleft 'printf("a is greater than b");')
      )
      :insertright '}'
      :code()
    assert.are.equals([[
{
  int a = 5;
  int b = 6;
  if (a > b) {
    printf("a is greater than b");
  }
}]], code)
  end)

  it('should produce multiple nested blocks', function()
    local code = Node:new()
      :insertleft '{'
      :insertright '}'
      :child(Node:new()
        :insertleft '{'
        :insertright '}'
        :child(Node:new()
          :insertleft'{'
          :insertright '}'
        )
      )
      :code()
    assert.are.equals([[
{
  {
    {
    }
  }
}]], code)
  end)

  it('should create a function on the same level as parent', function()
    local code = Node:new()
      :joinleft(Node:new()
        :insertleft 'int calculate(int a, int b) {'
        :insertright '}'
        :child(Node:new():insertleft 'return a + b;')
        :tree()
      )
      :code()
    assert.are.equals([[
int calculate(int a, int b) {
  return a + b;
}]], code)
  end)
end)
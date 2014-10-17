local JavaNode = require 'javatree'.JavaNode
local table = require 'table'

describe('Test Java code generator.', function()
  it('import a single class', function()
    local code = JavaNode:new():import('java.lang.String'):code()
    assert.is.equals('import java.lang.String;', code)
  end)

  it('should create a simple class', function()
    local code = JavaNode:newclass('Test'):code()
    assert.is.equals([[
class Test {
}]], code)
  end)

  it('should create a public class', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'}):code()
    assert.is.equals([[
public class Test {
}]], code)
  end)

  it('should create a static class', function()
    local code = JavaNode:newclass('Test', {static = true}):code()
    assert.is.equals([[
static class Test {
}]], code)
  end)

  it('should create a public static class', function()
    local code = JavaNode:newclass('Test', {visibility = 'public', static = true}):code()
    assert.is.equals([[
public static class Test {
}]], code)
  end)

  it('should create a public class with import', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :import('java.util.ArrayList')
      :code()
    assert.is.equals([[
import java.util.ArrayList;
public class Test {
}]], code)
  end)

  it('should create a public class with an inner class', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :child(JavaNode:newclass('InnerTest'))
      :code()
    assert.is.equals([[
public class Test {
  class InnerTest {
  }
}]], code)
  end)

  it('should create a public class with a private inner class', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :child(JavaNode:newclass('InnerTest', {visibility = 'private'}))
      :code()
    assert.is.equals([[
public class Test {
  private class InnerTest {
  }
}]], code)
  end)

  it('should create a public class with a static and private inner class', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :child(JavaNode:newclass('InnerTest', {static = true, visibility = 'private'}))
      :code()
    assert.is.equals([[
public class Test {
  private static class InnerTest {
  }
}]], code)
  end)

  it('should not accept an invalid visibility specifier', function()
    assert.has_error(function()
      JavaNode:newclass('Test', {visibility = 'secret'})
    end)
  end)

  it('should create a public class with an inner class with import', function()
    local code = JavaNode:newclass('Test')
      :child(JavaNode:newclass('InnerTest'):import('java.util.HashMap'))
      :code()
    assert.is.equals([[
import java.util.HashMap;
class Test {
  class InnerTest {
  }
}]], code)
  end)
end)
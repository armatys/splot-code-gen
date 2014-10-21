local javatree = require 'javatree'
local JavaNode = javatree.JavaNode
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

  it('should create a public class with a field', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String'})
      :code()
    assert.is.equals([[
public class Test {
  String mText ;
}]], code)
  end)

  it('should fail creating a public class with a field with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:newclass('Test', {visibility = 'public'})
        :field({fieldName = 'text', fieldType = 'String', visibility = 'secret'})
    end)
  end)

  it('should fail creating getter with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:newclass('Test', {visibility = 'public'})
        :field({fieldName = 'text', fieldType = 'String', getter = true, getterVisibility = 'secret'})
    end)
  end)

  it('should fail creating setter with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:newclass('Test', {visibility = 'public'})
        :field({fieldName = 'text', fieldType = 'String', setter = true, setterVisibility = 'secret'})
    end)
  end)

  it('should create a public class with a private field', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private'})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
}]], code)
  end)

  it('should create a public class with optional private field', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', optional = true})
      :code()
    assert.is.equals([[
import javax.annotation.Nullable;
public class Test {
  private @Nullable String mText ;
}]], code)
  end)

  it('should create a public class with a private field with a default getter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', getter = true})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  String getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private optional field with a default getter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', optional = true, getter = true})
      :code()
    assert.is.equals([[
import javax.annotation.Nullable;
public class Test {
  private @Nullable String mText ;
  @Nullable String getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a public default getter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', getter = true, getterVisibility = 'public'})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  public String getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a default setter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', setter = true})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  void setText ( String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with an optional private field with default value and a default setter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', optional = true, fieldInit = '"hello"', setter = true})
      :code()
    assert.is.equals([[
import javax.annotation.Nullable;
public class Test {
  private @Nullable String mText = "hello" ;
  void setText ( @Nullable String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a public default setter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', setter = true, setterVisibility = 'public'})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  public void setText ( String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a default getter and setter', function()
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = 'text', fieldType = 'String', visibility = 'private', getter = true, setter = true})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  String getText ( ) {
    return mText ;
  }
  void setText ( String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a custom public getter', function()
    local fieldName = 'text'
    local varName = javatree.makeFieldVarName(fieldName)
    local getterCode = string.format([[
System.out.println("Getter");
return %s;]], varName)
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = fieldName, fieldType = 'String', visibility = 'private', getterVisibility = 'public', getter = getterCode})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  public String getText ( ) {
    System.out.println("Getter");
    return mText;
  }
}]], code)
  end)

  it('should create a public class with a private field with a custom public setter', function()
    local fieldName = 'text'
    local varName = javatree.makeFieldVarName(fieldName)
    local setterCode = string.format([[
System.out.println("Setter");
%s = %s;]], varName, fieldName)
    local code = JavaNode:newclass('Test', {visibility = 'public'})
      :field({fieldName = fieldName, fieldType = 'String', visibility = 'private', setterVisibility = 'public', setter = setterCode})
      :code()
    assert.is.equals([[
public class Test {
  private String mText ;
  public void setText ( String text ) {
    System.out.println("Setter");
    mText = text;
  }
}]], code)
  end)
end)
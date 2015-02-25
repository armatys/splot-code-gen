local javautils = require 'javautils'
local JavaNode = require 'javanode'
local table = require 'table'

describe('Test Java code generator.', function()
  it('import a single class', function()
    local code = JavaNode:new():import('java.lang.String'):code()
    assert.is.equals('import io.splot.data.*;\nimport java.lang.String;', code)
  end)

  it('should create a simple class', function()
    local code = JavaNode:new():setclass('Test'):code()
    assert.is.equals([[
import io.splot.data.*;
class Test {
}]], code)
  end)

  it('should create a public class', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'}):code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
}]], code)
  end)

  it('should create a static class', function()
    local code = JavaNode:new():setclass('Test', {static = true}):code()
    assert.is.equals([[
import io.splot.data.*;
static class Test {
}]], code)
  end)

  it('should create a public static class', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public', static = true}):code()
    assert.is.equals([[
import io.splot.data.*;
public static class Test {
}]], code)
  end)

  it('should create a public class with import', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :import('java.util.ArrayList')
      :code()
    assert.is.equals([[
import io.splot.data.*;
import java.util.ArrayList;
public class Test {
}]], code)
  end)

  it('should create a public class with an inner class', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :child(JavaNode:new():setclass('InnerTest').node)
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  class InnerTest {
  }
}]], code)
  end)

  it('should create a public class with a private inner class', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :child(JavaNode:new():setclass('InnerTest', {visibility = 'private'}).node)
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private class InnerTest {
  }
}]], code)
  end)

  it('should create a public class with a static and private inner class', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :child(JavaNode:new():setclass('InnerTest', {static = true, visibility = 'private'}).node)
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private static class InnerTest {
  }
}]], code)
  end)

  it('should not accept an invalid visibility specifier', function()
    assert.has_error(function()
      JavaNode:new():setclass('Test', {visibility = 'secret'})
    end)
  end)

  it('should create a public class with an inner class with import', function()
    local code = JavaNode:new():setclass('Test')
      :child(JavaNode:new():setclass('InnerTest'):import('java.util.HashMap').node)
      :code()
    assert.is.equals([[
import io.splot.data.*;
import java.util.HashMap;
class Test {
  class InnerTest {
  }
}]], code)
  end)

  it('should create a public class with a field', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  String mText ;
}]], code)
  end)

  it('should fail creating a public class with a field with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:new():setclass('Test', {visibility = 'public'})
        :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'secret'})
    end)
  end)

  it('should fail creating getter with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:new():setclass('Test', {visibility = 'public'})
        :field({valueInfo={name = 'text', paramType = 'String'}, getter = true, getterVisibility = 'secret'})
    end)
  end)

  it('should fail creating setter with invalid visibility', function()
    assert.has_error(function()
      local code = JavaNode:new():setclass('Test', {visibility = 'public'})
        :field({valueInfo={name = 'text', paramType = 'String'}, setter = true, setterVisibility = 'secret'})
    end)
  end)

  it('should create a public class with a private field', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
}]], code)
  end)

  it('should create a public class with optional private field', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String', optional = true}, visibility = 'private'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private Optional<String> mText ;
}]], code)
  end)

  it('should create a public class with a private field with a default getter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private', getter = true})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
  String getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private optional field with a default getter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String', optional = true}, visibility = 'private', getter = true})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private Optional<String> mText ;
  Optional<String> getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a public default getter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private', getter = true, getterVisibility = 'public'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
  public String getText ( ) {
    return mText ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a default setter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private', setter = true})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
  void setText ( String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with an optional private field with default value and a default setter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String', optional = true, defaultValue = '"hello"'}, visibility = 'private', setter = true})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private Optional<String> mText = "hello" ;
  void setText ( Optional<String> text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a public default setter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private', setter = true, setterVisibility = 'public'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
  public void setText ( String text ) {
    mText = text ;
  }
}]], code)
  end)

  it('should create a public class with a private field with a default getter and setter', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = 'text', paramType = 'String'}, visibility = 'private', getter = true, setter = true})
      :code()
    assert.is.equals([[
import io.splot.data.*;
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
    local varName = javautils.makeFieldVarName(fieldName)
    local getterCode = string.format([[
System.out.println("Getter");
return %s;]], varName)
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = fieldName, paramType = 'String'}, visibility = 'private', getterVisibility = 'public', getter = getterCode})
      :code()
    assert.is.equals([[
import io.splot.data.*;
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
    local varName = javautils.makeFieldVarName(fieldName)
    local setterCode = string.format([[
System.out.println("Setter");
%s = %s;]], varName, fieldName)
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name = fieldName, paramType = 'String'}, visibility = 'private', setterVisibility = 'public', setter = setterCode})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  private String mText ;
  public void setText ( String text ) {
    System.out.println("Setter");
    mText = text;
  }
}]], code)
  end)

  it('should create a public class with an empty constructor', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :constructor()
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  Test ( ) {
  }
}]], code)
  end)

  it('should create a public class with an empty protected constructor', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :constructor({visibility = 'protected'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  protected Test ( ) {
  }
}]], code)
  end)

  it('should create a public class with a custom public constructor', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :constructor({
        visibility = 'public',
        code = [[
super();
]]
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  public Test ( ) {
    super();
  }
}]], code)
  end)

  it('should create a public class with a custom public constructor with params and a field', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :field({valueInfo={name='answer', paramType='int'}})
      :constructor({
        visibility = 'public',
        params = { {name='answer', paramType='int'} },
        code = [[
mAnswer = answer;
]]
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  int mAnswer ;
  public Test ( int answer ) {
    mAnswer = answer;
  }
}]], code)
  end)

  it('should create a public class with a custom constructor with optional params', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :constructor({
        params = { {name='answer', paramType='int'}, {name='text', paramType='String', optional=true} },
        code = [[
// Custom constructor
]]
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  Test ( int answer , Optional<String> text ) {
    // Custom constructor
  }
}]], code)
  end)

  it('should create a class with an empty constructor with optional param and default value', function()
    local code = JavaNode:new():setclass('Test', {visibility = 'public'})
      :constructor({
        params = { {name='text', paramType='String', optional=true, defaultValue='"Hi!"'} },
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  Test ( Optional<String> text ) {
    if (text == null) {
      text = "Hi!";
    }
  }
}]], code)
  end)

  it('should create a public class with a public method', function()
    local code = JavaNode:new()
      :setclass('Test', {visibility = 'public'})
      :method({methodName='foo', returnSpec={valueInfos={{paramType='void'}}}, visibility='public', code='System.out.println("Hello foo");'})
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  public void foo ( ) {
    System.out.println("Hello foo");
  }
}]], code)
  end)

  it('should create a public class with a public method that throws an Exception', function()
    local code = JavaNode:new()
      :setclass('Test', {visibility = 'public'})
      :method({
        methodName='foo',
        returnSpec={valueInfos={{paramType='void'}}},
        visibility='public',
        code='System.out.println("Hello foo");',
        throws={'Exception'}
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  public void foo ( ) throws Exception {
    System.out.println("Hello foo");
  }
}]], code)
  end)

  it('should create a public class with a public method that throws two exceptions', function()
    local code = JavaNode:new()
      :setclass('Test', {visibility = 'public'})
      :method({
        methodName='foo',
        returnSpec={valueInfos={{paramType='void'}}},
        visibility='public',
        code='System.out.println("Hello foo");',
        throws={'NumberFormatException', 'IndexOutOfBoundsException'}
      })
      :code()
    assert.is.equals([[
import io.splot.data.*;
public class Test {
  public void foo ( ) throws NumberFormatException, IndexOutOfBoundsException {
    System.out.println("Hello foo");
  }
}]], code)
  end)
end)
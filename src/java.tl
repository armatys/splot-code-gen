local JavaNode = require 'javanode'
local serpent = require 'serpent'
local table = require 'table'

local interface Context
  luaModuleName: string
  javaModuleName: string
  plainAst: {any: any}
  typecheckedAst: {any: any}
end

local function makeTopLevelConstructor(className, luaModuleName): JavaConstructorSpec
  local constructor: JavaConstructorSpec = {
    visibility = 'public',
    params = { {name='context', paramType='Context'} },
    code = string.gsub([[
mEngine = new SplotEngine(context);
mLuaModuleName = "_LUA_MODULE_NAME_";
try {
  mEngine.loadLuaModule(mLuaModuleName);
} catch (IOException e) {
  mEngine = null;
  throw new RuntimeException(e);
}
mLuaTableRef = mEngine.addTableReference();
]], '_LUA_MODULE_NAME_', luaModuleName)
  }
  return constructor
end

local function makeInnerLevelConstructor(className): JavaConstructorSpec
  -- TODO
  local constructor: JavaConstructorSpec = {}
  return constructor
end

local function makeClassFinalizer(): JavaMethodSpec
  local spec: JavaMethodSpec = {
    methodName = 'finalize',
    returnSpec = {returnType='void'},
    visibility = 'protected',
    throws = {'Throwable'},
    code = [[
if (mEngine != null) {
  mEngine.removeTableReference(mLuaTableRef);
}
super.finalize();]]
  }
  return spec
end

local function processTTable(context: Context, ttable: {any: any}, topLevel: boolean?): JavaNode
  local javaNode: JavaNode = JavaNode:new()
  javaNode:package('splot')
  javaNode:import('android.content.Context')
  javaNode:import('io.splot.LuaTable')
  javaNode:import('io.splot.SplotEngine')

  -- Class

  local className: string = topLevel and context.javaModuleName or 'TInnerClass' -- TODO infer the class name (for inner classes)
  local classDescr: JavaClassDescriptor = {
    visibility = 'public',
    static = not topLevel,
    implements = {'LuaTable'}
  }
  javaNode:setclass(className, classDescr)

  -- Fields

  javaNode:field({
    fieldName = 'engine',
    fieldType = 'SplotEngine',
    visibility = 'private',
    getter = true,
    getterVisibility = 'public'
  })

  javaNode:field({
    fieldName = 'luaModuleName',
    fieldType = 'String',
    visibility = 'private',
    getter = true,
    getterVisibility = 'public'
  })

  javaNode:field({
    fieldName = 'luaTableRef',
    fieldType = 'int',
    visibility = 'private',
    getter = true,
    getterVisibility = 'public'
  })

  -- Constructor

  if topLevel then
    javaNode:constructor(makeTopLevelConstructor(className, context.luaModuleName))
  else
    javaNode:constructor(makeInnerLevelConstructor(className))
  end

  -- Finalizer

  javaNode:method(makeClassFinalizer())


  -- Other methods, fields and inner classes

  for _, moduleField in ipairs(ttable) do
    if moduleField.tag == 'Id' then
      -- TODO Find the field's definition
    elseif moduleField.tag ~= 'TField' then
      print('-- ' .. tostring(serpent.block(moduleField)))
      print('Skipping ' .. tostring(moduleField.tag) .. ' field.')
    else
      -- local codeTable = javaProcessField(moduleField)
      -- table.insert(codeBuf, codeTable)
      print('Processing ' .. tostring(serpent.line(moduleField)))
    end
  end
  
  return javaNode
end

local function findReturnNode(ast: {any: any}): (number, any)?
  for i, v in ipairs(ast) do
    if v.tag == 'Return' then
      return i, v
    end
  end
  return nil, 'Could not find the return node.'
end

local function process(luaModuleName: string, javaModuleName: string, plainAst: {any: any}, typecheckedAst: {any: any}): string
  local ctx: Context = {
    luaModuleName = luaModuleName,
    javaModuleName = javaModuleName,
    plainAst = plainAst,
    typecheckedAst = typecheckedAst
  }
  local i, retNode = findReturnNode(typecheckedAst)
  if not i then
    error(retNode, 2)
  end

  local rootNode: JavaNode = processTTable(ctx, retNode, true)
  local code: string = rootNode:code()
  return code
end


return {
  name = 'Java',
  process = process
}
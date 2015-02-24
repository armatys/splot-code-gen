local JavaNode = require 'javanode'
local pretty = require 'pretty'
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
  local constructor: JavaConstructorSpec = {
    visibility = 'public',
    params = {
      {name='engine', paramType='SplotEngine'},
      {name='useTopTable', paramType='boolean'}
    },
    code = [[
mEngine = engine;
if (!useTopTable) {
  mEngine.getLuaState().createTable(0, 0);
}
mLuaTableRef = mEngine.addTableReference();
]]
  }
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

local function getJavaBaseType(typedLuaT: string): string
  if typedLuaT == 'boolean' then
    return 'Boolean'
  elseif typedLuaT == 'number' then
    return 'Double'
  elseif typedLuaT == 'integer' then
    return 'Integer'
  elseif typedLuaT == 'string' then
    return 'io.splot.LuaString'
  end
  error('Unsupported type ' .. tostring(typedLuaT))
  return ''
end

local function getJavaMethodParam(paramName: string, nodeType: {any: any}): JavaMethodParam
  if (nodeType.tag == 'TBase') then
    local tname = getJavaBaseType(nodeType[1])
    return {name = paramName, paramType = tname}
  elseif nodeType.tag == 'TNil' then
    return {name = paramName, paramType = 'void'}
  elseif nodeType.tag == 'TUnion' then
    if nodeType[1].tag == 'TNil' then
      local tname = getJavaMethodParam(nodeType[2]).paramType
      return {name = paramName, paramType = tname, optional = true}
    elseif nodeType[2].tag == 'TNil' then
      local tname = getJavaMethodParam(nodeType[1]).paramType
      return {name = paramName, paramType = tname, optional = true}
    else
      error('Union types not yet supported.')
    end
  elseif nodeType.tag == 'TValue' then
    return {name = paramName, paramType = 'Object'}
  elseif nodeType.tag == 'TVararg' then
    local tname = getJavaMethodParam(nodeType[1]).paramType .. '...'
    return {name = paramName, paramType = tname}
  elseif nodeType.tag == 'TTable' then
    -- if not fieldName then
    --   error('Missing field name parameter.', 2)
    -- end
    -- return 'T' .. fieldName
  end

  error('Unsupported node type: ' .. tostring(nodeType.tag))
  return {paramType=''}
end

local function findIdTable(parentTable: {any: any}, q: {any: any}): {any: any}?
  for _, v in pairs(parentTable) do
    if type(v) == 'table' then
      if v == q and parentTable.tag == 'Id' then
        return parentTable
      else
        local t = findIdTable(v, q)
        if t then
          return t
        end
      end
    end
  end
  return nil
end

local function findMethodParamName(context: Context, paramNode: {any: any}): string?
  -- Within the `context`, find a table with `Id` tag,
  -- where one of the number-indexed child of that table is the `param` table.
  local t = findIdTable(context.typecheckedAst, paramNode)
  return t and t[1] or nil
end

local function getMethodParams(context: Context, paramsTuple: {any: any}) : {JavaMethodParam}
  local paramsLen = #paramsTuple
  local params: {JavaMethodParam} = {}
  for i=1,paramsLen do
    local param: {any: any} = paramsTuple[i]
    if param.tag ~= 'TVararg' and param[1].tag ~= 'TValue' or i < paramsLen then
      local paramName: string = findMethodParamName(context, param) or ('param' .. tostring(i))
      local paramSpec: JavaMethodParam = getJavaMethodParam(paramName, param)
      table.insert(params, #params + 1, paramSpec)
    end
  end
  return params
end

local function getMethodReturnType(context: Context, returnsTuple: {any: any}): JavaMethodReturn
  return {
    returnType = 'void'
  }
end

local function processFunction(context: Context, funcName: string, fieldValueNode: {any: any}, parentClass: JavaNode)
  -- print('processFunction ' .. pretty.write(fieldValueNode))
  local paramsTuple = fieldValueNode[1]
  local returnsTuple = fieldValueNode[2]

  if paramsTuple.tag ~= 'TTuple' then
    error('The function ' .. funcName .. ' has incorrect parameter type: ' .. paramsTuple.tag)
  end
  if returnsTuple.tag ~= 'TTuple' then
    error('The function ' .. funcName .. ' has incorrect return type: ' .. returnsTuple.tag)
  end

  local params: {JavaMethodParam} = getMethodParams(context, paramsTuple)
  local returnSpec: JavaMethodReturn = getMethodReturnType(returnsTuple)

  parentClass:method({
    methodName = funcName,
    visibility = 'public',
    params = params,
    returnSpec = returnSpec
  })
end

local function processPlainTableField(context: Context, fieldKeyNode: {any: any}, fieldValueNode: {any: any}, parentClass: JavaNode)
  local fieldName = fieldKeyNode[1]
  local tag = fieldValueNode.tag

  if tag == 'TBase' then
    -- generateJavaBaseProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TFunction' then
    processFunction(context, fieldName, fieldValueNode, parentClass)
  elseif tag == 'TTable' then
    -- generateJavaClassProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TUnion' then
    -- generateJavaUnionType(fieldName, fieldValueNode, codeBuf)
  end
end

local function processTableField(context: Context, field: {any: any}, parentClass: JavaNode)
  local fieldKeyNode = field[1]
  local fieldValueNode = field[2]

  if fieldKeyNode.tag == 'TLiteral' then
    return processPlainTableField(context, fieldKeyNode, fieldValueNode, parentClass)
  elseif fieldKeyNode.tag == 'TBase' then
    -- return generateJavaMapFields(fieldKeyNode, fieldValueNode)
  else
    error('Invalid field name node: ' .. fieldKeyNode.tag)
  end
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
    static = not topLevel, -- only inner classes should be static
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
    fieldName = 'luaTableRef',
    fieldType = 'int',
    visibility = 'private',
    getter = true,
    getterVisibility = 'public'
  })

  if topLevel then
    javaNode:field({
      fieldName = 'luaModuleName',
      fieldType = 'String',
      visibility = 'private',
      getter = true,
      getterVisibility = 'public'
    })
  end

  -- Constructor

  if topLevel then
    javaNode:constructor(makeTopLevelConstructor(className, context.luaModuleName))
  else
    javaNode:constructor(makeInnerLevelConstructor(className))
  end

  -- Finalizer

  javaNode:method(makeClassFinalizer())


  -- Other methods, fields and inner classes

  for _, val in ipairs(ttable) do
    if val.tag ~= 'TField' then
      print('-- ' .. tostring(pretty.write(val)))
      print('SKIPPING ' .. tostring(val.tag) .. ' field.')
    else
      -- local codeTable = javaProcessField(val)
      -- table.insert(codeBuf, codeTable)
      -- print('Processing ' .. tostring(pretty.write(val)))
      processTableField(context, val, javaNode)
    end
  end
  
  return javaNode
end

local function processReturnNode(context: Context, node: {any: any}): JavaNode
  if node.tag == 'Table' then
    --
  elseif node.tag == 'Id' then
    --
  else
    error('Unknown tag for the return node: ' .. node.tag)
  end
  return JavaNode:new()
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
  print('Processing module: ' .. luaModuleName)
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

  local node = retNode[1]
  if not node.type or node.type.tag ~= 'TTable' then
    error('Returned node for ' .. luaModuleName .. ' should be a table, while it currently is ' .. pretty.write(node.type))
  end

  -- print(pretty.write(typecheckedAst))
  local rootNode: JavaNode = processTTable(ctx, node.type, true)
  -- local rootNode: JavaNode = processReturnNode(ctx, node)
  local code: string = rootNode:code()
  return code
end


return {
  name = 'Java',
  process = process
}
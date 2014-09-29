local string = require 'string'
local table = require 'table'

local LuaTableRefVarType = 'Int32'
local SwiftFuncParamPrefix = 'param'

local swiftProcessTable

local function getSwiftBaseType(typedLuaT)
  if typedLuaT == 'boolean' then
    return 'Bool'
  elseif typedLuaT == 'number' then
    return 'Double'
  elseif typedLuaT == 'string' then
    return 'NSData'
  else
    error('Unsupported type ' .. tostring(typedLuaT))
  end
end

local function getSwiftType(nodeType, fieldName)
  if nodeType.tag == 'TBase' then
    return getSwiftBaseType(nodeType[1])
  elseif nodeType.tag == 'TNil' then
    return 'Void'
  elseif nodeType.tag == 'TUnion' then
    if nodeType[1].tag == 'TNil' then
      return getSwiftType(nodeType[2], fieldName) .. '?'
    elseif nodeType[2].tag == 'TNil' then
      return getSwiftType(nodeType[1], fieldName) .. '?'
    else
      error('Union types not yet supported.')
    end
  elseif nodeType.tag == 'TValue' then
    return 'Any'
  elseif nodeType.tag == 'TVararg' then
    return getSwiftType(nodeType[1], fieldName) .. '...'
  elseif nodeType.tag == 'TTable' then
    if not fieldName then
      error('Missing field name parameter.', 2)
    end
    return 'T' .. fieldName
  else
    error('Unsupported node type: ' .. tostring(nodeType.tag))
  end
end

local function generateSwiftBaseProperty(fieldKeyName, fieldValueNode, codeBuf, optional)
  optional = optional or false
  local swiftType = getSwiftType(fieldValueNode) .. (optional and '?' or '')
  local fieldName = type(fieldKeyName) == 'string' and fieldKeyName or ('_' .. tostring(fieldKeyName))
  table.insert(codeBuf, string.format('var %s: %s {', fieldName, swiftType))
  
  -- getter
  table.insert(codeBuf, 'get {')
  table.insert(codeBuf, 'self.engine.saveStack()')
  table.insert(codeBuf, 'var L = self.engine.luaState')
  table.insert(codeBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')
  
  if type(fieldKeyName) == 'string' then
    table.insert(codeBuf, string.format('lua_getfield(L, -1, "%s")', fieldName))
  elseif type(fieldKeyName) == 'number' then
    table.insert(codeBuf, string.format('lua_pushnumber(L, %d)', fieldKeyName))
    table.insert(codeBuf, string.format('lua_gettable(L, -2)', fieldKeyName))
  else
    error('Unsupported key type: ' .. type(fieldKeyName))
  end
  
  if optional then
    table.insert(codeBuf, 'if lua_type(L, -1) == LUA_TNIL {')
    table.insert(codeBuf, '  self.engine.restoreStack()')
    table.insert(codeBuf, '  return nil')
    table.insert(codeBuf, '}')
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'var a: Bool = lua_toboolean(L, -1)')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return a')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'var a: Double = lua_tonumber(L, -1)')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return a')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'var l: size_t = 0')
    table.insert(codeBuf, 'var s = lua_tolstring(L, -1, &l)')
    table.insert(codeBuf, 'var data: NSData = NSData(bytes: UnsafePointer<Void>(s), length: Int(l))')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return data')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end
  table.insert(codeBuf, '}')

  -- setter

  table.insert(codeBuf, 'set {')
  table.insert(codeBuf, 'self.engine.saveStack()')
  table.insert(codeBuf, 'var L = self.engine.luaState')
  table.insert(codeBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')

  -- push key

  if type(fieldKeyName) == 'string' then
    table.insert(codeBuf, string.format('lua_pushstring(L, "%s")', fieldKeyName))
  elseif type(fieldKeyName) == 'number' then
    table.insert(codeBuf, string.format('lua_pushnumber(L, %d)', fieldKeyName))
  else
    error('Unsupported key type: ' .. type(fieldKeyName))
  end

  -- push value
  
  if optional then
    table.insert(codeBuf, 'if let v = newValue? {')
  else
    table.insert(codeBuf, 'let v = newValue')
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'lua_pushboolean(L, v)')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'lua_pushnumber(L, v)')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'lua_pushlstring(L, UnsafePointer<Int8>(v.bytes), UInt(v.length))')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end

  if optional then
    table.insert(codeBuf, '} else {')
    table.insert(codeBuf, '  lua_pushnil(L)')
    table.insert(codeBuf, '}')
  end

  table.insert(codeBuf, 'lua_settable(L, -3)')
  table.insert(codeBuf, 'self.engine.restoreStack()')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, '}')
end

local function generateTableParamType(funcName, i)
  return 'PT' .. funcName .. tostring(i)
end

local function generateSwiftFuncParams(funcName, funcParamsNode)
  if funcParamsNode.tag ~= 'TTuple' then
    error('Unsupported node: ' .. tostring(funcParamsNode.tag))
  end

  local classesCode
  local codeBuf = {}
  local nargs = 0

  -- Iterate over parameter list
  for i, v in ipairs(funcParamsNode) do
    local swiftType
    if v.tag == 'TTable' then
      classesCode = classesCode or {}
      swiftType = generateTableParamType(funcName, i)
      table.insert(classesCode, swiftProcessTable(swiftType, v))
    end

    swiftType = swiftType or getSwiftType(v)

    -- Skip the last argument, if it's a dummy placeholder
    if v.tag ~= 'TVararg' and v[1].tag ~= 'TValue' or i < #funcParamsNode then
      local param = {}
      table.insert(param, SwiftFuncParamPrefix .. tostring(i) .. ': ')
      table.insert(param, swiftType)
      table.insert(codeBuf, table.concat(param))
      nargs = nargs + 1
    end
  end

  return '(' .. table.concat(codeBuf, ', ') .. ')', classesCode, nargs
end

local function generateTableRetType(funcName, i)
  return 'RT' .. funcName .. tostring(i)
end

local function generateSwiftFuncRet(funcName, funcRetNode)
  if funcRetNode.tag ~= 'TTuple' then
    error('Unsupported node: ' .. tostring(funcRetNode.tag))
  end

  local classesCode
  local codeBuf = {}
  local nresults = 0

  -- Iterate over parameter list
  for i, v in ipairs(funcRetNode) do
    local swiftType
    if v.tag == 'TTable' then
      classesCode = classesCode or {}
      swiftType = generateTableRetType(funcName, i)
      table.insert(classesCode, swiftProcessTable(swiftType, v))
    end

    swiftType = swiftType or getSwiftType(v)

    -- Skip the last argument, if it's a dummy placeholder
    if v.tag ~= 'TVararg' and v[1].tag ~= 'TNil' or i < #funcRetNode then
      table.insert(codeBuf, swiftType)
      nresults = nresults + 1
    end
  end

  return '(' .. table.concat(codeBuf, ', ') .. ')', classesCode, nresults
end

local function generateSwiftFunction(funcName, fieldValueNode, codeBuf)
  local funcHeaderFmt = 'func %s%s -> %s {'
  local funcParamsNode = fieldValueNode[1]
  local funcRetNode = fieldValueNode[2]

  local funcParamsTuple, funcParamsClasses, nargs = generateSwiftFuncParams(funcName, funcParamsNode)
  local funcRetTuple, funcRetClasses, nresults = generateSwiftFuncRet(funcName, funcRetNode)
  local funcHeader = string.format(funcHeaderFmt, funcName, funcParamsTuple, funcRetTuple)

  if funcParamsClasses then
    table.insert(codeBuf, funcParamsClasses)
  end
  if funcRetClasses then
    table.insert(codeBuf, funcRetClasses)
  end
  table.insert(codeBuf, funcHeader)
  
  local innerBuf = {}
  table.insert(innerBuf, 'self.engine.saveStack()')
  table.insert(innerBuf, 'var L = self.engine.luaState')

  -- push the function
  table.insert(innerBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')
  table.insert(innerBuf, string.format('lua_getfield(L, -1, "%s")', funcName))

  -- arguments
  for i, paramNode in ipairs(funcParamsNode) do
    local optional = paramNode.tag == 'TUnion'
    local paramName = SwiftFuncParamPrefix .. tostring(i)

    if optional then
      table.insert(innerBuf, string.format('if %s == nil {', paramName))
      table.insert(innerBuf, '  lua_pushnil(L)')
      table.insert(innerBuf, '} else {')
      paramName = paramName .. '!'
      paramNode = paramNode[1].tag == 'TNil' and paramNode[2] or paramNode[1]
    end

    if paramNode.tag == 'TBase' then
      if paramNode[1] == 'boolean' then
        table.insert(innerBuf, string.format('lua_pushboolean(L, %s ? 1 : 0)', paramName))
      elseif paramNode[1] == 'number' then
        table.insert(innerBuf, string.format('lua_pushnumber(L, %s)', paramName))
      elseif paramNode[1] == 'string' then
        table.insert(innerBuf, string.format('lua_pushlstring(L, UnsafePointer<Int8>(%s.bytes), UInt(%s.length))', paramName, paramName))
      else
        error('Unsupported node type: ' .. tostring(paramNode[1]))
      end
    elseif paramNode.tag == 'TTable' then
      table.insert(innerBuf, string.format('lua_rawgeti(L, LUA_GLOBALSINDEX, %s.luaTableRef)', paramName))
    elseif paramNode.tag == 'TVararg' and paramNode[1].tag == 'TValue' then
      -- Ignore
    else
      error('Unsupported node type: ' .. tostring(paramNode.tag))
    end

    if optional then
      table.insert(innerBuf, '}')
    end
  end

  table.insert(innerBuf, string.format('lua_call(L, %d, %d)', nargs, nresults))
  
  -- return values
  local returnVars = {}

  for i, retNode in ipairs(funcRetNode) do
    local optional = retNode.tag == 'TUnion'
    local retName = 'ret' .. tostring(i)
    local luaIndex = - nresults + i - 1
    local swiftType = retNode.tag == 'TTable' and generateTableRetType(funcName, i) or getSwiftType(retNode)
    local varDeclaration = string.format('var %s: %s', retName, swiftType)

    if optional then
      table.insert(innerBuf, string.format('%s = nil', varDeclaration))
      table.insert(innerBuf, string.format('if lua_type(L, %d) != LUA_TNIL {', luaIndex))
      varDeclaration = string.format('%s', retName)
      retNode = retNode[1].tag == 'TNil' and retNode[2] or retNode[1]
    end

    if retNode.tag == 'TBase' then
      if retNode[1] == 'boolean' then
        table.insert(innerBuf, string.format('%s = lua_toboolean(L, %d) == 1 ? true : false', varDeclaration, luaIndex))
      elseif retNode[1] == 'number' then
        table.insert(innerBuf, string.format('%s = lua_tonumber(L, %d)', varDeclaration, luaIndex))
      elseif retNode[1] == 'string' then
        table.insert(innerBuf, string.format('var l%d: size_t = 0', i))
        table.insert(innerBuf, string.format('var s%d = lua_tolstring(L, %d, &l%d)', i, luaIndex, i))
        table.insert(innerBuf, string.format('%s = NSData(bytes: UnsafePointer<Void>(s%d), length: Int(l%d))', varDeclaration, i, i))
      else
        error('Unsupported node type: ' .. tostring(retNode[1]))
      end
      table.insert(returnVars, retName)
    elseif retNode.tag == 'TTable' then
      -- we need to make sure the table is at the top of the stack
      table.insert(innerBuf, string.format('lua_pushvalue(L, %d)', luaIndex))
      table.insert(innerBuf, string.format('%s = %s(engine: self.engine, useTopTable: true)', varDeclaration, swiftType))
      table.insert(returnVars, retName)
    elseif retNode.tag == 'TVararg' and retNode[1].tag == 'TNil' then
      -- Ignore
    else
      error('Unsupported node type: ' .. tostring(retNode.tag))
    end

    if optional then
      table.insert(innerBuf, '}')
    end
  end

  table.insert(innerBuf, 'self.engine.restoreStack()')
  local returnedVariablesList = ''
  if #returnVars > 0 then
    returnedVariablesList = '(' .. table.concat(returnVars, ', ') .. ')'
  end
  table.insert(innerBuf, 'return ' .. returnedVariablesList)
  table.insert(codeBuf, innerBuf)
  table.insert(codeBuf, '}')
end

local function generateSwiftSubscriptField(fieldKeyNode, fieldValueNode)
  local codeBuf = {}
  local headerFmt = 'subscript(index: %s) -> %s {'
  local indexSwiftType = getSwiftType(fieldKeyNode)
  local retSwiftType = getSwiftType(fieldValueNode)
  local header = string.format(headerFmt, indexSwiftType, retSwiftType)
  table.insert(codeBuf, header)
  
  -- getter
  table.insert(codeBuf, 'get {')
  table.insert(codeBuf, 'self.engine.saveStack()')
  table.insert(codeBuf, 'var L = self.engine.luaState')
  table.insert(codeBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')

  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, 'lua_pushnumber(L, index)')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, 'lua_pushlstring(L, UnsafePointer<Int8>(index.bytes), UInt(index.length))')
  else
    error('Unsupported key type: ' .. tostring(fieldKeyNode[1]))
  end

  table.insert(codeBuf, 'lua_gettable(L, -2)')

  local optional = fieldValueNode.tag == 'TUnion'
  if optional then
    table.insert(codeBuf, 'if lua_type(L, -1) == LUA_TNIL {')
    table.insert(codeBuf, '  return nil')
    table.insert(codeBuf, '}')
    fieldValueNode = fieldValueNode[1].tag == 'TNil' and fieldValueNode[2] or fieldValueNode[1]
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'var a: Bool = lua_toboolean(L, -1)')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return a')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'var a: Double = lua_tonumber(L, -1)')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return a')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'var l: size_t = 0')
    table.insert(codeBuf, 'var s = lua_tolstring(L, -1, &l)')
    table.insert(codeBuf, 'var data: NSData = NSData(bytes: UnsafePointer<Void>(s), length: Int(l))')
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return data')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, string.format('var t: %s = %s(engine: self.engine, useTopTable: true)', retSwiftType, retSwiftType))
    table.insert(codeBuf, 'self.engine.restoreStack()')
    table.insert(codeBuf, 'return t')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end
  table.insert(codeBuf, '}')

  -- setter
  table.insert(codeBuf, 'set {')
  table.insert(codeBuf, 'self.engine.saveStack()')
  table.insert(codeBuf, 'var L = self.engine.luaState')
  table.insert(codeBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')

  -- push the key
  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, 'lua_pushnumber(L, index)')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, 'lua_pushlstring(L, UnsafePointer<Int8>(index.bytes), UInt(index.length))')
  else
    error('Unsupported key type: ' .. tostring(fieldKeyNode[1]))
  end

  -- push the value (or nil)
  
  if optional then
    table.insert(codeBuf, 'if let v = newValue? {')
  else
    table.insert(codeBuf, 'let v = newValue')
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'lua_pushboolean(L, v)')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'lua_pushnumber(L, v)')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'lua_pushlstring(L, UnsafePointer<Int8>(v.bytes), UInt(v.length))')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, v.luaTableRef')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end

  if optional then
    table.insert(codeBuf, '} else {')
    table.insert(codeBuf, '  lua_pushnil(L)')
    table.insert(codeBuf, '}')
  end

  table.insert(codeBuf, 'lua_settable(L, -3)')

  table.insert(codeBuf, 'self.engine.restoreStack()')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, '}')
  return codeBuf
end

local function generateSwiftClassProperty(keyName, fieldValueNode, codeBuf, optional)
  optional = optional or false
  local fieldName = type(keyName) == 'string' and keyName or ('_' .. tostring(keyName))
  local notNullableSwiftType = 'T' .. fieldName
  table.insert(codeBuf, swiftProcessTable(notNullableSwiftType, fieldValueNode))
  local swiftType = notNullableSwiftType .. (optional and '?' or '')
  table.insert(codeBuf, string.format('var %s: %s {', fieldName, swiftType))

  -- getter
  do
    local innerBuf = {}
    table.insert(innerBuf, 'get {')
    table.insert(innerBuf, 'self.engine.saveStack()')
    table.insert(innerBuf, 'var L = self.engine.luaState')
    table.insert(innerBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')

    if type(keyName) == 'string' then
      table.insert(innerBuf, string.format('lua_pushstring(L, "%s")', keyName))
    elseif type(keyName) == 'number' then
      table.insert(innerBuf, string.format('lua_pushnumber(L, %d)', keyName))
    else
      error('Unsupported key type: ' .. type(keyName))
    end

    table.insert(innerBuf, 'lua_gettable(L, -2)')

    if optional then
      table.insert(innerBuf, 'if lua_type(L, -1) == LUA_TNIL {')
      table.insert(innerBuf, '  self.engine.restoreStack()')
      table.insert(innerBuf, '  return nil')
      table.insert(innerBuf, '}')
    end

    table.insert(innerBuf, string.format('var t = %s(engine: self.engine, useTopTable: true)', notNullableSwiftType))
    table.insert(innerBuf, 'self.engine.restoreStack()')
    table.insert(innerBuf, 'return t')
    table.insert(innerBuf, '}') -- get

    table.insert(codeBuf, innerBuf)
  end

  -- setter
  do
    local innerBuf = {}
    table.insert(innerBuf, 'set {')
    table.insert(innerBuf, 'self.engine.saveStack()')
    table.insert(innerBuf, 'var L = self.engine.luaState')
    table.insert(innerBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, self.luaTableRef)')
    if type(keyName) == 'string' then
      table.insert(innerBuf, string.format('lua_pushstring(L, "%s")', keyName))
    elseif type(keyName) == 'number' then
      table.insert(innerBuf, string.format('lua_pushnumber(L, %d)', keyName))
    else
      error('Unsupported key type: ' .. type(keyName))
    end

    if optional then
      table.insert(innerBuf, 'if newValue == nil { lua_pushnil(L) }')
      table.insert(innerBuf, 'else {')
      table.insert(innerBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, newValue!.luaTableRef)')
      table.insert(innerBuf, '}')
    else
      table.insert(innerBuf, 'lua_rawgeti(L, LUA_GLOBALSINDEX, newValue.luaTableRef)')
    end
    table.insert(innerBuf, 'lua_settable(L, -3)')
    table.insert(innerBuf, 'self.engine.restoreStack()')
    table.insert(innerBuf, '}') -- set

    table.insert(codeBuf, innerBuf)
  end

  table.insert(codeBuf, '}')
end

local function generateSwiftUnionType(fieldName, fieldValueNode, codeBuf)
  if not(fieldValueNode[1].tag == 'TNil' or fieldValueNode[2].tag == 'TNil') then
    error(string.format('Only nullable union types are supported (%s).', fieldName))
  end

  fieldValueNode = fieldValueNode[1].tag == 'TNil' and fieldValueNode[2] or fieldValueNode[1]
  if fieldValueNode.tag == 'TBase' then
    generateSwiftBaseProperty(fieldName, fieldValueNode, codeBuf, true)
  elseif fieldValueNode.tag == 'TTable' then
    generateSwiftClassProperty(fieldName, fieldValueNode, codeBuf, true)
  else
    error(string.format('Unsupported field type for field %s: %s', tostring(fieldName), fieldValueNode.tag))
  end
end

local function swiftProcessTableField(fieldNameNode, fieldValueNode)
  local fieldName = fieldNameNode[1]
  local tag = fieldValueNode.tag
  local codeBuf = {}

  if tag == 'TBase' then
    generateSwiftBaseProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TFunction' then
    generateSwiftFunction(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TTable' then
    generateSwiftClassProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TUnion' then
    generateSwiftUnionType(fieldName, fieldValueNode, codeBuf)
  end
  return codeBuf
end

local function swiftProcessField(moduleField)
  local fieldKeyNode = moduleField[1]
  local fieldValueNode = moduleField[2]

  if fieldKeyNode.tag == 'TLiteral' then
    return swiftProcessTableField(fieldKeyNode, fieldValueNode)
  elseif fieldKeyNode.tag == 'TBase' then
    return generateSwiftSubscriptField(fieldKeyNode, fieldValueNode)
  else
    error('Invalid field name node: ' .. fieldNameNode.tag)
  end
end

local function swiftInitializerForLuaModule(tableSpec, luaModuleName)
  local codeBuf = {}

  table.insert(codeBuf, 'var engine: SplotEngine')
  table.insert(codeBuf, 'var luaModuleName: String')
  table.insert(codeBuf, string.format('var luaTableRef: %s', LuaTableRefVarType))
  table.insert(codeBuf, 'init() {')
  
  do
    local innerCodeBuf = {}
    table.insert(innerCodeBuf, string.format('self.engine = SplotEngine(moduleName: "%s")', luaModuleName))
    table.insert(innerCodeBuf, 'self.luaTableRef = luaL_ref(self.engine.luaState, LUA_GLOBALSINDEX)')
    table.insert(innerCodeBuf, string.format('self.luaModuleName = "%s"', luaModuleName))
    table.insert(codeBuf, innerCodeBuf)
  end

  table.insert(codeBuf, '}')
  return codeBuf
end

local function swiftSimpleInitializer(tableSpec)
  local codeBuf = {}
  table.insert(codeBuf, 'var engine: SplotEngine')
  table.insert(codeBuf, string.format('var luaTableRef: %s', LuaTableRefVarType))
  table.insert(codeBuf, 'init(engine: SplotEngine, useTopTable: Bool = false) {')
  table.insert(codeBuf, 'self.engine = engine')
  table.insert(codeBuf, 'if (!useTopTable) { lua_createtable(self.engine.luaState, 0, 0) }')
  table.insert(codeBuf, 'self.luaTableRef = luaL_ref(self.engine.luaState, LUA_GLOBALSINDEX)')
  table.insert(codeBuf, '}')
  return codeBuf
end

local function swiftDeinitializer()
  local codeBuf = {}
  table.insert(codeBuf, 'deinit {')
  table.insert(codeBuf, '  luaL_unref(self.engine.luaState, LUA_GLOBALSINDEX, self.luaTableRef)')
  table.insert(codeBuf, '}')
  return codeBuf
end

swiftProcessTable = function(moduleName, tableSpec, luaModuleName)
  local codeBuf = {}
  table.insert(codeBuf, string.format('class %s {', moduleName))

  if luaModuleName then
    table.insert(codeBuf, swiftInitializerForLuaModule(tableSpec, luaModuleName))
  else
    table.insert(codeBuf, swiftSimpleInitializer(tableSpec))
  end

  table.insert(codeBuf, swiftDeinitializer())
  
  for _, moduleField in ipairs(tableSpec) do
    if moduleField.tag ~= 'TField' then
      print('Skipping ' .. tostring(moduleField.tag) .. ' field)')
    else
      local codeTable = swiftProcessField(moduleField)
      table.insert(codeBuf, codeTable)
    end
  end

  table.insert(codeBuf, '}')
  return codeBuf
end

return {
  processTable = swiftProcessTable,
}

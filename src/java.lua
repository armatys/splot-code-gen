local string = require 'string'
local table = require 'table'

local JavaFuncParamPrefix = 'param'

local javaProcessTable

local function getJavaBaseType(typedLuaT)
  if typedLuaT == 'boolean' then
    return 'Boolean'
  elseif typedLuaT == 'number' then
    return 'Double'
  elseif typedLuaT == 'string' then
    return 'byte[]'
  else
    error('Unsupported type ' .. tostring(typedLuaT))
  end
end

local function getJavaType(nodeType, fieldName)
  if nodeType.tag == 'TBase' then
    return getJavaBaseType(nodeType[1])
  elseif nodeType.tag == 'TNil' then
    return 'void'
  elseif nodeType.tag == 'TUnion' then
    if nodeType[1].tag == 'TNil' then
      return '@Nullable ' .. getJavaType(nodeType[2], fieldName)
    elseif nodeType[2].tag == 'TNil' then
      return '@Nullable ' .. getJavaType(nodeType[1], fieldName)
    else
      error('Union types not yet supported.')
    end
  elseif nodeType.tag == 'TValue' then
    return 'Object'
  elseif nodeType.tag == 'TVararg' then
    return getJavaType(nodeType[1], fieldName) .. '...'
  elseif nodeType.tag == 'TTable' then
    if not fieldName then
      error('Missing field name parameter.', 2)
    end
    return 'T' .. fieldName
  else
    error('Unsupported node type: ' .. tostring(nodeType.tag))
  end
end

local function makeAccessorName(propertyName)
  return propertyName:upper():sub(1, 1) .. propertyName:sub(2)
end

local function generateJavaBaseProperty(fieldKeyName, fieldValueNode, codeBuf, optional)
  optional = optional or false
  local javaType = (optional and '@Nullable ' or '') .. getJavaType(fieldValueNode)
  local fieldName = type(fieldKeyName) == 'string' and fieldKeyName or ('_' .. tostring(fieldKeyName))
  
  -- getter
  table.insert(codeBuf, string.format('public %s get%s() {', javaType, makeAccessorName(fieldName)))
  table.insert(codeBuf, 'mEngine.saveStack();')
  table.insert(codeBuf, 'final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  
  if type(fieldKeyName) == 'string' then
    table.insert(codeBuf, string.format('L.getField(-1, "%s");', fieldName))
  elseif type(fieldKeyName) == 'number' then
    table.insert(codeBuf, string.format('L.pushNumber(%d);', fieldKeyName))
    table.insert(codeBuf, string.format('L.getTable(-2);', fieldKeyName))
  else
    error('Unsupported key type: ' .. type(fieldKeyName))
  end
  
  if optional then
    table.insert(codeBuf, 'if (L.type(-1) == LuaState.LUA_TNIL) {')
    table.insert(codeBuf, '  mEngine.restoreStack();')
    table.insert(codeBuf, '  return null;')
    table.insert(codeBuf, '}')
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'final Boolean a = L.toBoolean(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return a;')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'final Double a = L.toNumber(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return a;')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'final byte[] data = L.toByteArray(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return data;')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end
  table.insert(codeBuf, '}')

  -- setter

  table.insert(codeBuf, string.format('public void set%s(%s newValue) {', makeAccessorName(fieldName), javaType))
  table.insert(codeBuf, 'mEngine.saveStack();')
  table.insert(codeBuf, 'final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')

  -- push key

  if type(fieldKeyName) == 'string' then
    table.insert(codeBuf, string.format('L.pushString("%s");', fieldKeyName))
  elseif type(fieldKeyName) == 'number' then
    table.insert(codeBuf, string.format('L.pushNumber(%d);', fieldKeyName))
  else
    error('Unsupported key type: ' .. type(fieldKeyName))
  end

  -- push value
  
  if optional then
    table.insert(codeBuf, 'if (newValue != null) {')

  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'L.pushBoolean(newValue);')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'L.pushNumber(newValue);')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'L.pushString(newValue);')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end

  if optional then
    table.insert(codeBuf, '} else {')
    table.insert(codeBuf, '  L.pushNil();')
    table.insert(codeBuf, '}')
  end

  table.insert(codeBuf, 'L.setTable(-3);')
  table.insert(codeBuf, 'mEngine.restoreStack();')
  table.insert(codeBuf, '}')
end

local function generateTableParamType(funcName, i)
  return 'PT' .. funcName .. tostring(i)
end

local function generateJavaFuncParams(funcName, funcParamsNode)
  if funcParamsNode.tag ~= 'TTuple' then
    error('Unsupported node: ' .. tostring(funcParamsNode.tag))
  end

  local classesCode
  local codeBuf = {}
  local nargs = 0

  -- Iterate over parameter list
  for i, v in ipairs(funcParamsNode) do
    local javaType
    if v.tag == 'TTable' then
      classesCode = classesCode or {}
      javaType = generateTableParamType(funcName, i)
      table.insert(classesCode, javaProcessTable(javaType, v))
    end

    javaType = javaType or getJavaType(v)

    -- Skip the last argument, if it's a dummy placeholder
    if v.tag ~= 'TVararg' and v[1].tag ~= 'TValue' or i < #funcParamsNode then
      local param = {}
      table.insert(param, javaType)
      table.insert(param, ' ' .. JavaFuncParamPrefix .. tostring(i))
      table.insert(codeBuf, table.concat(param))
      nargs = nargs + 1
    end
  end

  return '(' .. table.concat(codeBuf, ', ') .. ')', classesCode, nargs
end

local function generateTableRetType(funcName, i)
  return 'RT' .. funcName .. tostring(i)
end

local function generateJavaFuncRet(funcName, funcRetNode)
  if funcRetNode.tag ~= 'TTuple' then
    error('Unsupported node: ' .. tostring(funcRetNode.tag))
  end

  local classesCode
  local codeBuf = {}
  local nresults = 0

  -- Iterate over parameter list
  for i, v in ipairs(funcRetNode) do
    local javaType
    if v.tag == 'TTable' then
      classesCode = classesCode or {}
      javaType = generateTableRetType(funcName, i)
      table.insert(classesCode, javaProcessTable(javaType, v))
    end

    javaType = javaType or getJavaType(v)

    -- Skip the last argument, if it's a dummy placeholder
    if v.tag ~= 'TVararg' and v[1].tag ~= 'TNil' or i < #funcRetNode then
      table.insert(codeBuf, javaType)
      nresults = nresults + 1
    end
  end

  local returnSignature
  if nresults == 0 then
    returnSignature = 'void'
  elseif nresults == 1 then
    returnSignature = table.concat(codeBuf)
  elseif nresults == 2 then
    returnSignature = string.format('Pair<%s>', table.concat(codeBuf, ', '))
  else
    error(string.format('Function %s has %d return values, but only up to 2 is supported.', funcName, nresults))
  end

  return returnSignature, classesCode, nresults
end

local function generateJavaFunction(funcName, fieldValueNode, codeBuf)
  local funcHeaderFmt = 'public %s %s%s {'
  local funcParamsNode = fieldValueNode[1]
  local funcRetNode = fieldValueNode[2]

  local funcParamsTuple, funcParamsClasses, nargs = generateJavaFuncParams(funcName, funcParamsNode)
  local funcRetTuple, funcRetClasses, nresults = generateJavaFuncRet(funcName, funcRetNode)
  local funcHeader = string.format(funcHeaderFmt, funcRetTuple, funcName, funcParamsTuple)

  if funcParamsClasses then
    table.insert(codeBuf, funcParamsClasses)
  end
  if funcRetClasses then
    table.insert(codeBuf, funcRetClasses)
  end
  table.insert(codeBuf, funcHeader)
  
  local innerBuf = {}
  table.insert(innerBuf, 'mEngine.saveStack();')
  table.insert(innerBuf, 'final LuaState L = mEngine.getLuaState();')

  -- push the function
  table.insert(innerBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(innerBuf, string.format('L.getField(-1, "%s");', funcName))

  -- arguments
  for i, paramNode in ipairs(funcParamsNode) do
    local optional = paramNode.tag == 'TUnion'
    local paramName = JavaFuncParamPrefix .. tostring(i)

    if optional then
      table.insert(innerBuf, string.format('if (%s == null) {', paramName))
      table.insert(innerBuf, '  L.pushNil();')
      table.insert(innerBuf, '} else {')
      paramNode = paramNode[1].tag == 'TNil' and paramNode[2] or paramNode[1]
    end

    if paramNode.tag == 'TBase' then
      if paramNode[1] == 'boolean' then
        table.insert(innerBuf, string.format('L.pushBoolean(%s);', paramName))
      elseif paramNode[1] == 'number' then
        table.insert(innerBuf, string.format('L.pushNumber(%s);', paramName))
      elseif paramNode[1] == 'string' then
        table.insert(innerBuf, string.format('L.pushString(%s);', paramName))
      else
        error('Unsupported node type: ' .. tostring(paramNode[1]))
      end
    elseif paramNode.tag == 'TTable' then
      table.insert(innerBuf, string.format('L.rawGetI(LuaState.LUA_GLOBALSINDEX, %s.getLuaTableRef());', paramName))
    elseif paramNode.tag == 'TVararg' and paramNode[1].tag == 'TValue' then
      -- Ignore
    else
      error('Unsupported node type: ' .. tostring(paramNode.tag))
    end

    if optional then
      table.insert(innerBuf, '}')
    end
  end

  table.insert(innerBuf, string.format('L.call(%d, %d);', nargs, nresults))
  
  -- return values
  local returnVars = {}

  for i, retNode in ipairs(funcRetNode) do
    local optional = retNode.tag == 'TUnion'
    local retName = 'ret' .. tostring(i)
    local luaIndex = - nresults + i - 1

    if optional then
      retNode = retNode[1].tag == 'TNil' and retNode[2] or retNode[1]
    end

    local javaType = retNode.tag == 'TTable' and generateTableRetType(funcName, i) or getJavaType(retNode)
    local varDeclaration = string.format('%s %s', javaType, retName)

    if optional then
      table.insert(innerBuf, string.format('%s = null;', varDeclaration))
      table.insert(innerBuf, string.format('if (L.type(%d) != LuaState.LUA_TNIL) {', luaIndex))
      varDeclaration = string.format('%s', retName)
    end

    if retNode.tag == 'TBase' then
      if retNode[1] == 'boolean' then
        table.insert(innerBuf, string.format('%s = L.toBoolean(%d);', varDeclaration, luaIndex))
      elseif retNode[1] == 'number' then
        table.insert(innerBuf, string.format('%s = L.toNumber(%d);', varDeclaration, luaIndex))
      elseif retNode[1] == 'string' then
        table.insert(innerBuf, string.format('%s = L.toByteArray(%d);', varDeclaration, luaIndex))
      else
        error('Unsupported node type: ' .. tostring(retNode[1]))
      end
      table.insert(returnVars, retName)
    elseif retNode.tag == 'TTable' then
      -- we need to make sure the table is at the top of the stack
      table.insert(innerBuf, string.format('L.pushValue(%d);', luaIndex))
      table.insert(innerBuf, string.format('%s = new %s(mEngine, true);', varDeclaration, javaType))
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

  table.insert(innerBuf, 'mEngine.restoreStack();')
  local returnedVariablesList = ''
  if #returnVars == 0 then
    returnedVariablesList = ''
  elseif #returnVars == 1 then
    returnedVariablesList = table.concat(returnVars)
  elseif #returnVars == 2 then
    returnedVariablesList = string.format('new Pair(%s)', table.concat(returnVars, ', '))
  else
    error(string.format('Function %s has %d return values, but only up to 2 is supported.', funcName, #returnVars))
  end
  table.insert(innerBuf, 'return ' .. returnedVariablesList .. ';')
  table.insert(codeBuf, innerBuf)
  table.insert(codeBuf, '}')
end

local function generateJavaMapFields(fieldKeyNode, fieldValueNode)
  local codeBuf = {}
  local indexJavaType = getJavaType(fieldKeyNode)
  local retJavaType = getJavaType(fieldValueNode)
  local notNullableRetJavaType = retJavaType
  if fieldValueNode.tag == 'TUnion' then
    notNullableRetJavaType = fieldValueNode[1].tag == 'TNil' and getJavaType(fieldValueNode[2]) or getJavaType(fieldValueNode[1])
  end
  
  --------------------
  -- getter

  table.insert(codeBuf, string.format('@Override public %s get(Object indexObj) {', retJavaType))
  table.insert(codeBuf, string.format('if (!(indexObj instanceof %s)) {', indexJavaType))
  table.insert(codeBuf, '  return null;')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, string.format('final %s index = (%s)indexObj;', indexJavaType, indexJavaType))
  table.insert(codeBuf, 'mEngine.saveStack();')
  table.insert(codeBuf, 'final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')

  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, 'L.pushNumber(index);')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, 'L.pushString(index);')
  else
    error('Unsupported key type: ' .. tostring(fieldKeyNode[1]))
  end

  table.insert(codeBuf, 'L.getTable(-2);')

  local optional = fieldValueNode.tag == 'TUnion'
  if optional then
    table.insert(codeBuf, 'if (L.type(-1) == LuaState.LUA_TNIL) {')
    table.insert(codeBuf, '  return null;')
    table.insert(codeBuf, '}')
    fieldValueNode = fieldValueNode[1].tag == 'TNil' and fieldValueNode[2] or fieldValueNode[1]
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'Boolean a = L.toBoolean(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return a;')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'Double a = L.toNumber(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return a;')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'byte[] data = L.toByteArray(-1);')
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return data;')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, string.format('%s t = new %s(true);', notNullableRetJavaType, notNullableRetJavaType))
    table.insert(codeBuf, 'mEngine.restoreStack();')
    table.insert(codeBuf, 'return t;')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end
  table.insert(codeBuf, '}')

  --------------------
  -- setter

  table.insert(codeBuf, string.format('@Override public %s put(%s index, %s newValue) {', retJavaType, indexJavaType, retJavaType))
  table.insert(codeBuf, string.format('final %s oldMapping = get(index);', notNullableRetJavaType))
  table.insert(codeBuf, 'mEngine.saveStack();')
  table.insert(codeBuf, 'final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')

  -- push the key
  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, 'L.pushNumber(index);')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, 'L.pushString(index)')
  else
    error('Unsupported key type: ' .. tostring(fieldKeyNode[1]))
  end

  -- push the value (or nil)
  
  if optional then
    table.insert(codeBuf, 'if (newValue != null) {')
  end

  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, 'L.pushBoolean(newValue);')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, 'L.pushNumber(newValue);')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, 'L.pushString(newValue);')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, newValue.getLuaTableRef());')
  else
    error('Unsupported base value: ' .. tostring(fieldValueNode[1]))
  end

  if optional then
    table.insert(codeBuf, '} else {')
    table.insert(codeBuf, '  L.pushNil();')
    table.insert(codeBuf, '}')
  end

  table.insert(codeBuf, 'L.setTable(-3);')

  table.insert(codeBuf, 'mEngine.restoreStack();')
  table.insert(codeBuf, 'return oldMapping;')
  table.insert(codeBuf, '}')

  --------------------
  -- clear

  table.insert(codeBuf, '@Override public void clear() {')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  L.createTable(0, 0);')
  table.insert(codeBuf, '  L.rawSetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '}')

  --------------------
  -- containsKey

  table.insert(codeBuf, '@Override public boolean containsKey(Object key) {')
  table.insert(codeBuf, '  return get(key) != null;')
  table.insert(codeBuf, '}')

  --------------------
  -- containsValue

  table.insert(codeBuf, '@Override public boolean containsValue(Object value) {')
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  while (L.next(-2) != 0) {')
  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, '    if (value.equals(L.toBoolean(-1))) { return true; }')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, '    if (value.equals(L.toNumber(-1))) { return true; }')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, '    if (Arrays.equals((byte[])value, L.toByteArray(-1))) { return true; }')
  elseif fieldValueNode.tag == 'TTable' then
    -- TODO check if value is a lua table (i.e. has a mLuaTableRef property)
    -- then compare using Lua's "eq" (==) operation
    -- alternatively, allow the generated classes to have "equals" and "hashCode" methods implemented
    -- (which is probably more difficult)
    table.insert(codeBuf, '    throw new RuntimeException("Not yet implemented.");')
  end
  table.insert(codeBuf, '    L.pop(1);') -- pop the value, keep the kep
  table.insert(codeBuf, '  }') -- while
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return false;')
  table.insert(codeBuf, '}')

  --------------------
  -- entrySet

  table.insert(codeBuf, string.format('@Override public @NonNull Set<Entry<%s, %s>> entrySet() {', indexJavaType, notNullableRetJavaType))
  table.insert(codeBuf, string.format('  final HashSet<Entry<%s, %s>> hashSet = new HashSet<Entry<%s, %s>>();', indexJavaType, notNullableRetJavaType, indexJavaType, notNullableRetJavaType))
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  while (L.next(-2) != 0) {')
  
  -- get the key
  table.insert(codeBuf, string.format('    %s key;', indexJavaType))
  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, '    key = L.toNumber(-2);')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, '    key = L.toByteArray(-2);')
  end

  -- get the value
  table.insert(codeBuf, string.format('    %s value;', notNullableRetJavaType))
  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, '    value = L.toBoolean(-1);')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, '    value = L.toNumber(-1);')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, '    value = L.toByteArray(-1);')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, string.format('    value = new %s(true);', notNullableRetJavaType))
  end
  table.insert(codeBuf, string.format('  hashSet.add(new AbstractMap.SimpleEntry<%s, %s>(key, value));', indexJavaType, notNullableRetJavaType))
  table.insert(codeBuf, '  L.pop(1);')

  table.insert(codeBuf, '  }')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return hashSet;')
  table.insert(codeBuf, '}')

  --------------------
  -- isEmpty

  table.insert(codeBuf, '@Override public boolean isEmpty() {')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  final boolean empty = L.next(-2) == 0;')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return empty;')
  table.insert(codeBuf, '}')

  --------------------
  -- keySet

  table.insert(codeBuf, string.format('@Override public @NonNull Set<%s> keySet() {', indexJavaType))
  table.insert(codeBuf, string.format('  final HashSet<%s> hashSet = new HashSet<%s>();', indexJavaType, indexJavaType))
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  while (L.next(-2) != 0) {')
  
  -- get the key
  table.insert(codeBuf, string.format('    %s key;', indexJavaType))
  if fieldKeyNode[1] == 'number' then
    table.insert(codeBuf, '    key = L.toNumber(-2);')
  elseif fieldKeyNode[1] == 'string' then
    table.insert(codeBuf, '    key = L.toByteArray(-2);')
  end

  table.insert(codeBuf, '  hashSet.add(key);')
  table.insert(codeBuf, '  L.pop(1);')

  table.insert(codeBuf, '  }')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return hashSet;')
  table.insert(codeBuf, '}')

  --------------------
  -- putAll

  table.insert(codeBuf, string.format('@Override public void putAll(@NonNull Map<? extends %s, ? extends %s> map) {', indexJavaType, notNullableRetJavaType))
  table.insert(codeBuf, string.format('  for (%s key : map.keySet()) {', indexJavaType))
  table.insert(codeBuf, '    put(key, map.get(key));')
  table.insert(codeBuf, '  }')
  table.insert(codeBuf, '}')

  --------------------
  -- remove

  table.insert(codeBuf, string.format('@Override public %s remove(Object key) {', retJavaType))
  table.insert(codeBuf, string.format('if (!(key instanceof %s)) {', indexJavaType))
  table.insert(codeBuf, '  return null;')
  table.insert(codeBuf, '}')
  table.insert(codeBuf, string.format('final %s index = (%s)key;', indexJavaType, indexJavaType))
  table.insert(codeBuf, 'return put(index, null);')
  table.insert(codeBuf, '}')

  --------------------
  -- size

  table.insert(codeBuf, '@Override public int size() {')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  int n = 0;')
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  while (L.next(-2) != 0) {')
  table.insert(codeBuf, '    n += 1;')
  table.insert(codeBuf, '    L.pop(1);')
  table.insert(codeBuf, '  }')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return n;')
  table.insert(codeBuf, '}')

  --------------------
  -- values

  table.insert(codeBuf, string.format('@Override public @NonNull Collection<%s> values() {', notNullableRetJavaType))
  table.insert(codeBuf, string.format('  final ArrayList<%s> valuesArray = new ArrayList<%s>();', notNullableRetJavaType, notNullableRetJavaType))
  table.insert(codeBuf, '  mEngine.saveStack();')
  table.insert(codeBuf, '  final LuaState L = mEngine.getLuaState();')
  table.insert(codeBuf, '  L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '  L.pushNil();')
  table.insert(codeBuf, '  while (L.next(-2) != 0) {')

  -- get the value
  table.insert(codeBuf, string.format('    %s value;', notNullableRetJavaType))
  if fieldValueNode[1] == 'boolean' then
    table.insert(codeBuf, '    value = L.toBoolean(-1);')
  elseif fieldValueNode[1] == 'number' then
    table.insert(codeBuf, '    value = L.toNumber(-1);')
  elseif fieldValueNode[1] == 'string' then
    table.insert(codeBuf, '    value = L.toByteArray(-1);')
  elseif fieldValueNode.tag == 'TTable' then
    table.insert(codeBuf, string.format('    value = new %s(true);', notNullableRetJavaType))
  end
  table.insert(codeBuf, '  valuesArray.add(value);')
  table.insert(codeBuf, '  L.pop(1);')

  table.insert(codeBuf, '  }')
  table.insert(codeBuf, '  mEngine.restoreStack();')
  table.insert(codeBuf, '  return valuesArray;')
  table.insert(codeBuf, '}')

  return codeBuf
end

local function generateJavaClassProperty(keyName, fieldValueNode, codeBuf, optional)
  optional = optional or false
  local fieldName = type(keyName) == 'string' and keyName or ('_' .. tostring(keyName))
  local notNullableJavaType = 'T' .. fieldName
  table.insert(codeBuf, javaProcessTable(notNullableJavaType, fieldValueNode))
  local javaType = (optional and '@Nullable ' or '') .. notNullableJavaType

  -- getter
  do
    local innerBuf = {}
    table.insert(innerBuf, string.format('public %s get%s() {', javaType, makeAccessorName(fieldName)))
    table.insert(innerBuf, 'mEngine.saveStack();')
    table.insert(innerBuf, 'final LuaState L = mEngine.getLuaState();')
    table.insert(innerBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')

    if type(keyName) == 'string' then
      table.insert(innerBuf, string.format('L.pushString("%s");', keyName))
    elseif type(keyName) == 'number' then
      table.insert(innerBuf, string.format('L.pushNumber(%d);', keyName))
    else
      error('Unsupported key type: ' .. type(keyName))
    end

    table.insert(innerBuf, 'L.getTable(-2);')

    if optional then
      table.insert(innerBuf, 'if (L.type(-1) == LuaState.LUA_TNIL) {')
      table.insert(innerBuf, '  mEngine.restoreStack();')
      table.insert(innerBuf, '  return null;')
      table.insert(innerBuf, '}')
    end

    table.insert(innerBuf, string.format('%s t = new %s(mEngine, true);', notNullableJavaType, notNullableJavaType))
    table.insert(innerBuf, 'mEngine.restoreStack();')
    table.insert(innerBuf, 'return t;')
    table.insert(innerBuf, '}') -- get

    table.insert(codeBuf, innerBuf)
  end

  -- setter
  do
    local innerBuf = {}
    table.insert(innerBuf, string.format('public void set%s(%s newValue) {', makeAccessorName(fieldName), javaType))
    table.insert(innerBuf, 'mEngine.saveStack();')
    table.insert(innerBuf, 'final LuaState L = mEngine.getLuaState();')
    table.insert(innerBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
    if type(keyName) == 'string' then
      table.insert(innerBuf, string.format('L.pushString("%s");', keyName))
    elseif type(keyName) == 'number' then
      table.insert(innerBuf, string.format('L.pushNumber(%d);', keyName))
    else
      error('Unsupported key type: ' .. type(keyName))
    end

    if optional then
      table.insert(innerBuf, 'if (newValue == null) { L.pushNil(); }')
      table.insert(innerBuf, 'else {')
      table.insert(innerBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, newValue.getLuaTableRef());')
      table.insert(innerBuf, '}')
    else
      table.insert(innerBuf, 'L.rawGetI(LuaState.LUA_GLOBALSINDEX, newValue.getLuaTableRef());')
    end
    table.insert(innerBuf, 'L.setTable(-3);')
    table.insert(innerBuf, 'mEngine.restoreStack();')
    table.insert(innerBuf, '}') -- set

    table.insert(codeBuf, innerBuf)
  end
end

local function generateJavaUnionType(fieldName, fieldValueNode, codeBuf)
  if not(fieldValueNode[1].tag == 'TNil' or fieldValueNode[2].tag == 'TNil') then
    error(string.format('Only nullable union types are supported (%s).', fieldName))
  end

  fieldValueNode = fieldValueNode[1].tag == 'TNil' and fieldValueNode[2] or fieldValueNode[1]
  if fieldValueNode.tag == 'TBase' then
    generateJavaBaseProperty(fieldName, fieldValueNode, codeBuf, true)
  elseif fieldValueNode.tag == 'TTable' then
    generateJavaClassProperty(fieldName, fieldValueNode, codeBuf, true)
  else
    error(string.format('Unsupported field type for field %s: %s', tostring(fieldName), fieldValueNode.tag))
  end
end

local function javaProcessTableField(fieldNameNode, fieldValueNode)
  local fieldName = fieldNameNode[1]
  local tag = fieldValueNode.tag
  local codeBuf = {}

  if tag == 'TBase' then
    generateJavaBaseProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TFunction' then
    generateJavaFunction(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TTable' then
    generateJavaClassProperty(fieldName, fieldValueNode, codeBuf)
  elseif tag == 'TUnion' then
    generateJavaUnionType(fieldName, fieldValueNode, codeBuf)
  end
  return codeBuf
end

local function javaProcessField(moduleField)
  local fieldKeyNode = moduleField[1]
  local fieldValueNode = moduleField[2]

  if fieldKeyNode.tag == 'TLiteral' then
    return javaProcessTableField(fieldKeyNode, fieldValueNode)
  elseif fieldKeyNode.tag == 'TBase' then
    return generateJavaMapFields(fieldKeyNode, fieldValueNode)
  else
    error('Invalid field name node: ' .. fieldNameNode.tag)
  end
end

local function javaInitializerForLuaModule(moduleName, tableSpec, luaModuleName)
  local codeBuf = {}

  table.insert(codeBuf, 'private SplotEngine mEngine;')
  table.insert(codeBuf, 'private String mLuaModuleName;')
  table.insert(codeBuf, 'private int mLuaTableRef;')
  table.insert(codeBuf, string.format('public %s(Context context) {', moduleName))
  do
    local innerCodeBuf = {}
    table.insert(innerCodeBuf, 'mEngine = new SplotEngine(context);')
    table.insert(innerCodeBuf, 'try {')
    table.insert(innerCodeBuf, string.format('  mEngine.loadLuaModule("%s");', luaModuleName))
    table.insert(innerCodeBuf, '} catch (IOException e) {')
    table.insert(innerCodeBuf, '  throw new RuntimeException(e);')
    table.insert(innerCodeBuf, '}')
    table.insert(innerCodeBuf, 'mLuaTableRef = mEngine.getLuaState().Lref(LuaState.LUA_GLOBALSINDEX);')
    table.insert(innerCodeBuf, string.format('mLuaModuleName = "%s";', luaModuleName))
    table.insert(codeBuf, innerCodeBuf)
  end
  table.insert(codeBuf, '}')

  table.insert(codeBuf, 'public SplotEngine getEngine() {')
  table.insert(codeBuf, ' return mEngine;')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, 'public int getLuaTableRef() {')
  table.insert(codeBuf, ' return mLuaTableRef;')
  table.insert(codeBuf, '}')
  return codeBuf
end

local function javaSimpleInitializer(moduleName, tableSpec)
  local codeBuf = {}
  table.insert(codeBuf, 'private int mLuaTableRef;')
  table.insert(codeBuf, 'private SplotEngine mEngine;')
  table.insert(codeBuf, string.format('public %s(SplotEngine engine, boolean useTopTable) {', moduleName))
  table.insert(codeBuf, 'mEngine = engine;')
  table.insert(codeBuf, 'if (!useTopTable) { mEngine.getLuaState().createTable(0, 0); }')
  table.insert(codeBuf, 'mLuaTableRef = mEngine.getLuaState().Lref(LuaState.LUA_GLOBALSINDEX);')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, 'public SplotEngine getEngine() {')
  table.insert(codeBuf, ' return mEngine;')
  table.insert(codeBuf, '}')

  table.insert(codeBuf, 'public int getLuaTableRef() {')
  table.insert(codeBuf, ' return mLuaTableRef;')
  table.insert(codeBuf, '}')
  return codeBuf
end

local function javaDeinitializer()
  local codeBuf = {}
  table.insert(codeBuf, 'protected void finalize() throws Throwable {')
  table.insert(codeBuf, '  super.finalize();')
  table.insert(codeBuf, '  mEngine.getLuaState().LunRef(LuaState.LUA_GLOBALSINDEX, mLuaTableRef);')
  table.insert(codeBuf, '}')
  return codeBuf
end

javaProcessTable = function(moduleName, tableSpec, luaModuleName)
  local codeBuf = {}
  local staticDecl = ''

  if luaModuleName then
    table.insert(codeBuf, 'package splot;')
    -- Import any needed classes
    table.insert(codeBuf, 'import android.content.Context;')
    table.insert(codeBuf, 'import android.support.annotation.NonNull;')
    table.insert(codeBuf, 'import android.support.annotation.Nullable;')
    table.insert(codeBuf, 'import android.util.Pair;')
    table.insert(codeBuf, 'import org.keplerproject.luajava.LuaState;')
    table.insert(codeBuf, 'import java.io.IOException;')
    table.insert(codeBuf, 'import java.util.AbstractMap;')
    table.insert(codeBuf, 'import java.util.ArrayList;')
    table.insert(codeBuf, 'import java.util.Arrays;')
    table.insert(codeBuf, 'import java.util.Collection;')
    table.insert(codeBuf, 'import java.util.HashSet;')
    table.insert(codeBuf, 'import java.util.Map;')
    table.insert(codeBuf, 'import java.util.Set;')
    table.insert(codeBuf, 'import pl.makenika.splot.LuaTable;')
    table.insert(codeBuf, 'import pl.makenika.splot.SplotEngine;')
  else
    staticDecl = 'static'
  end

  local fieldKeyNode = tableSpec[1][1]
  local fieldValueNode = tableSpec[1][2]

  if fieldKeyNode.tag == 'TBase' then
    if fieldValueNode.tag == 'TUnion' then
      fieldValueNode = fieldValueNode[1].tag == 'TNil' and fieldValueNode[2] or fieldValueNode[1]
    end
    table.insert(codeBuf, string.format('public %s class %s implements LuaTable, Map<%s, %s> {', staticDecl, moduleName, getJavaType(fieldKeyNode), getJavaType(fieldValueNode)))
  else
    table.insert(codeBuf, string.format('public %s class %s implements LuaTable {', staticDecl, moduleName))
  end

  if luaModuleName then
    table.insert(codeBuf, javaInitializerForLuaModule(moduleName, tableSpec, luaModuleName))
  else
    table.insert(codeBuf, javaSimpleInitializer(moduleName, tableSpec))
  end

  table.insert(codeBuf, javaDeinitializer())
  
  for _, moduleField in ipairs(tableSpec) do
    if moduleField.tag ~= 'TField' then
      print('Skipping ' .. tostring(moduleField.tag) .. ' field)')
    else
      local codeTable = javaProcessField(moduleField)
      table.insert(codeBuf, codeTable)
    end
  end

  table.insert(codeBuf, '}')
  return codeBuf
end

return {
  processTable = javaProcessTable,
}

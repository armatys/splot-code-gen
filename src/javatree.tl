local Node = require 'codetree'.Node
local string = require 'string'

local NullableFQCN = 'javax.annotation.Nullable'

local interface JavaClassDescriptor
  visibility: string?
  static: boolean?
  implements: {string}?
  extends: string?
end

local interface JavaFieldSpec
  fieldName: string
  fieldType: string
  fieldInit: string?
  optional: boolean?
  visibility: string?
  static: boolean?
  getter: string|boolean?
  setter: string|boolean?
  getterVisibility: string?
  setterVisibility: string?
end

local interface JavaMethodParam
  name: string
  paramType: string
  optional: boolean?
  defaultValue: string?
end

local interface JavaMethodReturn
  returnType: string
  optional: boolean?
end

local interface JavaMethodSpec
  methodName: string
  returnSpec: JavaMethodReturn
  params: {JavaMethodParam}
  visibility: string?
  static: boolean?
  code: string?
end

local interface JavaNode
  class: JavaClassDescriptor?
  className: string?
  fields: {JavaFieldSpec}
  methods: {JavaMethodSpec}
  const new:() => (self)
  const newclass:(string, JavaClassDescriptor?) => (self)
  const import:(string) => (self)
end

local JavaNode = setmetatable({}, { __index = Node })
JavaNode.class = nil
JavaNode.className = nil
JavaNode.fields = {}
JavaNode.methods = {}

const function JavaNode:new(): self
  local c = setmetatable(Node:new(), { __index = self })
  c.class = nil
  c.className = nil
  c.fields = {}
  c.methods = {}
  return c
end

const function JavaNode:newclass(className: string, d: JavaClassDescriptor?)
  local c = self:new()

  local descriptor: JavaClassDescriptor = d or {}
  descriptor.implements = descriptor.implements or {}

  local firstLineBuf: {string} = {}
  if descriptor.visibility then
    if descriptor.visibility ~= 'public' and descriptor.visibility ~= 'private' then
      error(string.format('Class %s has invalid visibility: "%s"', className, descriptor.visibility), 2)
    end
    table.insert(firstLineBuf, #firstLineBuf + 1, descriptor.visibility)
  end
  
  if descriptor.static then
    table.insert(firstLineBuf, #firstLineBuf + 1, 'static')
  end

  table.insert(firstLineBuf, #firstLineBuf + 1, 'class')
  table.insert(firstLineBuf, #firstLineBuf + 1, className)

  if descriptor.extends then
    table.insert(firstLineBuf, #firstLineBuf + 1, 'extends')
    table.insert(firstLineBuf, #firstLineBuf + 1, descriptor.extends)
  end

  local interfaces: {string} = descriptor.implements or {}
  if #interfaces > 0 then
    table.insert(firstLineBuf, #firstLineBuf + 1, 'implements')
    local interfaceCommaList: string = table.concat(interfaces, ', ')
    table.insert(firstLineBuf, #firstLineBuf + 1, interfaceCommaList)
  end

  table.insert(firstLineBuf, #firstLineBuf + 1, '{')

  local line = table.concat(firstLineBuf, ' ')
  c:insertleft(line)
  c:insertright('}')

  c.class = d
  c.classname = className
  return c
end

const function JavaNode:import(fqcn: string)
  local line = string.format('import %s;', fqcn)
  local node = JavaNode:new():insertleft(line)
  node.unique = true
  self:rootchild(node)
  return self
end

local function makeAccessorName(prefix: string, fieldName: string)
  return table.concat({prefix, fieldName:upper():sub(1, 1), fieldName:sub(2)}, '')
end

local function makeFieldVarName(fieldName: string)
  return table.concat({'m', fieldName:upper():sub(1, 1), fieldName:sub(2)}, '')
end

local function generateGetterCode(fieldSpec: JavaFieldSpec)
  if type(fieldSpec.getter) == 'boolean' then
    local fieldVarName = makeFieldVarName(fieldSpec.fieldName)
    return table.concat({'return', fieldVarName, ';'}, ' ')
  else
    return fieldSpec.getter
  end
end

local function generateSetterCode(fieldSpec: JavaFieldSpec)
  if type(fieldSpec.setter) == 'boolean' then
    local fieldVarName = makeFieldVarName(fieldSpec.fieldName)
    return table.concat({fieldVarName, '=', fieldSpec.fieldName, ';'}, ' ')
  else
    return fieldSpec.setter
  end
end

local function generateField(fieldSpec: JavaFieldSpec)
  local declBuf: {string} = {}
  if fieldSpec.visibility then
    if fieldSpec.visibility ~= 'public' and fieldSpec.visibility ~= 'private' then
      error(string.format('Field %s has invalid visibility: "%s"', fieldSpec.fieldName, tostring(fieldSpec.visibility)), 3)
    end
    table.insert(declBuf, #declBuf + 1, fieldSpec.visibility)
  end
  if fieldSpec.static then
    table.insert(declBuf, #declBuf + 1, 'static')
  end
  if fieldSpec.optional then
    table.insert(declBuf, #declBuf + 1, '@Nullable')
  end
  table.insert(declBuf, #declBuf + 1, fieldSpec.fieldType)
  local fieldVarName = makeFieldVarName(fieldSpec.fieldName)
  table.insert(declBuf, #declBuf + 1, fieldVarName)
  if fieldSpec.fieldInit then
    table.insert(declBuf, #declBuf + 1, '=')
    table.insert(declBuf, #declBuf + 1, fieldSpec.fieldInit)
  end
  table.insert(declBuf, #declBuf + 1, ';')
  return JavaNode:new():insertleft(table.concat(declBuf, ' '))
end

const function JavaNode:field(fieldSpec: JavaFieldSpec)
  self:child(generateField(fieldSpec))
  if fieldSpec.optional then
    self:import(NullableFQCN)
  end

  if fieldSpec.getter then
    local accessorName = makeAccessorName('get', fieldSpec.fieldName)
    local code = generateGetterCode(fieldSpec)
    local spec: JavaMethodSpec = {
      methodName = accessorName,
      returnSpec = {returnType = fieldSpec.fieldType, optional = fieldSpec.optional},
      params = {},
      visibility = fieldSpec.getterVisibility,
      static = fieldSpec.static,
      code = code
    }
    self:method(spec)
  end

  if fieldSpec.setter then
    local accessorName = makeAccessorName('set', fieldSpec.fieldName)
    local code = generateSetterCode(fieldSpec)
    local spec: JavaMethodSpec = {
      methodName = accessorName,
      returnSpec = {returnType = 'void', optional = false},
      params = { {name = fieldSpec.fieldName, paramType = fieldSpec.fieldType, optional = fieldSpec.optional} },
      visibility = fieldSpec.setterVisibility,
      static = fieldSpec.static,
      code = code
    }
    self:method(spec)
  end

  table.insert(self.fields, #self.fields + 1, fieldSpec)

  return self
end

const function JavaNode:method(spec: JavaMethodSpec)
  local firstLineBuf: {string} = {}
  local codeNode = JavaNode:new()

  if spec.visibility then
    if spec.visibility ~= 'public' and spec.visibility ~= 'private' then
      error(string.format('Method %s has invalid visibility: "%s"', spec.methodName, tostring(spec.visibility)), 2)
    end
    table.insert(firstLineBuf, #firstLineBuf + 1, spec.visibility)
  end

  if spec.static then
    table.insert(firstLineBuf, #firstLineBuf + 1, 'static')
  end

  if spec.returnSpec.optional then
    self:import(NullableFQCN)
    table.insert(firstLineBuf, #firstLineBuf + 1, '@Nullable')
  end
  table.insert(firstLineBuf, #firstLineBuf + 1, spec.returnSpec.returnType)
  table.insert(firstLineBuf, #firstLineBuf + 1, spec.methodName)
  table.insert(firstLineBuf, #firstLineBuf + 1, '(')
  
  for i, param in ipairs(spec.params) do
    if param.optional then
      self:import(NullableFQCN)
      table.insert(firstLineBuf, #firstLineBuf + 1, '@Nullable')
    end
    table.insert(firstLineBuf, #firstLineBuf + 1, param.paramType)
    table.insert(firstLineBuf, #firstLineBuf + 1, param.name)
    if i < #spec.params then
      table.insert(firstLineBuf, #firstLineBuf + 1, ',')
    end
    if param.defaultValue then
      codeNode:joinleft(JavaNode:new()
        :insertleft(string.format('if (%s == null) {', param.name))
        :insertright('}')
        :child(JavaNode:new():insertleft(string.format('%s = %s;', param.name, param.defaultValue)))
      )
    end
  end

  table.insert(firstLineBuf, #firstLineBuf + 1, ')')
  table.insert(firstLineBuf, #firstLineBuf + 1, '{')

  if spec.code then
    codeNode:insertleft(spec.code)
  end

  local methodNode: JavaNode = JavaNode:new()
    :insertleft(table.concat(firstLineBuf, ' '))
    :insertright('}')
    :child(codeNode)

  self:child(methodNode)
  table.insert(self.methods, #self.methods + 1, spec)
  return self
end

return {
  JavaNode = JavaNode,
  makeFieldVarName = makeFieldVarName
}

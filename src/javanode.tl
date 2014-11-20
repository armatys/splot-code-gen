local javautils = require 'javautils'
local Node = require 'node'
local string = require 'string'

local NullableFQN = 'javax.annotation.Nullable'

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
  params: {JavaMethodParam}?
  visibility: string?
  static: boolean?
  code: string?
end

local interface JavaConstructorSpec
  params: {JavaMethodParam}?
  visibility: string?
  code: string?
end

interface JavaNode
  class: JavaClassDescriptor?
  className: string?
  fields: {JavaFieldSpec}
  methods: {JavaMethodSpec}
  node: Node

  const new:() => (self)
  const child:(Node) => (self)
  const code:() => (string)
  const constructor:(JavaConstructorSpec?) => (self)
  const field:(JavaFieldSpec) => (self)
  const generateMethodParams:({JavaMethodParam}?, {string}) => (Node)
  const import:(string) => (self)
  const method:(JavaMethodSpec) => (self)
  const setclass:(string, JavaClassDescriptor?) => (self)
end


local function isVisibilitySpecInvalid(visibility: string?): boolean
  return visibility ~= 'public' and visibility ~= 'private' and visibility ~= 'protected'
end

local function generateGetterCode(fieldSpec: JavaFieldSpec): string?
  local getter: string|boolean? = fieldSpec.getter
  if type(getter) == 'boolean' then
    local fieldVarName: string = javautils.makeFieldVarName(fieldSpec.fieldName)
    return table.concat({'return', fieldVarName, ';'}, ' ')
  elseif type(getter) == 'string' then
    return getter
  else
    return nil
  end
end

local function generateSetterCode(fieldSpec: JavaFieldSpec): string?
  local setter: string|boolean? = fieldSpec.setter
  if type(setter) == 'boolean' then
    local fieldVarName: string = javautils.makeFieldVarName(fieldSpec.fieldName)
    return table.concat({fieldVarName, '=', fieldSpec.fieldName, ';'}, ' ')
  elseif type(setter) == 'string' then
    return setter
  else
    return nil
  end
end

local function generateField(fieldSpec: JavaFieldSpec): Node
  local declBuf: {string} = {}
  if fieldSpec.visibility then
    if isVisibilitySpecInvalid(fieldSpec.visibility) then
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
  local fieldVarName: string = javautils.makeFieldVarName(fieldSpec.fieldName)
  table.insert(declBuf, #declBuf + 1, fieldVarName)
  if fieldSpec.fieldInit then
    table.insert(declBuf, #declBuf + 1, '=')
    table.insert(declBuf, #declBuf + 1, fieldSpec.fieldInit)
  end
  table.insert(declBuf, #declBuf + 1, ';')
  local node: Node = Node:new()
  node:insertleft(table.concat(declBuf, ' '))
  return node
end


local _class: JavaClassDescriptor? = nil
local _className: string? = nil
local _fields: {JavaFieldSpec} = {}
local _methods: {JavaMethodSpec} = {}
local _node: Node = Node:new()

local JavaNode = {}
JavaNode.class = _class
JavaNode.className = _className
JavaNode.fields = _fields
JavaNode.methods = _methods
JavaNode.node = _node

const function JavaNode:new(): self
  local c = setmetatable({}, { __index = self })

  local _class: JavaClassDescriptor? = nil
  local _className: string? = nil
  local _fields: {JavaFieldSpec} = {}
  local _methods: {JavaMethodSpec} = {}
  local _node: Node = Node:new()

  c.class = _class
  c.className = _className
  c.fields = _fields
  c.methods = _methods
  c.node = _node
  return c
end

const function JavaNode:child(node: Node): self
  self.node:child(node)
  return self
end

const function JavaNode:code(): string
  return self.node:code()
end

const function JavaNode:import(fqn: string)
  local line = string.format('import %s;', fqn)
  local node = Node:new()
  node:insertleft(line)
  node.unique = true
  self.node:rootchild(node)
  return self
end

const function JavaNode:generateMethodParams(_params: {JavaMethodParam}?, buf: {string}): Node
  local codeNode: Node = Node:new()
  local params: {JavaMethodParam} = _params or {}

  for i, param in ipairs(params) do
    if param.optional then
      JavaNode.import(self, NullableFQN) --self:import(NullableFQN)
      table.insert(buf, #buf + 1, '@Nullable')
    end
    table.insert(buf, #buf + 1, param.paramType)
    table.insert(buf, #buf + 1, param.name)
    if i < #params then
      table.insert(buf, #buf + 1, ',')
    end
    if param.defaultValue then
      local ifContentNode: Node = Node:new()
      ifContentNode:insertleft(string.format('%s = %s;', param.name, param.defaultValue))

      local ifNode: Node = Node:new()
      ifNode:insertleft(string.format('if (%s == null) {', param.name))
      ifNode:insertright('}')
      ifNode:child(ifContentNode)

      codeNode:joinleft(ifNode)
    end
  end
  return codeNode
end

const function JavaNode:constructor(s: JavaConstructorSpec?): self
  local spec: JavaConstructorSpec = s or {params=nil, visibility=nil, code=nil}
  spec.params = spec.params or {}

  local firstLineBuf: {string} = {}

  if spec.visibility then
    if isVisibilitySpecInvalid(spec.visibility) then
      error(string.format('Constructor for class %s has invalid visibility: "%s"', tostring(self.className), tostring(spec.visibility)), 2)
    end
    table.insert(firstLineBuf, #firstLineBuf + 1, spec.visibility)
  end

  table.insert(firstLineBuf, #firstLineBuf + 1, self.className)
  table.insert(firstLineBuf, #firstLineBuf + 1, '(')
  local codeNode: Node = JavaNode.generateMethodParams(self, spec.params, firstLineBuf) --self:generateMethodParams(spec.params, firstLineBuf, codeNode)
  table.insert(firstLineBuf, #firstLineBuf + 1, ') {')

  local code: string? = spec.code
  if type(code) == 'string' then
    codeNode:insertleft(code)
  end

  local constructorNode: Node = Node:new()
  constructorNode:insertleft(table.concat(firstLineBuf, ' '))
  constructorNode:insertright('}')
  constructorNode:child(codeNode)    

  self.node:child(constructorNode)

  return self
end

const function JavaNode:method(spec: JavaMethodSpec): self
  local firstLineBuf: {string} = {}
  spec.params = spec.params or {}

  if spec.visibility then
    if isVisibilitySpecInvalid(spec.visibility) then
      error(string.format('Method %s has invalid visibility: "%s"', spec.methodName, tostring(spec.visibility)), 2)
    end
    table.insert(firstLineBuf, #firstLineBuf + 1, spec.visibility)
  end

  if spec.static then
    table.insert(firstLineBuf, #firstLineBuf + 1, 'static')
  end

  if spec.returnSpec.optional then
    JavaNode.import(self, NullableFQN) --self:import(NullableFQN)
    table.insert(firstLineBuf, #firstLineBuf + 1, '@Nullable')
  end
  table.insert(firstLineBuf, #firstLineBuf + 1, spec.returnSpec.returnType)
  table.insert(firstLineBuf, #firstLineBuf + 1, spec.methodName)
  table.insert(firstLineBuf, #firstLineBuf + 1, '(')
  local codeNode: Node = JavaNode.generateMethodParams(self, spec.params, firstLineBuf) --self:generateMethodParams(spec.params, firstLineBuf)
  table.insert(firstLineBuf, #firstLineBuf + 1, ') {')

  local code: string? = spec.code
  if type(code) == 'string' then
    codeNode:insertleft(code)
  end

  local methodNode = Node:new()
  methodNode:insertleft(table.concat(firstLineBuf, ' '))
  methodNode:insertright('}')
  methodNode:child(codeNode)

  self.node:child(methodNode)
  table.insert(self.methods, #self.methods + 1, spec)
  return self
end

const function JavaNode:field(fieldSpec: JavaFieldSpec): self
  self.node:child(generateField(fieldSpec))
  if fieldSpec.optional then
    JavaNode.import(self, NullableFQN) --self:import(NullableFQN)
  end

  if fieldSpec.getter then
    local accessorName: string = javautils.makeAccessorName('get', fieldSpec.fieldName)
    local code = generateGetterCode(fieldSpec)
    if code then
      local spec: JavaMethodSpec = {
        methodName = accessorName,
        returnSpec = {returnType = fieldSpec.fieldType, optional = fieldSpec.optional},
        params = {},
        visibility = fieldSpec.getterVisibility,
        static = fieldSpec.static,
        code = code
      }
      JavaNode.method(self, spec) --self:method(spec)
    end
  end

  if fieldSpec.setter then
    local accessorName = javautils.makeAccessorName('set', fieldSpec.fieldName)
    local code = generateSetterCode(fieldSpec)
    if code then
      local spec: JavaMethodSpec = {
        methodName = accessorName,
        returnSpec = {returnType = 'void', optional = false},
        params = { {name = fieldSpec.fieldName, paramType = fieldSpec.fieldType, optional = fieldSpec.optional} },
        visibility = fieldSpec.setterVisibility,
        static = fieldSpec.static,
        code = code
      }
      JavaNode.method(self, spec) --self:method(spec)
    end
  end

  table.insert(self.fields, #self.fields + 1, fieldSpec)

  return self
end

const function JavaNode:setclass(className: string, d: JavaClassDescriptor?): self
  local descriptor: JavaClassDescriptor = d or {}
  descriptor.implements = descriptor.implements or {}

  local firstLineBuf: {string} = {}
  if descriptor.visibility then
    if isVisibilitySpecInvalid(descriptor.visibility) then
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
  self.node:insertleft(line)
  self.node:insertright('}')

  self.class = descriptor
  self.className = className
  return self
end

return JavaNode

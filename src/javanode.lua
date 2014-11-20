local javautils = require("javautils")
local Node = require("node")
local string = require("string")
local NullableFQN = "javax.annotation.Nullable"







local function isVisibilitySpecInvalid (visibility)
  return not (visibility == "public") and not (visibility == "private") and not (visibility == "protected")
end
local function generateGetterCode (fieldSpec)
  local getter = fieldSpec["getter"]
  if type(getter) == "boolean" then
    local fieldVarName = javautils["makeFieldVarName"](fieldSpec["fieldName"])
    return table["concat"]({"return", fieldVarName, ";"}," ")
  elseif type(getter) == "string" then
    return getter
  else
    return nil
  end
end
local function generateSetterCode (fieldSpec)
  local setter = fieldSpec["setter"]
  if type(setter) == "boolean" then
    local fieldVarName = javautils["makeFieldVarName"](fieldSpec["fieldName"])
    return table["concat"]({fieldVarName, "=", fieldSpec["fieldName"], ";"}," ")
  elseif type(setter) == "string" then
    return setter
  else
    return nil
  end
end
local function generateField (fieldSpec)
  local declBuf = {}
  if fieldSpec["visibility"] then
    if isVisibilitySpecInvalid(fieldSpec["visibility"]) then
      error(string["format"]("Field %s has invalid visibility: \"%s\"",fieldSpec["fieldName"],tostring(fieldSpec["visibility"])),3)
    end
    table["insert"](declBuf,#(declBuf) + 1,fieldSpec["visibility"])
  end
  if fieldSpec["static"] then
    table["insert"](declBuf,#(declBuf) + 1,"static")
  end
  if fieldSpec["optional"] then
    table["insert"](declBuf,#(declBuf) + 1,"@Nullable")
  end
  table["insert"](declBuf,#(declBuf) + 1,fieldSpec["fieldType"])
  local fieldVarName = javautils["makeFieldVarName"](fieldSpec["fieldName"])
  table["insert"](declBuf,#(declBuf) + 1,fieldVarName)
  if fieldSpec["fieldInit"] then
    table["insert"](declBuf,#(declBuf) + 1,"=")
    table["insert"](declBuf,#(declBuf) + 1,fieldSpec["fieldInit"])
  end
  table["insert"](declBuf,#(declBuf) + 1,";")
  local node = Node:new()
  node:insertleft(table["concat"](declBuf," "))
  return node
end
local _class = nil
local _className = nil
local _fields = {}
local _methods = {}
local _node = Node:new()
local JavaNode = {}
JavaNode["class"] = _class
JavaNode["className"] = _className
JavaNode["fields"] = _fields
JavaNode["methods"] = _methods
JavaNode["node"] = _node
JavaNode["new"] = function (self)
  local c = setmetatable({},{["__index"] = self})
  local _class = nil
  local _className = nil
  local _fields = {}
  local _methods = {}
  local _node = Node:new()
  c["class"] = _class
  c["className"] = _className
  c["fields"] = _fields
  c["methods"] = _methods
  c["node"] = _node
  return c
end
JavaNode["child"] = function (self, node)
  self["node"]:child(node)
  return self
end
JavaNode["code"] = function (self)
  return self["node"]:code()
end
JavaNode["import"] = function (self, fqn)
  local line = string["format"]("import %s;",fqn)
  local node = Node:new()
  node:insertleft(line)
  node["unique"] = true
  self["node"]:rootchild(node)
  return self
end
JavaNode["generateMethodParams"] = function (self, _params, buf)
  local codeNode = Node:new()
  local params = _params or {}
  for i, param in ipairs(params) do
    if param["optional"] then
      JavaNode["import"](self,NullableFQN)
      table["insert"](buf,#(buf) + 1,"@Nullable")
    end
    table["insert"](buf,#(buf) + 1,param["paramType"])
    table["insert"](buf,#(buf) + 1,param["name"])
    if i < #(params) then
      table["insert"](buf,#(buf) + 1,",")
    end
    if param["defaultValue"] then
      local ifContentNode = Node:new()
      ifContentNode:insertleft(string["format"]("%s = %s;",param["name"],param["defaultValue"]))
      local ifNode = Node:new()
      ifNode:insertleft(string["format"]("if (%s == null) {",param["name"]))
      ifNode:insertright("}")
      ifNode:child(ifContentNode)
      codeNode:joinleft(ifNode)
    end
  end
  return codeNode
end
JavaNode["constructor"] = function (self, s)
  local spec = s or {["params"] = nil, ["visibility"] = nil, ["code"] = nil}
  spec["params"] = spec["params"] or {}
  local firstLineBuf = {}
  if spec["visibility"] then
    if isVisibilitySpecInvalid(spec["visibility"]) then
      error(string["format"]("Constructor for class %s has invalid visibility: \"%s\"",tostring(self["className"]),tostring(spec["visibility"])),2)
    end
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["visibility"])
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,self["className"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"(")
  local codeNode = JavaNode["generateMethodParams"](self,spec["params"],firstLineBuf)
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,") {")
  local code = spec["code"]
  if type(code) == "string" then
    codeNode:insertleft(code)
  end
  local constructorNode = Node:new()
  constructorNode:insertleft(table["concat"](firstLineBuf," "))
  constructorNode:insertright("}")
  constructorNode:child(codeNode)
  self["node"]:child(constructorNode)
  return self
end
JavaNode["method"] = function (self, spec)
  local firstLineBuf = {}
  spec["params"] = spec["params"] or {}
  if spec["visibility"] then
    if isVisibilitySpecInvalid(spec["visibility"]) then
      error(string["format"]("Method %s has invalid visibility: \"%s\"",spec["methodName"],tostring(spec["visibility"])),2)
    end
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["visibility"])
  end
  if spec["static"] then
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"static")
  end
  if spec["returnSpec"]["optional"] then
    JavaNode["import"](self,NullableFQN)
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"@Nullable")
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["returnSpec"]["returnType"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["methodName"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"(")
  local codeNode = JavaNode["generateMethodParams"](self,spec["params"],firstLineBuf)
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,") {")
  local code = spec["code"]
  if type(code) == "string" then
    codeNode:insertleft(code)
  end
  local methodNode = Node:new()
  methodNode:insertleft(table["concat"](firstLineBuf," "))
  methodNode:insertright("}")
  methodNode:child(codeNode)
  self["node"]:child(methodNode)
  table["insert"](self["methods"],#(self["methods"]) + 1,spec)
  return self
end
JavaNode["field"] = function (self, fieldSpec)
  self["node"]:child(generateField(fieldSpec))
  if fieldSpec["optional"] then
    JavaNode["import"](self,NullableFQN)
  end
  if fieldSpec["getter"] then
    local accessorName = javautils["makeAccessorName"]("get",fieldSpec["fieldName"])
    local code = generateGetterCode(fieldSpec)
    if code then
      local spec = {["methodName"] = accessorName, ["returnSpec"] = {["returnType"] = fieldSpec["fieldType"], ["optional"] = fieldSpec["optional"]}, ["params"] = {}, ["visibility"] = fieldSpec["getterVisibility"], ["static"] = fieldSpec["static"], ["code"] = code}
      JavaNode["method"](self,spec)
    end
  end
  if fieldSpec["setter"] then
    local accessorName = javautils["makeAccessorName"]("set",fieldSpec["fieldName"])
    local code = generateSetterCode(fieldSpec)
    if code then
      local spec = {["methodName"] = accessorName, ["returnSpec"] = {["returnType"] = "void", ["optional"] = false}, ["params"] = {{["name"] = fieldSpec["fieldName"], ["paramType"] = fieldSpec["fieldType"], ["optional"] = fieldSpec["optional"]}}, ["visibility"] = fieldSpec["setterVisibility"], ["static"] = fieldSpec["static"], ["code"] = code}
      JavaNode["method"](self,spec)
    end
  end
  table["insert"](self["fields"],#(self["fields"]) + 1,fieldSpec)
  return self
end
JavaNode["setclass"] = function (self, className, d)
  local descriptor = d or {}
  descriptor["implements"] = descriptor["implements"] or {}
  local firstLineBuf = {}
  if descriptor["visibility"] then
    if isVisibilitySpecInvalid(descriptor["visibility"]) then
      error(string["format"]("Class %s has invalid visibility: \"%s\"",className,descriptor["visibility"]),2)
    end
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,descriptor["visibility"])
  end
  if descriptor["static"] then
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"static")
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"class")
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,className)
  if descriptor["extends"] then
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"extends")
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,descriptor["extends"])
  end
  local interfaces = descriptor["implements"] or {}
  if 0 < #(interfaces) then
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"implements")
    local interfaceCommaList = table["concat"](interfaces,", ")
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,interfaceCommaList)
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"{")
  local line = table["concat"](firstLineBuf," ")
  self["node"]:insertleft(line)
  self["node"]:insertright("}")
  self["class"] = descriptor
  self["className"] = className
  return self
end
return JavaNode


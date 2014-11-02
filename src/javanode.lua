local javautils = require("javautils")
local Node = require("node")
local string = require("string")
local NullableFQN = "javax.annotation.Nullable"







local function isVisibilitySpecInvalid (visibility)
  return not (visibility == "public") and not (visibility == "private") and not (visibility == "protected")
end
local JavaNode = setmetatable({["class"] = nil, ["className"] = nil, ["fields"] = {}, ["methods"] = {}},{["__index"] = Node})
JavaNode["new"] = function (self)
  local c = setmetatable(Node:new(),{["__index"] = self})
  c["class"] = nil
  c["className"] = nil
  c["fields"] = {}
  c["methods"] = {}
  return c
end
JavaNode["newclass"] = function (self, className, d)
  local c = self:new()
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
  c:insertleft(line)
  c:insertright("}")
  c["class"] = d
  c["className"] = className
  return c
end
JavaNode["import"] = function (self, fqn)
  local line = string["format"]("import %s;",fqn)
  local node = JavaNode:new():insertleft(line)
  node["unique"] = true
  self:rootchild(node)
  return self
end
local function generateGetterCode (fieldSpec)
  if type(fieldSpec["getter"]) == "boolean" then
    local fieldVarName = javautils["makeFieldVarName"](fieldSpec["fieldName"])
    return table["concat"]({"return", fieldVarName, ";"}," ")
  else
    return fieldSpec["getter"]
  end
end
local function generateSetterCode (fieldSpec)
  if type(fieldSpec["setter"]) == "boolean" then
    local fieldVarName = javautils["makeFieldVarName"](fieldSpec["fieldName"])
    return table["concat"]({fieldVarName, "=", fieldSpec["fieldName"], ";"}," ")
  else
    return fieldSpec["setter"]
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
  return JavaNode:new():insertleft(table["concat"](declBuf," "))
end
JavaNode["field"] = function (self, fieldSpec)
  self:child(generateField(fieldSpec))
  if fieldSpec["optional"] then
    self:import(NullableFQN)
  end
  if fieldSpec["getter"] then
    local accessorName = javautils["makeAccessorName"]("get",fieldSpec["fieldName"])
    local code = generateGetterCode(fieldSpec)
    local spec = {["methodName"] = accessorName, ["returnSpec"] = {["returnType"] = fieldSpec["fieldType"], ["optional"] = fieldSpec["optional"]}, ["params"] = {}, ["visibility"] = fieldSpec["getterVisibility"], ["static"] = fieldSpec["static"], ["code"] = code}
    self:method(spec)
  end
  if fieldSpec["setter"] then
    local accessorName = javautils["makeAccessorName"]("set",fieldSpec["fieldName"])
    local code = generateSetterCode(fieldSpec)
    local spec = {["methodName"] = accessorName, ["returnSpec"] = {["returnType"] = "void", ["optional"] = false}, ["params"] = {{["name"] = fieldSpec["fieldName"], ["paramType"] = fieldSpec["fieldType"], ["optional"] = fieldSpec["optional"]}}, ["visibility"] = fieldSpec["setterVisibility"], ["static"] = fieldSpec["static"], ["code"] = code}
    self:method(spec)
  end
  table["insert"](self["fields"],#(self["fields"]) + 1,fieldSpec)
  return self
end
JavaNode["generateMethodParams"] = function (self, params, buf, codeNode)
  for i, param in ipairs(params) do
    if param["optional"] then
      self:import(NullableFQN)
      table["insert"](buf,#(buf) + 1,"@Nullable")
    end
    table["insert"](buf,#(buf) + 1,param["paramType"])
    table["insert"](buf,#(buf) + 1,param["name"])
    if i < #(params) then
      table["insert"](buf,#(buf) + 1,",")
    end
    if param["defaultValue"] then
      codeNode:joinleft(JavaNode:new():insertleft(string["format"]("if (%s == null) {",param["name"])):insertright("}"):child(JavaNode:new():insertleft(string["format"]("%s = %s;",param["name"],param["defaultValue"]))))
    end
  end
end
JavaNode["method"] = function (self, spec)
  local firstLineBuf = {}
  local codeNode = JavaNode:new()
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
    self:import(NullableFQN)
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,"@Nullable")
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["returnSpec"]["returnType"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["methodName"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"(")
  self:generateMethodParams(spec["params"],firstLineBuf,codeNode)
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,") {")
  if spec["code"] then
    codeNode:insertleft(spec["code"])
  end
  local methodNode = JavaNode:new():insertleft(table["concat"](firstLineBuf," ")):insertright("}"):child(codeNode)
  self:child(methodNode)
  table["insert"](self["methods"],#(self["methods"]) + 1,spec)
  return self
end
JavaNode["constructor"] = function (self, spec)
  spec = spec or {}
  spec["params"] = spec["params"] or {}
  local firstLineBuf = {}
  local codeNode = JavaNode:new()
  if spec["visibility"] then
    if isVisibilitySpecInvalid(spec["visibility"]) then
      error(string["format"]("Constructor for class %s has invalid visibility: \"%s\"",tostring(self["className"]),tostring(spec["visibility"])),2)
    end
    table["insert"](firstLineBuf,#(firstLineBuf) + 1,spec["visibility"])
  end
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,self["className"])
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,"(")
  self:generateMethodParams(spec["params"],firstLineBuf,codeNode)
  table["insert"](firstLineBuf,#(firstLineBuf) + 1,") {")
  if spec["code"] then
    codeNode:insertleft(spec["code"])
  end
  local constructorNode = JavaNode:new():insertleft(table["concat"](firstLineBuf," ")):insertright("}"):child(codeNode)
  self:child(constructorNode)
  return self
end
return JavaNode


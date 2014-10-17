local Node = require("codetree")["Node"]
local string = require("string")


local JavaNode = setmetatable({},{["__index"] = Node})
JavaNode["new"] = function (self)
  local c = setmetatable(Node:new(),{["__index"] = self})
  return c
end
JavaNode["newclass"] = function (self, className, d)
  local c = self:new()
  local descriptor = d or {}
  descriptor["implements"] = descriptor["implements"] or {}
  local firstLine = {}
  if descriptor["visibility"] then
    if not (descriptor["visibility"] == "public") and not (descriptor["visibility"] == "private") then
      error(string["format"]("Class %s has invalid visibility: \"%s\"",className,descriptor["visibility"]),2)
    end
    table["insert"](firstLine,#(firstLine) + 1,descriptor["visibility"])
  end
  if descriptor["static"] then
    table["insert"](firstLine,#(firstLine) + 1,"static")
  end
  table["insert"](firstLine,#(firstLine) + 1,"class")
  table["insert"](firstLine,#(firstLine) + 1,className)
  if descriptor["extends"] then
    table["insert"](firstLine,#(firstLine) + 1,"extends")
    table["insert"](firstLine,#(firstLine) + 1,descriptor["extends"])
  end
  local interfaces = descriptor["implements"] or {}
  if 0 < #(interfaces) then
    table["insert"](firstLine,#(firstLine) + 1,"implements")
    local interfaceCommaList = table["concat"](interfaces,", ")
    table["insert"](firstLine,#(firstLine) + 1,interfaceCommaList)
  end
  table["insert"](firstLine,#(firstLine) + 1,"{")
  local line = table["concat"](firstLine," ")
  c:insertleft(line)
  c:insertright("}")
  return c
end
JavaNode["import"] = function (self, fqcn)
  local line = string["format"]("import %s;",fqcn)
  self:rootchild(JavaNode:new():insertleft(line))
  return self
end
return {["JavaNode"] = JavaNode}


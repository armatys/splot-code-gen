local string = require("string")
local table = require("table")

local function iterateChildren (children, level, code)
  local lines = {}
  for _, childnode in ipairs(children) do
    local codelines = childnode:tree(level)
    for _, line in ipairs(codelines) do
      local canInsert = true
      if childnode["unique"] then
        if lines[line] then
          canInsert = false
        end
        lines[line] = true
      end
      if canInsert then
        table["insert"](code,#(code) + 1,line)
      end
    end
  end
end
local function iterateContents (contents, level, code)
  local whitespace = string["rep"]("  ",level,nil)
  for _, v in ipairs(contents) do
    for line in string["gmatch"](v,"[^\n]+") do
      if not (line:match("^%s*$",nil)) then
        table["insert"](code,#(code) + 1,whitespace .. line)
      end
    end
  end
end
local _left_contents = {}
local _right_contents = {}
local _children = {}
local _root_children = {}
local _unique = false
local Node = {}
Node["left_contents"] = _left_contents
Node["right_contents"] = _right_contents
Node["children"] = _children
Node["root_children"] = _root_children
Node["unique"] = _unique
Node["new"] = function (self)
  local t = {}
  local _left_contents = {}
  local _right_contents = {}
  local _children = {}
  local _root_children = {}
  local _unique = false
  t["left_contents"] = _left_contents
  t["right_contents"] = _right_contents
  t["children"] = _children
  t["root_children"] = _root_children
  t["unique"] = _unique
  local s = setmetatable(t,{["__index"] = self})
  return s
end
Node["insertleft"] = function (self, code, pos)
  local p = pos or #(self["left_contents"]) + 1
  local contents = self["left_contents"]
  table["insert"](contents,p,code)
  return self
end
Node["insertright"] = function (self, code, pos)
  local p = pos or #(self["right_contents"]) + 1
  local contents = self["right_contents"]
  table["insert"](contents,p,code)
  return self
end
Node["child"] = function (self, node)
  local t = self["children"]
  table["insert"](t,#(t) + 1,node)
  return self
end
Node["rootchild"] = function (self, node, prepend)
  local t = self["root_children"]
  local pos = prepend and 1 or #(t) + 1
  table["insert"](t,pos,node)
  return self
end
Node["tree"] = function (self, level)
  level = level or 0
  local code = {}
  if level == 0 then
    iterateChildren(self["root_children"],0,code)
    for _, childnode in ipairs(self["children"]) do
      iterateChildren(childnode["root_children"],0,code)
    end
  end
  iterateContents(self["left_contents"],level,code)
  iterateChildren(self["children"],level + 1,code)
  iterateContents(self["right_contents"],level,code)
  return code
end
Node["joinleft"] = function (self, tree)
  for _, v in ipairs(tree) do
    local t = self["left_contents"]
    table["insert"](t,#(t) + 1,v)
  end
  return self
end
Node["joinright"] = function (self, tree)
  for _, v in ipairs(tree) do
    local t = self["right_contents"]
    table["insert"](t,#(t) + 1,v)
  end
  return self
end
Node["code"] = function (self)
  local t = self:tree()
  return table["concat"](t,"\n")
end
return Node


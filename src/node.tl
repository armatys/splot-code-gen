local string = require 'string'
local table = require 'table'

interface Node
  left_contents: {string}
  right_contents: {string}
  children: {Node}
  root_children: {Node}
  unique: boolean?

  const new:() => (self)
  const insertleft:(string, number?) => (self)
  const insertright:(string, number?) => (self)
  const child:(Node) => (self)
  const rootchild:(Node) => (self)
  const joinleft:(Node) => (self)
  const joinright:(Node) => (self)
  const tree:(number?) => ({string})
  const code:() => (string)
end

local function iterateChildren(children: {Node}, level: number, code: {string})
  local lines: {string: boolean} = {}
  for _, childnode in ipairs(children) do
    local codelines = childnode:tree(level)
    for _, line in ipairs(codelines) do
      local canInsert = true
      if childnode.unique then
        if lines[line] then
          canInsert = false
        end
        lines[line] = true
      end
      if canInsert then
        table.insert(code, #code + 1, line)
      end
    end
  end
end

local function iterateContents(contents: {string}, level: number, code: {string})
  local whitespace: string = string.rep('  ', level, nil)
  for _, v in ipairs(contents) do
    for line in string.gmatch(v, '[^\n]+') do
      if not line:match('^%s*$', nil) then
        table.insert(code, #code + 1, whitespace .. line)
      end
    end
  end
end

local _left_contents: {string} = {}
local _right_contents: {string} = {}
local _children: {Node} = {}
local _root_children: {Node} = {}
local _unique: boolean? = false

local Node = {}
Node.left_contents = _left_contents
Node.right_contents = _right_contents
Node.children = _children
Node.root_children = _root_children
Node.unique = _unique

const function Node:new(): self
  local s = setmetatable({}, {__index = self})

  local _left_contents: {string} = {}
  local _right_contents: {string} = {}
  local _children: {Node} = {}
  local _root_children: {Node} = {}
  local _unique: boolean? = false

  s.left_contents = _left_contents
  s.right_contents = _right_contents
  s.children = _children
  s.root_children = _root_children
  s.unique = _unique
  return s
end

const function Node:insertleft(code: string, pos: number?): self
  pos = pos or #self.left_contents + 1
  table.insert(self.left_contents, pos, code)
  return self
end

const function Node:insertright(code: string, pos: number?): self
  pos = pos or #self.right_contents + 1
  table.insert(self.right_contents, pos, code)
  return self
end

const function Node:child(node: Node): self
  table.insert(self.children, #self.children + 1, node)
  return self
end

const function Node:rootchild(node: Node): self
  table.insert(self.root_children, #self.root_children + 1, node)
  return self
end

const function Node:tree(level: number?): {string}
  level = level or 0
  local code: {string} = {}

  if level == 0 then
    iterateChildren(self.root_children, 0, code)
    for _, childnode in ipairs(self.children) do
      iterateChildren(childnode.root_children, 0, code)
    end
  end

  iterateContents(self.left_contents, level, code)
  iterateChildren(self.children, level + 1, code)
  iterateContents(self.right_contents, level, code)

  return code
end

const function Node:joinleft(node: Node): self
  local t = Node.tree(node) --node:tree()
  for _, v in ipairs(t) do
    table.insert(self.left_contents, #self.left_contents + 1, v)
  end
  return self
end

const function Node:joinright(node: Node): self
  local t = Node.tree(node) --node:tree()
  for _, v in ipairs(t) do
    table.insert(self.right_contents, #self.right_contents + 1, v)
  end
  return self
end

const function Node:code(): string
  local t = self:tree()
  return table.concat(t, '\n')
end

return Node

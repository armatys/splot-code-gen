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
  const rootchild:(Node, boolean?) => (self)
  const joinleft:({string}) => (self)
  const joinright:({string}) => (self)
  const tree:(number?) => ({string})
  const code:() => (string)
end

local function iterateChildren(children: {Node}, level: integer, code: {string})
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

local function iterateContents(contents: {string}, level: integer, code: {string})
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
  local t = {}
  local _left_contents: {string} = {}
  local _right_contents: {string} = {}
  local _children: {Node} = {}
  local _root_children: {Node} = {}
  local _unique: boolean? = false

  t.left_contents = _left_contents
  t.right_contents = _right_contents
  t.children = _children
  t.root_children = _root_children
  t.unique = _unique

  local s = setmetatable(t, {__index = self})
  return s
end

const function Node:insertleft(code: string, pos: number?): self
  local p: number = pos or #self.left_contents + 1
  local contents: {string} = self.left_contents
  table.insert(contents, p, code)
  return self
end

const function Node:insertright(code: string, pos: number?): self
  local p: number = pos or #self.right_contents + 1
  local contents: {string} = self.right_contents
  table.insert(contents, p, code)
  return self
end

const function Node:child(node: Node): self
  local t: {Node} = self.children
  table.insert(t, #t + 1, node)
  return self
end

const function Node:rootchild(node: Node, prepend: boolean?): self
local t: {Node} = self.root_children
  local pos: number = prepend and 1 or #t + 1
  table.insert(t, pos, node)
  return self
end

const function Node:tree(level: integer?): {string}
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

const function Node:joinleft(tree: {string}): self
  for _, v in ipairs(tree) do
    local t: {string} = self.left_contents
    table.insert(t, #t + 1, v)
  end
  return self
end

const function Node:joinright(tree: {string}): self
  for _, v in ipairs(tree) do
    local t: {string} = self.right_contents
    table.insert(t, #t + 1, v)
  end
  return self
end

const function Node:code(): string
  local t = self:tree()
  return table.concat(t, '\n')
end


return Node

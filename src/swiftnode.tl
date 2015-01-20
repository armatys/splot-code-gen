local Node = require 'node'
local string = require 'string'

interface SwiftNode
  node: Node

  const new:() => (self)
  const child:(Node) => (self)
  const code:() => (string)
end

local _node: Node = Node:new()

local SwiftNode = {}
SwiftNode.node = _node

const function SwiftNode:new(): self
  local _node: Node = Node:new()

  local t = {}
  t.node = _node

  local s = setmetatable(t, {__index = self})
  return s
end

const function SwiftNode:child(node: Node): self
  local n: Node = self.node
  n:child(node)
  return self
end

const function SwiftNode:code(): string
  return self.node:code()
end

return SwiftNode

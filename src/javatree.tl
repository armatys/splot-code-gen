local Node = require 'codetree'.Node
local string = require 'string'

local interface JavaClassDescriptor
  visibility: string?
  static: boolean?
  implements: {string}?
  extends: string?
end

local interface JavaNode
  const new:() => (self)
  const newclass:(string, JavaClassDescriptor?) => (self)
  const import:(string) => (self)
end

local JavaNode = setmetatable({}, { __index = Node })
-- Set other properties

const function JavaNode:new(): self
  local c = setmetatable(Node:new(), { __index = self })
  -- Set other properties
  return c
end

const function JavaNode:newclass(className: string, d: JavaClassDescriptor?)
  local c = self:new()

  local descriptor: JavaClassDescriptor = d or {}
  descriptor.implements = descriptor.implements or {}

  local firstLine: {string} = {}
  if descriptor.visibility then
    if descriptor.visibility ~= 'public' and descriptor.visibility ~= 'private' then
      error(string.format('Class %s has invalid visibility: "%s"', className, descriptor.visibility), 2)
    end
    table.insert(firstLine, #firstLine + 1, descriptor.visibility)
  end
  
  if descriptor.static then
    table.insert(firstLine, #firstLine + 1, 'static')
  end

  table.insert(firstLine, #firstLine + 1, 'class')
  table.insert(firstLine, #firstLine + 1, className)

  if descriptor.extends then
    table.insert(firstLine, #firstLine + 1, 'extends')
    table.insert(firstLine, #firstLine + 1, descriptor.extends)
  end

  local interfaces: {string} = descriptor.implements or {}
  if #interfaces > 0 then
    table.insert(firstLine, #firstLine + 1, 'implements')
    local interfaceCommaList: string = table.concat(interfaces, ', ')
    table.insert(firstLine, #firstLine + 1, interfaceCommaList)
  end

  table.insert(firstLine, #firstLine + 1, '{')

  local line = table.concat(firstLine, ' ')
  c:insertleft(line)
  c:insertright('}')
  return c
end

const function JavaNode:import(fqcn: string)
  local line = string.format('import %s;', fqcn)
  self:rootchild(JavaNode:new():insertleft(line))
  return self
end

return {JavaNode = JavaNode}

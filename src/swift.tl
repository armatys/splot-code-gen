local SwiftNode = require 'swiftnode'
local table = require 'table'

local interface Context
  luaModuleName: string
  swiftModuleName: string
  plainAst: {any: any}
  typecheckedAst: {any: any}
end

local function processTTable(context: Context, ttable: {any: any}, topLevel: boolean?): SwiftNode
  local swiftNode: SwiftNode = SwiftNode:new()
  -- swiftNode:package('io.splot.L')
  -- swiftNode:import('io.splot.LuaTable')
  
  return swiftNode
end

local function findReturnNode(ast: {any: any}): (number, any)?
  for i, v in ipairs(ast) do
    if v.tag == 'Return' then
      return i, v
    end
  end
  return nil, 'Could not find the return node.'
end

local function process(luaModuleName: string, swiftModuleName: string, plainAst: {any: any}, typecheckedAst: {any: any}): string
  local ctx: Context = {
    luaModuleName = luaModuleName,
    swiftModuleName = swiftModuleName,
    plainAst = plainAst,
    typecheckedAst = typecheckedAst
  }
  local i, retNode = findReturnNode(typecheckedAst)
  if not i then
    error(retNode, 2)
  end

  local rootNode: SwiftNode = processTTable(ctx, retNode, true)
  local code: string = rootNode:code()
  return code
end


return {
  name = 'Swift',
  process = process
}
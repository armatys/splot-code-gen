local javatree = require 'javatree'
local JavaNode = javatree.JavaNode
local table = require 'table'

local interface Context
  luaModuleName: string
  javaModuleName: string
  plainAst: {any: any}
  typecheckedAst: {any: any}
end

local function tinsert(t, el)
  table.insert(t, #t + 1, el)
end

local function processTTable(context: Context, ttable: {any: any}, topLevel: boolean?)
  local node = JavaNode:new()
  node:import('pl.makenika.splot.LuaTable')
  
  return node
end

local function findReturnNode(ast: {any: any}): (int, {any: any})?
  for i, v in ipairs(ast) do
    if v.tag == 'Return' then
      return i, v
    end
  end
  return nil
end

local function process(luaModuleName: string, javaModuleName: string, plainAst: {any: any}, typecheckedAst: {any: any}): string
  local ctx: Context = {
    luaModuleName = luaModuleName,
    javaModuleName = javaModuleName,
    plainAst = plainAst,
    typecheckedAst = typecheckedAst,
    tree = JavaNode:new()
  }
  local i, retNode = findReturnNode(typecheckedAst)
  if not i then
    error('Could not find the return node.', 2)
  end

  local rootNode = processTTable(ctx, retNode, true)
  return rootNode:code()
end

return {
  name = 'Java',
  process = process
}
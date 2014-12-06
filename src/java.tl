local JavaNode = require 'javanode'
local table = require 'table'

local interface Context
  luaModuleName: string
  javaModuleName: string
  plainAst: {any: any}
  typecheckedAst: {any: any}
end

local function processTTable(context: Context, ttable: {any: any}, topLevel: boolean?): JavaNode
  local javaNode: JavaNode = JavaNode:new()
  javaNode:package('io.splot.L')
  javaNode:import('io.splot.LuaTable')
  
  return javaNode
end

local function findReturnNode(ast: {any: any}): (number, any)?
  for i, v in ipairs(ast) do
    if v.tag == 'Return' then
      return i, v
    end
  end
  return nil, 'Could not find the return node.'
end

local function process(luaModuleName: string, javaModuleName: string, plainAst: {any: any}, typecheckedAst: {any: any}): string
  local ctx: Context = {
    luaModuleName = luaModuleName,
    javaModuleName = javaModuleName,
    plainAst = plainAst,
    typecheckedAst = typecheckedAst
  }
  local i, retNode = findReturnNode(typecheckedAst)
  if not i then
    error(retNode, 2)
  end

  local rootNode: JavaNode = processTTable(ctx, retNode, true)
  local code: string = rootNode:code()
  return code
end


return {
  name = 'Java',
  process = process
}
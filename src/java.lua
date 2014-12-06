local JavaNode = require("javanode")
local table = require("table")

local function processTTable (context, ttable, topLevel)
  local javaNode = JavaNode:new()
  javaNode:package("io.splot.L")
  javaNode:import("io.splot.LuaTable")
  return javaNode
end
local function findReturnNode (ast)
  for i, v in ipairs(ast) do
    if v["tag"] == "Return" then
      return i, v
    end
  end
  return nil, "Could not find the return node."
end
local function process (luaModuleName, javaModuleName, plainAst, typecheckedAst)
  local ctx = {["luaModuleName"] = luaModuleName, ["javaModuleName"] = javaModuleName, ["plainAst"] = plainAst, ["typecheckedAst"] = typecheckedAst}
  local i, retNode = findReturnNode(typecheckedAst)
  if not (i) then
    error(retNode,2)
  end
  local rootNode = processTTable(ctx,retNode,true)
  local code = rootNode:code()
  return code
end
return {["name"] = "Java", ["process"] = process}


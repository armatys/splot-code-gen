local javatree = require("javatree")
local JavaNode = javatree["JavaNode"]
local table = require("table")

local function tinsert (t, el)
  table["insert"](t,#(t) + 1,el)
end
local function processTTable (context, node, ttable, topLevel)
  node:import("pl.makenika.splot.LuaTable")
  local lineBuf = {}
  tinsert(lineBuf,"")
end
local function findReturnNode (ast)
  for i, v in ipairs(ast) do
    if v["tag"] == "Return" then
      return i, v
    end
  end
  return nil
end
local function process (luaModuleName, javaModuleName, plainAst, typecheckedAst)
  local ctx = {["luaModuleName"] = luaModuleName, ["javaModuleName"] = javaModuleName, ["plainAst"] = plainAst, ["typecheckedAst"] = typecheckedAst, ["tree"] = JavaNode:new()}
  local i, retNode = findReturnNode(typecheckedAst)
  if not (i) then
    error("Could not find the return node.",2)
  end
  local rootNode = JavaNode:new()
  processTTable(ctx,rootNode,retNode,true)
  return ctx["tree"]:code()
end
return {["name"] = "Java", ["process"] = process}


#!/usr/bin/env lua

local dir = require 'dir'.dir
local io = require 'io'
local lpeg = require 'lpeg'
local math = require 'math'
local os = require 'os'
local string = require 'string'
local swift = require 'swift'
local table = require 'table'
local tlparser = require 'typedlua.tlparser'
local tlchecker = require 'typedlua.tlchecker'

local STRICT = false
local WARNINGS = false

local function getcontents (filename)
  local file = assert(io.open(filename, 'r'))
  local contents = file:read('*a')
  file:close()
  return contents
end

local function setcontents (contents, filename)
  local file = assert(io.open(filename, 'w'))
  file:write(contents)
  file:write('\n')
  file:close()
end

local function validArgs()
  if #arg ~= 3 then
    print('usage: [input_file] [lua_module_name] [output_file]')
    return false
  end
  return true
end

local function parseAst(subject, filename)
  local ast, error_msg = tlparser.parse(subject, filename, STRICT)
  if not ast then
    print(error_msg)
    os.exit(1)
  end

  ast, error_msg = tlchecker.typecheck(ast, subject, filename, STRICT, WARNINGS)
  if error_msg then
    print(error_msg)
    os.exit(1)
  end

  return ast
end

local function findReturnNode(ast)
  for i, v in ipairs(ast) do
    if v.tag == 'Return' then
      return i, v
    end
  end
  return nil
end

local function formatCodeTable(codeTable, level)
  local buf = {}
  level = level or 0
  for _, v in ipairs(codeTable) do
    if type(v) == 'table' then
      local code = formatCodeTable(v, level + 1)
      table.insert(buf, code)
    else
      local indent = 2 * level
      table.insert(buf, string.rep(' ', indent))
      table.insert(buf, tostring(v))
      table.insert(buf, '\n')
    end
  end
  return table.concat(buf, '')
end

local function generateCode(luaModuleName, moduleName, ast)
  local nodeI, returnNode = findReturnNode(ast)
  if not nodeI then
    error 'Could not find the return node.'
  end

  local returnNodeType = returnNode[1].type
  if returnNodeType.tag ~= 'TTable' then
    error 'The returned object must be a table.'
  end

  local codeTable = swift.processTable(moduleName, returnNodeType, luaModuleName)
  return formatCodeTable(codeTable)
end

function gsub (s, patt, repl)
  patt = lpeg.P(patt)
  patt = lpeg.Cs((patt / repl + 1)^0)
  return lpeg.match(patt, s)
end

local function getModuleName(filepath)
  local c = lpeg.P{
    'S';
    S = (lpeg.V'elem' * lpeg.V'sep')^0 * lpeg.C(lpeg.V'fname'),
    elem = (1 - lpeg.S'/')^1,
    fname = (1 - (lpeg.P'.' * lpeg.V'fext' * -1))^1,
    fext = lpeg.R'az'^1,
    sep = lpeg.P'/'
  }
  return c:match(filepath)
end

local function main()
  if not validArgs() then
    os.exit(1)
  end

  local inFilePath = arg[1]
  local luaModuleName = arg[2]
  local outFilePath = arg[3]
  local subject = getcontents(inFilePath)
  local ok, astOrMsg = pcall(parseAst, subject, inFilePath)

  if not ok then
    print('Could not parse AST', astOrMsg)
    os.exit(1)
  end

  local moduleName = getModuleName(outFilePath)
  local ok, codeOrErr = pcall(generateCode, luaModuleName, moduleName, astOrMsg)
  if not ok then
    print('Could not generate the code', codeOrErr)
    os.exit(1)
  end
  print(codeOrErr)
end

main()
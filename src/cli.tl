local io = require 'io'
local java = require 'java'
local lpeg = require 'lpeg'
local math = require 'math'
local os = require 'os'
local pretty = require 'pretty'
local string = require 'string'
local swift = require 'swift'
local table = require 'table'
local tlparser = require 'typedlua.tlparser'
local tlchecker = require 'typedlua.tlchecker'

local STRICT = false
local INTEGER = true

local interface ProgramGenerator
  name: string
  process: (string, string, {any: any}, {any: any}) -> (string) -- luaModuleName, outModuleName, plainAst, typecheckedAst
end

local function writeError(message: string)
  local oldStdOut = io.output()
  io.output(io.stderr)
  io.write(message .. '\n')
  io.output(oldStdOut)
end

local EmptyGenerator: ProgramGenerator = {
  name = 'Empty Generator',
  process = function(luaModuleName: string, outModuleName: string, plainAst: {any: any}, typecheckedAst: {any: any}): string
    error('Could not infer the generator from the target file extension (java or swift).')
    return ''
  end
}

local interface ProgramArgs
  inFilePath: string
  outFilePath: string
  luaModuleName: string
end

local function getContents(filename: string): string
  local file = assert(io.open(filename, 'r'), 'Could not get the file contents')
  local contents = file:read('*a')
  file:close()
  return contents
end

local function setContents(contents: string, filename: string)
  local file = assert(io.open(filename, 'w+'), 'Could not save a file')
  file:write(contents)
  file:write('\n')
  file:close()
end

local function getModuleName(filepath: string): string?
  local c = lpeg.P{
    'S';
    S = lpeg.V'sep'^0 * (lpeg.V'elem' * lpeg.V'sep')^0 * lpeg.C(lpeg.V'fname'),
    elem = (1 - lpeg.S'/')^1,
    fname = (1 - (lpeg.P'.' * lpeg.V'fext' * -1))^1,
    fext = lpeg.R'az'^1,
    sep = lpeg.P'/'
  }
  return c:match(filepath)
end

local function getProgramArguments(args: {string}): (ProgramArgs)?
  if #args ~= 3 then
    return nil, [[
Usage: lua main.lua input_file lua_module_name output_file
output_file should have either ".java" or ".swift" extension.
]]
  end
  local inFilePath = args[1] or ''
  local luaModuleName = args[2] or ''
  local outFilePath = args[3] or ''
  return {inFilePath=inFilePath, outFilePath=outFilePath, luaModuleName=luaModuleName}
end

local function getGenerator(outFilePath: string): ProgramGenerator?
  if outFilePath:match('.*%.swift$') then
    return swift
  elseif outFilePath:match('.*%.java$') then
    return java
  else
    return nil
  end
end

local function getPlainAst(subject: string, inFilePath: string, strict: boolean): ({any: any})?
  local subject: string = getContents(inFilePath)
  local plainAst: {any: any}?, errorMessage: string? = tlparser.parse(subject, inFilePath, strict)
  if plainAst then
    return plainAst
  elseif errorMessage then
    return nil, errorMessage
  else
    return nil, 'Could not parse the file (report a bug)'
  end
end

local function runArguments(arguments: ProgramArgs): (boolean)?
  local subject: string = getContents(arguments.inFilePath)
  local plainAst: {any: any}?, err: string? = getPlainAst(subject, arguments.inFilePath, STRICT)
  if not plainAst then
    return nil, err or 'Error getting plain AST'
  end

  local typecheckedAst: {any: any}?, err: string? = getPlainAst(subject, arguments.inFilePath, STRICT)
  if not typecheckedAst then
    return nil, err or 'Error getting plain AST (typechecked)'
  end
  local typecheckMessages: { {'tag': string, 'msg': string, 'l': number, 'c': number} } = tlchecker.typecheck(typecheckedAst, subject, arguments.inFilePath, STRICT, INTEGER)
  if #typecheckMessages > 0 then
    local errorMessages: {string|number} = {}
    for k, v in pairs(typecheckMessages) do
      local msg = string.format('ERR: %s: %s', k, pretty.write(v))
      table.insert(errorMessages, #errorMessages + 1, msg)
    end
    return nil, table.concat(errorMessages, '\n')
  end

  local moduleName: string = getModuleName(arguments.outFilePath) or ''
  if #moduleName == 0 then
    return nil, 'Could not infer the module name.'
  end
  local generator: ProgramGenerator = getGenerator(arguments.outFilePath) or EmptyGenerator

  local ok, codeOrErr = pcall(generator.process, arguments.luaModuleName, moduleName, plainAst, typecheckedAst)
  if ok then
    setContents(codeOrErr, arguments.outFilePath)
  else
    return nil, string.format('Could not generate the code: %s', codeOrErr)
  end

  return true
end

local function parseArguments(args: {string}): (boolean)?
  local arguments, errMsg = getProgramArguments(args)

  if arguments then
    return runArguments(arguments)
  else
    return nil, errMsg
  end
end

return {
  parseArguments = parseArguments
}

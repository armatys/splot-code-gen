local dir = require 'dir'.dir
local io = require 'io'
local java = require 'java'
local lpeg = require 'lpeg'
local math = require 'math'
local os = require 'os'
local string = require 'string'
local table = require 'table'
local tlparser = require 'typedlua.tlparser'
local tlchecker = require 'typedlua.tlchecker'

local STRICT = false

local interface ProgramGenerator
  name: string
  process: (string, string, {any: any}, {any: any}) -> (string)
end

local interface ProgramArgs
  inFilePath: string
  outFilePath: string
  luaModuleName: string
end

local function writeError(message: string)
  local oldStdOut = io.output()
  io.output(io.stderr)
  io.write(message .. '\n')
  io.output(oldStdOut)
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

local function getProgramArguments(args: {string}): (ProgramArgs?, string?)
  if #args ~= 3 then
    return nil, 'usage: [input_file] [lua_module_name] [output_file]'
  end
  local inFilePath = args[1] or ''
  local luaModuleName = args[2] or ''
  local outFilePath = args[3] or ''
  return {inFilePath=inFilePath, outFilePath=outFilePath, luaModuleName=luaModuleName}, nil
end

local function getGenerator(outFilePath: string): ProgramGenerator?
  if outFilePath:match('.*%.swift$') then
    return nil -- TODO
  elseif outFilePath:match('.*%.java$') then
    return java
  else
    return nil
  end
end

local function getPlainAst(subject: string, inFilePath: string, strict: boolean): {any: any}
  local subject: string = getContents(inFilePath)
  local plainAst: {any: any}?, errorMessage: string? = tlparser.parse(subject, inFilePath, strict)
  if plainAst then
    return plainAst
  else
    writeError(string.format('Could not parse AST: %s', errorMessage))
    os.exit(1)
  end
end

local function runArguments(arguments: ProgramArgs)
  local subject: string = getContents(arguments.inFilePath)
  local plainAst: {any: any} = getPlainAst(subject, arguments.inFilePath, STRICT)
  local typecheckedAst: {any: any} = getPlainAst(subject, arguments.inFilePath, STRICT)
  local typecheckMessages: { {'tag': string, 'msg': string, 'l': number, 'c': number} } = tlchecker.typecheck(typecheckedAst, subject, STRICT)
  if #typecheckMessages > 0 then
    for k, v in pairs(typecheckMessages) do
      writeError(string.format('ERR: %s: %s', k, dir(v)))
    end
    os.exit(1)
  end

  local moduleName: string? = getModuleName(arguments.outFilePath)
  local generator: ProgramGenerator? = getGenerator(arguments.outFilePath)
  if generator and moduleName then
    local ok, codeOrErr = pcall(generator.process, arguments.luaModuleName, moduleName, plainAst, typecheckedAst)
    if ok then
      setContents(codeOrErr, arguments.outFilePath)
    else
      writeError(string.format('Could not generate the code: %s', codeOrErr))
      os.exit(1)
    end
  else
    if not generator then
      writeError('Could not infer the generator from the target file extension (java or swift).')
    elseif not moduleName then
      writeError('Could not infer the module name.')
    end
    os.exit(1)
  end
end

local function main()
  local arguments, errMsg = getProgramArguments(arg)
  if arguments then
    runArguments(arguments)
  else
    writeError(errMsg)
    os.exit(1)
  end
end

main()

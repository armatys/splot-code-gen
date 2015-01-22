local cli = require 'cli'
local io = require 'io'
local os = require 'os'


local function writeError(message: string)
  local oldStdOut = io.output()
  io.output(io.stderr)
  io.write(message)
  io.output(oldStdOut)
end

local function main()
  local ok, errMsg = cli.parseArguments(arg)
  if errMsg then
    writeError(errMsg)
    os.exit(1)
  end
end

main()

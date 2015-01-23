local cli = require 'cli'
local os = require 'os'

local tmpDirPath = '/tmp/splot-code-gen-tests/'
os.execute("mkdir -p " .. tmpDirPath)

local function getTmpFile(filename)
  return tmpDirPath .. filename
end

describe('Test CLI', function()
  it('Should fail because an input file does not exist', function()
    assert.has_error(function()
      cli.parseArguments({'fixtures/non_existent_file.tl', 'fixture0', getTmpFile('Fixture0.java')})
    end)
  end)

  it('Should not generate fixture1 (because it has a type error)', function()
    local ok, errMsg = cli.parseArguments({'fixtures/fixture1.tl', 'fixture1', getTmpFile('Fixture1.java')})
    assert.is.not_true(ok)
  end)

  it('Generates fixture2', function()
    local ok, errMsg = cli.parseArguments({'fixtures/fixture2.tl', 'fixture2', getTmpFile('Fixture2.java')})
    assert.is_true(ok)
  end)

  it('Generates arrays', function()
    local ok, errMsg = cli.parseArguments({'fixtures/arrays.tl', 'arrays', getTmpFile('Arrays.java')})
    assert.is_true(ok)
  end)

  it('Generates interfaces', function()
    local ok, errMsg = cli.parseArguments({'fixtures/interfaces.tl', 'interfaces', getTmpFile('Interfaces.java')})
    assert.is_true(ok)
  end)
end)

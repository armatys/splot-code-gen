local cli = require 'cli'
local os = require 'os'

local tmpDirPath = '/tmp/splot-code-gen-tests/'
os.execute("mkdir -p " .. tmpDirPath)

local function getTmpFile(filename)
  return tmpDirPath .. filename
end

local function testFixture(fixtureName, outFileName, printErrors)
  if type(printErrors) == 'nil' then
    printErrors = true
  end
  local ok, errMsg = cli.parseArguments({'fixtures/' .. fixtureName .. '.tl', fixtureName, getTmpFile(outFileName)})
  if not ok and printErrors then
    print(errMsg)
  end
  assert.is_true(ok)
end

describe('Test CLI', function()
  it('Should fail because an input file does not exist', function()
    assert.has_error(function()
      testFixture('non_existent_file', 'Fixture0.java')
    end)
  end)

  it('Should not generate fixture1 (because it has a type error)', function()
    assert.has_error(function()
      testFixture('fixture1', 'Fixture1.java', false)
    end)
  end)

  it('Generates fixture2', function()
    testFixture('fixture2', 'Fixture2.java')
  end)

  it('Generates fixture3', function()
    testFixture('fixture3', 'Fixture3.java')
  end)

  it('Generates arrays', function()
    testFixture('arrays', 'Arrays.java')
  end)

  it('Generates interfaces', function()
    testFixture('interfaces', 'Interfaces.java')
  end)
end)

local cli = require 'cli'
local os = require 'os'

local tmpDirPath = '/tmp/splot-code-gen-tests/'
os.execute("mkdir -p " .. tmpDirPath)

local function getTmpFile(filename)
  return tmpDirPath .. filename
end

local function testFixture(fixtureName, outFileName)
  local ok, errMsg = cli.parseArguments({'fixtures/' .. fixtureName .. '.tl', fixtureName, getTmpFile(outFileName)})
  assert.is_true(ok)
  if not ok then
    print(errMsg)
  end
end

describe('Test CLI', function()
  it('Should fail because an input file does not exist', function()
    assert.has_error(function()
      testFixture('non_existent_file', 'Fixture0.java')
    end)
  end)

  it('Should not generate fixture1 (because it has a type error)', function()
    assert.has_error(function()
      testFixture('fixture1', 'Fixture1.java')
    end)
  end)

  it('Generates fixture2', function()
    testFixture('fixture2', 'Fixture2.java')
  end)

  it('Generates arrays', function()
    testFixture('arrays', 'Arrays.java')
  end)

  it('Generates interfaces', function()
    testFixture('interfaces', 'Interfaces.java')
  end)
end)

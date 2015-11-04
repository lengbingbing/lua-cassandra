local Buffer = require "cassandra.buffer"

describe("Buffer", function()
  local FIXTURES = {
    byte = {1, 2, 3},
    int = {0, 4200, -42},
    short = {0, 1, -1, 12, 13},
    --boolean = {true, false},
    string = {"hello world"},
    long_string = {string.rep("blob", 1000), ""},
    inet = {
      "127.0.0.1", "0.0.0.1", "8.8.8.8",
      "2001:0db8:85a3:0042:1000:8a2e:0370:7334",
      "2001:0db8:0000:0000:0000:0000:0000:0001"
    },
    string_map = {
      {hello = "world"},
      {cql_version = "3.0.0", foo = "bar"}
    },
  }

  for fixture_type, fixture_values in pairs(FIXTURES) do
    it("["..fixture_type.."] should be bufferable", function()
      for _, fixture in ipairs(fixture_values) do
        local writer = Buffer(3)
        writer["write_"..fixture_type](writer, fixture)
        local bytes = writer:dump()

        local reader = Buffer(3, bytes) -- protocol v3
        local decoded = reader["read_"..fixture_type](reader)

        if type(fixture) == "table" then
          assert.same(fixture, decoded)
        else
          assert.equal(fixture, decoded)
        end
      end
    end)
  end

  it("should accumulate values", function()
    local writer = Buffer(3) -- protocol v3
    writer:write_byte(2)
    writer:write_int(128)
    writer:write_string("hello world")

    local reader = Buffer.from_buffer(writer)
    assert.equal(2, reader:read_byte())
    assert.equal(128, reader:read_int())
    assert.equal("hello world", reader:read_string())
  end)

  describe("inet", function()
    local fixtures = {
      ["2001:0db8:85a3:0042:1000:8a2e:0370:7334"] = "2001:0db8:85a3:0042:1000:8a2e:0370:7334",
      ["2001:0db8:0000:0000:0000:0000:0000:0001"] = "2001:db8::1",
      ["2001:0db8:85a3:0000:0000:0000:0000:0010"] = "2001:db8:85a3::10",
      ["2001:0db8:85a3:0000:0000:0000:0000:0100"] = "2001:db8:85a3::100",
      ["0000:0000:0000:0000:0000:0000:0000:0001"] = "::1",
      ["0000:0000:0000:0000:0000:0000:0000:0000"] = "::"
    }

    it("should shorten ipv6 addresses", function()
      for expected_ip, fixture_ip in pairs(fixtures) do
        local buffer = Buffer(3)
        buffer:write_inet(fixture_ip)
        buffer.pos = 1

        assert.equal(expected_ip, buffer:read_inet())
      end
    end)
  end)
end)

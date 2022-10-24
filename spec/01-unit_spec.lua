local PLUGIN_NAME = "aws-cost-aggregator"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end

describe(PLUGIN_NAME .. ": (schema)", function()
  
  it("configuration with no values is rejected", function()
    local ok, err = validate({})

    assert.equal(type(ok), "nil")
    assert.equal(type(err), "table")
  end)

  it("configuration with example values is accepted", function()
    local ok, err = validate({
      aws_key = "AKIAIOSFODNN7EXAMPLE",
      aws_secret = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      aws_region = "us-east-1",
      show_raw_error_in_http = false
    })

    assert.is_truthy(ok)
    assert.equal(type(err), "nil")
  end)

  it("configuration without secret is rejected", function()
    local ok, err = validate({
      aws_key = "AKIAIOSFODNN7EXAMPLE",
      aws_region = "us-east-1",
      show_raw_error_in_http = false
    })

    assert.equal(type(ok), "nil")
    assert.equal(type(err), "table")
  end)

end)

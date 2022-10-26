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
end)

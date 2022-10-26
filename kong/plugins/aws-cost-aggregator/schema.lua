local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "aws-cost-aggregator"
local ENCRYPT_STRING_OPTS = { type = "string", encrypted = true }

return {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    { config = {
      type = "record",
      fields = {},
    } }
  }
}
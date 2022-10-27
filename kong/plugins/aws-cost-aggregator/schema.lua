local typedefs = require "kong.db.schema.typedefs"
local PLUGIN_NAME = "aws-cost-aggregator"

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
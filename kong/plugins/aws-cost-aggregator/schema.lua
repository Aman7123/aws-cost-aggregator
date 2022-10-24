local typedefs = require "kong.db.schema.typedefs"
local PLUGIN_NAME = "aws-cost-aggregator"
local REQUIRED_STRING_OPTS = {type = "string", required = true}

return {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { config = {
      type = "record",
      fields = {
        {aws_key    = REQUIRED_STRING_OPTS},
        {aws_secret = REQUIRED_STRING_OPTS},
        {aws_region = REQUIRED_STRING_OPTS},
        {show_raw_error_in_http = {type = "boolean", default = false}}
      },
    } }
  },
  entity_checks = {
    { mutually_required = { "config.aws_key", "config.aws_secret" } }
  }
}
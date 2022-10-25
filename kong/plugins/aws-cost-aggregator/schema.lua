local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "aws-cost-aggregator"
local ENCRYPT_STRING_OPTS = { type = "string", encrypted = true }

return {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { config = {
      type = "record",
      fields = {
        {aws_key    = ENCRYPT_STRING_OPTS},
        {aws_secret = ENCRYPT_STRING_OPTS},
        {aws_region = typedefs.host },
        {aws_assume_role_arn = ENCRYPT_STRING_OPTS},
        {aws_role_session_name = { type = "string", default = "kong" }},
        {show_raw_error_in_http = { type = "boolean", default = false }}
      },
    } }
  },
  entity_checks = {
    { mutually_required = { "config.aws_key", "config.aws_secret" } }
  }
}
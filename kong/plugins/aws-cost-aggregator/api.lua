local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local get_config_from_env = require("kong.plugins."..PLUGIN_NAME..".helpers").get_config_from_env

return {
  ["/ag-pop"] = {
    GET = function()
      local config = get_config_from_env()
      local res, err = exporter.log(config)
      if err then
        kong.log.err("error")
        log_error(true, err, true)
      end
      return kong.response.exit(200, { message = "completed" })
    end,
  }
}
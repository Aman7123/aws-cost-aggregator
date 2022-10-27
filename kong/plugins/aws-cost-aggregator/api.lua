local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local log_debug = require("kong.plugins."..PLUGIN_NAME..".helpers").log_debug
local cjson = require("cjson.safe")
local fmt = string.format

return {
  ["/ag-pop"] = {
    GET = function()
      local res, err = exporter.log()
      if err then
        kong.log.err("error")
        log_error(true, err, true)
      end
      return kong.response.exit(200, { message = "completed" })
    end,
  }
}
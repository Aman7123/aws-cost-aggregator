local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")

return {
  ["/aws"] = {
    GET = function()
      exporter.collect()
    end,
  }
}
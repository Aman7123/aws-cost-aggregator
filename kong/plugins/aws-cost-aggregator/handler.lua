-- load the base plugin object and create a subclass
local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")
local get_days_in_month = require("kong.plugins."..PLUGIN_NAME..".helpers").get_days_in_month
local pad_date_integer = require("kong.plugins."..PLUGIN_NAME..".helpers").pad_date_integer
local throw_kong_exception = require("kong.plugins."..PLUGIN_NAME..".helpers").throw_kong_exception
local aws_request = require("kong.plugins."..PLUGIN_NAME..".aws-utils").aws_request
local cost_explorer_opts = require("kong.plugins."..PLUGIN_NAME..".aws-utils").cost_explorer_opts
local cjson = require "cjson.safe"
local fmt = string.format
local COST_EXPLORER_FUNCTION = "AWSInsightsIndexService.GetCostAndUsage"
local DATE_FORMAT = "%s-%s-%s"

exporter.init()

-- set the plugin priority, which determines plugin execution order
local AWSCostAggregator = {}
AWSCostAggregator.PRIORITY = 751
AWSCostAggregator.VERSION = "1.0.0"

function AWSCostAggregator:init_worker()
  exporter.init_worker()
end

-- runs in the 'access_by_lua_block'
function AWSCostAggregator:access(config)

  -- 
  -- build aws request
  local now = os.date ("*t")
  local awsRequestBody = {
    Granularity = "MONTHLY",
    TimePeriod = {
      End = fmt(DATE_FORMAT, now.year, pad_date_integer(now.month), get_days_in_month(now.month, now.year)),
      Start = fmt(DATE_FORMAT, (now.year - 1), pad_date_integer(now.month), "01")
    },
    Metrics = {
      "BlendedCost",
      "UnblendedCost"
    }
  }

  -- 
  -- connect to aws
  local awsRequestSignature, err = cost_explorer_opts(config, awsRequestBody, COST_EXPLORER_FUNCTION)
  if not awsRequestSignature then
    throw_kong_exception(config.show_raw_error_in_http, err)
  end

  -- 
  -- format before using in active body
  kong.log.info(cjson.encode(awsRequestSignature))

  -- 
  -- query aws
  local response, err = aws_request(awsRequestSignature)
  if not response then
    throw_kong_exception(config.show_raw_error_in_http, (err or response.body))
  end

  -- 
  -- build response
  kong.response.exit(response.status, response.body, response.headers)
end

-- function AWSCostAggregator:log()
--   local message = kong.log
--   exporter.log()
-- end

-- return our plugin object
return AWSCostAggregator
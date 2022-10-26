local PLUGIN_NAME = "aws-cost-aggregator"
local get_days_in_month = require("kong.plugins."..PLUGIN_NAME..".helpers").get_days_in_month
local pad_date_integer = require("kong.plugins."..PLUGIN_NAME..".helpers").pad_date_integer
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local aws_request = require("kong.plugins."..PLUGIN_NAME..".aws-utils").aws_request
local cost_explorer_opts = require("kong.plugins."..PLUGIN_NAME..".aws-utils").cost_explorer_opts
local cjson = require("cjson.safe")
local fmt = string.format

local _M = {}

function _M.monthly_cost_last_12_months(config)
  local COST_EXPLORER_FUNCTION = "AWSInsightsIndexService.GetCostAndUsage"
  local DATE_FORMAT = "%s-%s-%s"

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
    log_error(true, err, false)
    return nil, err
  end

  -- 
  -- query aws
  local response, err = aws_request(awsRequestSignature)
  if not response then
    log_error(true, (err or response.body), false)
    return nil, err
  end

  return cjson.decode(response.body), nil
end

return _M
local PLUGIN_NAME = "aws-cost-aggregator"
local get_days_in_month = require("kong.plugins."..PLUGIN_NAME..".helpers").get_days_in_month
local pad_date_integer = require("kong.plugins."..PLUGIN_NAME..".helpers").pad_date_integer
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local do_aws = require("kong.plugins."..PLUGIN_NAME..".aws-utils").do_query
local fmt = string.format

local COST_EXPLORER_FUNCTION = "AWSInsightsIndexService.GetCostAndUsage"
local DATE_FORMAT = "%s-%s-%s"

local _M = {}

-- This function gets the last 12 months of cost
function _M.monthly_cost_last_12_months(config)
  -- build the monhtly cost query 
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

  if type(config) ~= nil then
    if config.ag_tags ~= nil then
      for k, v in pairs(config.ag_tags) do
        local filter_obj = {
          Tags = {
            Key = k,
            Values = v
          }
        }

        awsRequestBody["Filter"] = {}
        awsRequestBody["Filter"] = filter_obj
      end
    end
  end

  local aws_res, err = do_aws(config, awsRequestBody, COST_EXPLORER_FUNCTION)
  if err then
    kong.log.err("error")
    return nil, err
  end
  return aws_res
end

-- This function gets the last 30 days of cost
function _M.monthly_cost_last_30_days(config)
  -- build the monhtly cost query 
  local now = os.date ("*t")
  local awsRequestBody = {
    Granularity = "DAILY",
    TimePeriod = {
      End = fmt(DATE_FORMAT, now.year, pad_date_integer(now.month), get_days_in_month(now.month, now.year)),
      Start = fmt(DATE_FORMAT, now.year, pad_date_integer(now.month), "01")
    },
    Metrics = {
      "BlendedCost",
      "UnblendedCost"
    }
  }

  if type(config) ~= nil then
    if config.ag_tags ~= nil then
      for k, v in pairs(config.ag_tags) do
        local filter_obj = {
          Tags = {
            Key = k,
            Values = v
          }
        }

        awsRequestBody["Filter"] = {}
        awsRequestBody["Filter"] = filter_obj
      end
    end
  end

  local aws_res, err = do_aws(config, awsRequestBody, COST_EXPLORER_FUNCTION)
  if err then
    kong.log.err("error")
    return nil, err
  end
  return aws_res
end

return _M
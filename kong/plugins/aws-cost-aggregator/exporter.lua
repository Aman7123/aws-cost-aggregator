local PLUGIN_NAME = "aws-cost-aggregator"
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local log_debug = require("kong.plugins."..PLUGIN_NAME..".helpers").log_debug
local aws_monthly = require("kong.plugins."..PLUGIN_NAME..".costexplorer-utils").monthly_cost_last_12_months
local exporter = require('kong.plugins.prometheus.exporter')
local cjson = require("cjson.safe")
local fmt = string.format

local COST_MSG = "\n# HELP Breakdown over the last 12 months and values have been rounded to the nearest cent,"
local AWS_COST_ARTICLE = "https://aws.amazon.com/blogs/aws-cloud-financial-management/understanding-your-aws-cost-datasets-a-cheat-sheet/"
local CUSTOM_OWNERSHIP_MSG = fmt("\n# MODIFIED this data was added by %s", PLUGIN_NAME)
local CUSTOM_LINK_MSG = fmt("\n# view this link for blended vs unblended @ %s", AWS_COST_ARTICLE)
local metrics = {}
-- prometheus.lua instance
local prometheus = exporter.get_prometheus()

local function init()
  local shm = "prometheus_metrics"
  if not ngx.shared.prometheus_metrics then
    kong.log.err("prometheus: ngx shared dict 'prometheus_metrics' not found")
    return
  end

  local blended_annotation =  CUSTOM_OWNERSHIP_MSG .. COST_MSG .. CUSTOM_LINK_MSG

  -- global metrics
  metrics.blended_costs = prometheus:gauge("aws_monthly_blended_cost",
                                            blended_annotation,
                                            {"start", "end", "unit", "estimated"},
                                            prometheus.LOCAL_STORAGE)
  metrics.unblended_costs = prometheus:gauge("aws_monthly_unblended_cost",
                                            blended_annotation,
                                            {"start", "end", "unit", "estimated"},
                                            prometheus.LOCAL_STORAGE)
end

local function log(config)
  -- We rule our booleans as the config value,
  -- this is because during a call from the timer the
  -- first argument is a premature value
  -- we want that value to be nil
  if type(config) == "boolean" then
    config = nil
  end

  log_debug("running exporter re-pop")

  if not metrics then
    local msg = "prometheus: can not log metrics because of an initialization "
    .. "error, please make sure that you've declared "
    .. "'prometheus_metrics' shared dict in your nginx template"
    return nil, msg
  end

  -- actual JSON parsing here
  local aws_monthly_response, err = aws_monthly(config)
  if not aws_monthly_response then
    return nil, err
  end

  local monthly_results_by_time = aws_monthly_response.ResultsByTime
  for _,monthly_result in ipairs(monthly_results_by_time) do
    local labels_table_blended = {0, 0, 0, 0}
    local labels_table_unblended = {0, 0, 0, 0}

    -- gather estimated label
    labels_table_blended[4] = monthly_result.Estimated
    labels_table_unblended[4] = monthly_result.Estimated

    -- gather dates for this individule monthly result
    local time_period = monthly_result.TimePeriod
    labels_table_blended[1] = time_period.Start
    labels_table_blended[2] = time_period.End
    labels_table_unblended[1] = time_period.Start
    labels_table_unblended[2] = time_period.End

    -- gather the total array
    local total_array = monthly_result.Total

    -- gather and complete blended cost
    local blended_cost = total_array.BlendedCost
    labels_table_blended[3] = blended_cost.Unit
    metrics.blended_costs:set(blended_cost.Amount, labels_table_blended)

    -- gather and complete unblended cost
    local unblended_cost = total_array.UnblendedCost
    labels_table_unblended[3] = unblended_cost.Unit
    metrics.unblended_costs:set(unblended_cost.Amount, labels_table_unblended)
  end
end

return {
  init = init,
  log  = log,
}
local PLUGIN_NAME = "aws-cost-aggregator"
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local log_debug = require("kong.plugins."..PLUGIN_NAME..".helpers").log_debug
local aws_monthly = require("kong.plugins."..PLUGIN_NAME..".costexplorer-utils").monthly_cost_last_12_months
local aws_daily = require("kong.plugins."..PLUGIN_NAME..".costexplorer-utils").monthly_cost_last_30_days
local exporter = require('kong.plugins.prometheus.exporter')
local cjson = require("cjson.safe")
local fmt = string.format

local MONTHLY_COST_MSG = "\n# HELP Breakdown over the last 12 months and values have been rounded to the nearest cent,"
local DAILY_COST_MSG = "\n# HELP Breakdown over the last 30 days and values have been rounded to the nearest cent,"
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

  local monthly_blended_annotation = fmt("%s%s%s", CUSTOM_OWNERSHIP_MSG, MONTHLY_COST_MSG, CUSTOM_LINK_MSG)
  local daily_blended_annotation = fmt("%s%s%s", CUSTOM_OWNERSHIP_MSG, DAILY_COST_MSG, CUSTOM_LINK_MSG)

  -- monthly metrics
  metrics.monthly_blended_costs = prometheus:gauge("aws_monthly_blended_cost",
                                                  monthly_blended_annotation,
                                                  {"start", "end", "unit", "estimated"},
                                                  prometheus.LOCAL_STORAGE)
  metrics.monthly_unblended_costs = prometheus:gauge("aws_monthly_unblended_cost",
                                                    monthly_blended_annotation,
                                                    {"start", "end", "unit", "estimated"},
                                                    prometheus.LOCAL_STORAGE)

  -- daily metrics
  metrics.daily_blended_costs = prometheus:gauge("aws_daily_blended_cost",
                                                daily_blended_annotation,
                                                {"start", "end", "unit", "estimated"},
                                                prometheus.LOCAL_STORAGE)
  metrics.daily_unblended_costs = prometheus:gauge("aws_daily_unblended_cost",
                                                daily_blended_annotation,
                                                {"start", "end", "unit", "estimated"},
                                                prometheus.LOCAL_STORAGE)
end

local function log(config, config_from_timer)
  -- We rule our booleans as the config value,
  -- this is because during a call from the timer the
  -- first argument is a premature value
  -- we want that value to be nil
  log_debug(fmt("running exporter re-pop with config %s", cjson.encode(config)))
  if type(config) == "boolean" then
    config = config_from_timer
  end

  log_debug(fmt("running exporter re-pop with config %s", cjson.encode(config)))
  log_debug(fmt("running exporter re-pop with config_from_timer %s", cjson.encode(config_from_timer)))

  if not metrics then
    local msg = "prometheus: can not log metrics because of an initialization "
    .. "error, please make sure that you've declared "
    .. "'prometheus_metrics' shared dict in your nginx template"
    return nil, msg
  end

  -- get monthly JSON data
  local aws_monthly_response, err = aws_monthly(config)
  if err then
    kong.log.err("error")
    return nil, err
  end

  -- Monthly
  log_debug(fmt("Obtained the monthly response from AWS: %s", cjson.encode(aws_monthly_response)))
  local monthly_results_by_time = aws_monthly_response.ResultsByTime
  for _,monthly_result in ipairs(monthly_results_by_time) do
    -- The monthly_result parsed out above is an object, this object contains the data for the 3 functions below
    -- { "Total": {
    --     "BlendedCost": { "Amount": "0",
    --                      "Unit": "USD"},
    --     "UnblendedCost": { "Amount": "0",
    --                        "Unit": "USD"}
    --   },
    --   "Estimated": false,
    --   "TimePeriod": { "Start": "2021-10-01",
    --                   "End": "2021-11-01"
    --   },
    --   "Groups": {}
    -- }
    local labels_table_blended = {0, 0, 0, 0}
    local labels_table_unblended = {0, 0, 0, 0}

    -- Estimated
    -- This field is a boolean which explains if the value is activly being updated (current month)
    -- Here were essentially transfering that boolean into the table
    labels_table_blended[4] = monthly_result.Estimated
    labels_table_unblended[4] = monthly_result.Estimated

    -- TimePeriod
    -- Sets the start ad end times in the tables above
    local time_period = monthly_result.TimePeriod
    labels_table_blended[1] = time_period.Start
    labels_table_blended[2] = time_period.End
    labels_table_unblended[1] = time_period.Start
    labels_table_unblended[2] = time_period.End

    -- Total
    local total_array = monthly_result.Total
    -- BlendedCost
    local blended_cost = total_array.BlendedCost
    labels_table_blended[3] = blended_cost.Unit
    metrics.monthly_blended_costs:set(blended_cost.Amount, labels_table_blended)
    -- UnblendedCost
    local unblended_cost = total_array.UnblendedCost
    labels_table_unblended[3] = unblended_cost.Unit
    metrics.monthly_unblended_costs:set(unblended_cost.Amount, labels_table_unblended)
  end


  -- get daily JSON data
  local aws_daily_response, err = aws_daily(config)
  if err then
    kong.log.err("error")
    return nil, err
  end

  -- Daily
  log_debug(fmt("Obtained the daily response from AWS: %s", cjson.encode(aws_daily_response)))
  local daily_results_by_time = aws_daily_response.ResultsByTime
  for _,daily_result in ipairs(daily_results_by_time) do
    -- The daily_result parsed out above is an object, this object contains the data for the 3 functions below
    -- { "Total": {
    --     "BlendedCost": { "Amount": "0",
    --                      "Unit": "USD"},
    --     "UnblendedCost": { "Amount": "0",
    --                        "Unit": "USD"}
    --   },
    --   "Estimated": false,
    --   "TimePeriod": { "Start": "2021-10-01",
    --                   "End": "2021-11-01"
    --   },
    --   "Groups": {}
    -- }
    local labels_table_blended = {0, 0, 0, 0}
    local labels_table_unblended = {0, 0, 0, 0}

    -- Estimated
    -- This field is a boolean which explains if the value is activly being updated (current month)
    -- Here were essentially transfering that boolean into the table
    labels_table_blended[4] = daily_result.Estimated
    labels_table_unblended[4] = daily_result.Estimated

    -- TimePeriod
    -- Sets the start ad end times in the tables above
    local time_period = daily_result.TimePeriod
    labels_table_blended[1] = time_period.Start
    labels_table_blended[2] = time_period.End
    labels_table_unblended[1] = time_period.Start
    labels_table_unblended[2] = time_period.End

    -- Total
    local total_array = daily_result.Total
    -- BlendedCost
    local blended_cost = total_array.BlendedCost
    labels_table_blended[3] = blended_cost.Unit
    metrics.daily_blended_costs:set(blended_cost.Amount, labels_table_blended)
    -- UnblendedCost
    local unblended_cost = total_array.UnblendedCost
    labels_table_unblended[3] = unblended_cost.Unit
    metrics.daily_unblended_costs:set(unblended_cost.Amount, labels_table_unblended)
  end
end

return {
  init = init,
  log  = log,
}
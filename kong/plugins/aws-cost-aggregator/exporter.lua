local kong = kong
local ngx = ngx
local lower = string.lower
local concat = table.concat
local cjson = require "cjson.safe"

local PLUGIN_NAME = "aws-cost-aggregator"
local AWS_COST_ARTICLE = "https://aws.amazon.com/blogs/aws-cloud-financial-management/understanding-your-aws-cost-datasets-a-cheat-sheet/"
local metrics = {}
-- prometheus.lua instance
local prometheus

local function init()
  local shm = "prometheus_metrics"
  if not ngx.shared.prometheus_metrics then
    kong.log.err("prometheus: ngx shared dict 'prometheus_metrics' not found")
    return
  end

  prometheus = require("kong.plugins."..PLUGIN_NAME..".prometheus").init(shm, "aws_")

  -- global metrics
  metrics.blended_costs = prometheus:gauge("monthly_blended_cost",
                                            "Breakdown over the last 12 months and values have been rounded to the nearest cent, " ..
                                            "more info on this topic start at an article like " .. AWS_COST_ARTICLE,
                                            -- {"start", "end", "unit", "estimated"},
                                            nil,
                                            prometheus.LOCAL_STORAGE)
  metrics.unblended_costs = prometheus:gauge("monthly_unblended_cost",
                                            "Breakdown over the last 12 months and values have been rounded to the nearest cent, " ..
                                            "more info on this topic start at an article like " .. AWS_COST_ARTICLE,
                                            -- {"start", "end", "unit", "estimated"},
                                            nil,
                                            prometheus.LOCAL_STORAGE)
end

local function init_worker()
  prometheus:init_worker()
end


local function metric_data(write_fn)
  kong.log.info("type of write_fn: ", type(write_fn))
  kong.log.info("type of ngx.shared.prometheus_metrics: ", type(ngx.shared.prometheus_metrics))
  kong.log.info(cjson.encode(write_fn))
  kong.log.info(cjson.encode(ngx.shared.prometheus_metrics))
  -- for a,b in ipairs(ngx.shared.prometheus_metrics) do
  --   kong.info.log("a=", a, "b=", b)
  -- end
  if not prometheus or not metrics then
    kong.log.err("prometheus: plugin is not initialized, please make sure ",
                 " 'prometheus_metrics' shared dict is present in nginx template")
    return kong.response.exit(500, { message = "An unexpected error occurred" })
  end

  metrics.blended_costs:set(1)
  metrics.unblended_costs:set(1)
  
  prometheus:metric_data(write_fn)
end

local function collect()
  ngx.header["Content-Type"] = "text/plain; charset=UTF-8"
  ngx.header["X-Test"] = "Hellow"

  metric_data()
end

return {
  init        = init,
  init_worker = init_worker,
  metric_data = metric_data,
  collect     = collect
}
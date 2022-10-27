local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local log_debug = require("kong.plugins."..PLUGIN_NAME..".helpers").log_debug
local get_config_from_env = require("kong.plugins."..PLUGIN_NAME..".helpers").get_config_from_env
local cjson = require("cjson.safe")
local fmt = string.format
local ngx_timer_at = ngx.timer.at
local ngx_timer_every = ngx.timer.every

-- init the unique labels in prometheus
exporter.init()

-- set the plugin priority, which determines plugin execution order
local AWSCostAggregator = {}
AWSCostAggregator.PRIORITY = 10
AWSCostAggregator.VERSION = "1.0.0"

-- runs in the 'init_worker_by_lua_block'
function AWSCostAggregator:init_worker()
  -- This below varibale is a lock to ensure only a single worker populates prometheus per kong deployment
  local lock_cache_key = fmt("%s:init_worker_lock", PLUGIN_NAME)
  -- Gather what type of node is spinning up
  local node_role = kong.configuration.role
  -- enable only execution in dp or traditional modes...
  -- this means in hybrid the metrics endpoint on CP is unchanged
  if (node_role == "data_plane" or node_role == "traditional") then
    local success = ngx.shared.kong_locks:add(lock_cache_key, true, 60)
    -- Success is true if the lock was created, false if it already existed
    if success then
      log_debug("running init_worker")
      log_debug(fmt("selected worker id %s for executing timers", ngx.worker.pid()))
      local config = get_config_from_env()
      log_debug(fmt("built config %s", cjson.encode(res)))
      -- Create a pointer to the function for use within the timers
      -- I had problems assigning this `exporter.log` directly to the timer
      local run_function = exporter.log
      -- Initial created so our metrics are available ASAP
      local _, err = ngx_timer_at(0, run_function, config)
      if err then
        log_error(true, "Failed to start the nginx_timer_at")
      end
      -- Create this delayed monitor for watching every few minutes
      --                           5 minutes
      local _, err = ngx_timer_every(config.ag_update_frequency, run_function, config)
      if err then
        log_error(true, "Failed to start the nginx_timer_every")
      end
    end
  end
end

-- return our plugin object
return AWSCostAggregator
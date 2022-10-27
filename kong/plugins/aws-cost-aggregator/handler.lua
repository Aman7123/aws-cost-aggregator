local PLUGIN_NAME = "aws-cost-aggregator"
local exporter = require("kong.plugins."..PLUGIN_NAME..".exporter")
local log_error = require("kong.plugins."..PLUGIN_NAME..".helpers").log_error
local log_debug = require("kong.plugins."..PLUGIN_NAME..".helpers").log_debug
local cjson = require("cjson.safe")
local fmt = string.format
local ngx_timer_at = ngx.timer.at
local ngx_timer_every = ngx.timer.every

-- Register OS variables
local AWS_KEY = os.getenv("AWS_KEY")
local AWS_SECRET = os.getenv("AWS_SECRET")
local AWS_ASSUME_ROLE_ARN = os.getenv("AWS_ASSUME_ROLE_ARN")
local AWS_ROLE_SESSION_NAME do
  AWS_ROLE_SESSION_NAME = os.getenv("AWS_ROLE_SESSION_NAME") or "kong"
end
local AG_UPDATE_FREQUENCY do
  AG_UPDATE_FREQUENCY = tonumber(os.getenv("AG_UPDATE_FREQUENCY")) or 300
end
local AG_TAGS = os.getenv("AG_TAGS")

-- init the unique labels in prometheus
exporter.init()

-- set the plugin priority, which determines plugin execution order
local AWSCostAggregator = {}
AWSCostAggregator.PRIORITY = 10
AWSCostAggregator.VERSION = "1.0.0"

local function build_config_from_env()
  log_debug("running init_worker")
  log_debug(fmt("selected worker id %s for executing timers", ngx.worker.pid()))
  if AWS_KEY then
    log_debug("using AWS_KEY from env")
  end
  if AWS_SECRET then
    log_debug("using AWS_SECRET from env")
  end
  if AWS_ASSUME_ROLE_ARN then
    log_debug(fmt("using AWS_ASSUME_ROLE_ARN from env as %s", AWS_ASSUME_ROLE_ARN))
  end
  if AWS_ROLE_SESSION_NAME then
    log_debug(fmt("using AWS_ROLE_SESSION_NAME from env as %s", AWS_ROLE_SESSION_NAME))
  end
  if AG_UPDATE_FREQUENCY then
    log_debug(fmt("using AG_UPDATE_FREQUENCY from env as %s", AG_UPDATE_FREQUENCY))
  end
  if AG_TAGS then
    log_debug(fmt("using AG_TAGS from env as %s", cjson.encode(AG_TAGS)))
  end

  local res = {
    aws_key               = AWS_KEY,
    aws_secret            = AWS_SECRET,
    aws_assume_role_arn   = AWS_ASSUME_ROLE_ARN,
    aws_role_session_name = AWS_ROLE_SESSION_NAME,
    ag_tags               = AG_TAGS
  }

  log_debug(fmt("built config %s", cjson.encode(res)))

  return res
end

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
      local config = build_config_from_env()
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
      local _, err = ngx_timer_every(300, run_function, config)
      if err then
        log_error(true, "Failed to start the nginx_timer_every")
      end
    end
  end
end

-- return our plugin object
return AWSCostAggregator
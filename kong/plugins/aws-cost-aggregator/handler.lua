-- load the base plugin object and create a subclass
local PLUGIN_NAME = "aws-cost-aggregator"
local cjson = require "cjson.safe"
local aws_v4 = require "kong.plugins.aws-lambda.v4"
local http = require "resty.http"
local fmt = string.format
local GLOBAL_ERROR = [[There has been an issue with this request.
  The internal connection to AWS could not be established.
  If this problem persists please contact an admin!]]
local COST_EXPLORER_FUNCTION = "AWSInsightsIndexService.GetCostAndUsage"
local AWS_SERVICE = "ce"
local COST_EXPLORER_URL = fmt("%s.%s", AWS_SERVICE, "%s.amazonaws.com")

-- set the plugin priority, which determines plugin execution order
local AWSCostAggregator = {}
AWSCostAggregator.PRIORITY = 751
AWSCostAggregator.VERSION = "1.0.0"

local function do_error(do_debug, error)
  local formatGlobalError = GLOBAL_ERROR:gsub("\n ", "")
  local baseErrorMsg = {
    message = formatGlobalError
  }

  if do_debug then
    baseErrorMsg["plugin"] = PLUGIN_NAME
    baseErrorMsg["error"] = tostring(error)
  end

  kong.log.err("[", PLUGIN_NAME, "] ", cjson.encode(err))
  
  return kong.response.exit(500, baseErrorMsg)
end

-- runs in the 'access_by_lua_block'
function AWSCostAggregator:access(config)

  -- 
  -- build aws request
  local now = os.date ("*t")
  local awsRequestBody = {
    Granularity = "MONTHLY",
    TimePeriod = {
      End = fmt("%s/%s/%s", now.year, now.month, now.day),
      Start = fmt("%s/%s/%s", now.year, (now.month - 1), now.day)
    },
    Metrics = {
      "BlendedCost",
      "UnblendedCost",
      "UsageQuantity"
    }
  }
  local awsRequestBodyAsString = cjson.encode(awsRequestBody)

  -- 
  -- connect to aws
  local host = string.format(COST_EXPLORER_URL, config.aws_region)

  local requestSignatureOptions = {
    region = config.aws_region,
    service = "ce",
    method = "POST",
    headers = {
      ["X-Amz-Target"] = COST_EXPLORER_FUNCTION,
      ["Content-Type"] = "application/x-amz-json-1.1",
      ["Content-Length"] = tostring(#awsRequestBodyAsString)
    },
    body = awsRequestBodyAsString,
    host = host,
    port = 443,
    scheme = "https",
    path = "/",
    access_key = config.aws_key,
    secret_key = config.aws_secret,
  }

  local awsRequestSignature, err = aws_v4(requestSignatureOptions)
  if not awsRequestSignature then
    do_error(config.show_raw_error_in_http, err)
  end

  -- 
  -- format before using in active body
  -- awsRequestSignature.headers["Connection"] = "Keep-Alive"
  kong.log.info(cjson.encode(awsRequestSignature))

  -- 
  -- query aws
  local client = http.new()

  local awsRequestOpts =  {
    method = "POST",
    path = awsRequestSignature.url,
    body = awsRequestSignature.body,
    headers = awsRequestSignature.headers
  }

  local response, err = client:request_uri(awsRequestSignature.url, awsRequestOpts)
  client:close()

  if not response then
    do_error(config.show_raw_error_in_http, (err or response.body))
  end

  kong.response.exit(response.status, response.body, response.headers)
end

-- return our plugin object
return AWSCostAggregator
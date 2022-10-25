local http = require "resty.http"
local cjson = require "cjson.safe"
local aws_v4 = require "kong.plugins.aws-lambda.v4"
local fmt = string.format

local AWS_SERVICE = "ce"
local COST_EXPLORER_URL = fmt("%s.%s", AWS_SERVICE, "%s.amazonaws.com")
local IAM_CREDENTIALS_CACHE_KEY_PATTERN = "plugin.aws-lambda.iam_role_temp_creds.%s"
local AWS_REGION do
  AWS_REGION = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
end

local _M = {}

-- Function is from the [Kong AWS Lambda handler](https://github.com/Kong/kong-ee/blob/b8ff26d75c285d3f5f5ab2a3aaedbcdffaf5ace4/kong/plugins/aws-lambda/handler.lua#L28-L63)
-- @param aws_conf Table containing configutation params
local function fetch_aws_credentials(aws_conf)
  local fetch_metadata_credentials do
    local metadata_credentials_source = {
      require "kong.plugins.aws-lambda.iam-ecs-credentials",
      -- The EC2 one will always return `configured == true`, so must be the last!
      require "kong.plugins.aws-lambda.iam-ec2-credentials",
    }

    for _, credential_source in ipairs(metadata_credentials_source) do
      if credential_source.configured then
        fetch_metadata_credentials = credential_source.fetchCredentials
        break
      end
    end
  end

  if aws_conf.aws_assume_role_arn then
    local metadata_credentials, err = fetch_metadata_credentials()

    if err then
      return nil, err
    end

    local aws_sts_cred_source = require "kong.plugins.aws-lambda.iam-sts-credentials"
    return aws_sts_cred_source.fetch_assume_role_credentials(aws_conf.aws_region,
                                                             aws_conf.aws_assume_role_arn,
                                                             aws_conf.aws_role_session_name,
                                                             metadata_credentials.access_key,
                                                             metadata_credentials.secret_key,
                                                             metadata_credentials.session_token)

  else
    return fetch_metadata_credentials()
  end

end

-- This function generates a new http module and makes requests for AWS information
-- @param awsV4 the signature from the aws-lambda v4 module [more info here](https://github.com/Kong/kong/blob/master/kong/plugins/aws-lambda/v4.lua)
function _M.aws_request(awsV4)
  -- make new http
  local client = http.new()
  -- format new request
  local awsRequestOpts =  {
    method = "POST",
    path = awsV4.target,
    body = awsV4.body,
    headers = awsV4.headers
  }
  -- end connection
  return client:request_uri(awsV4.url, awsRequestOpts)
end

-- Generate new awsV4 options for CostExplorer
-- This is a standard process for any application who uses the AWS v4 API
-- All endpoints should be simmiliar just with different AWS_SERVICE below which plays into a full url generation
-- @params config The params from a Kong handler session
-- @params body A table or string
-- @params ce_function The value of the X-Amz-Target
function _M.cost_explorer_opts(config, body, ce_function)

  -- turn body into string if table, because we're nice
  local upstreamBodyAsString = body
  if type(body) == "table" then
    upstreamBodyAsString = cjson.encode(body)
  end

  -- some variables for this function only
  local region = config.aws_region or AWS_REGION
  if not region then
    return nil, "no region specified"
  end
  local host = string.format(COST_EXPLORER_URL, region)

  -- The builk of the inital config for AWS, needed for formatting by the v4 library
  local requestSignatureOptions = {
    region = region,
    service = AWS_SERVICE,
    method = "POST",
    headers = {
      ["X-Amz-Target"] = ce_function,
      ["Content-Type"] = "application/x-amz-json-1.1",
      ["Content-Length"] = tostring(#upstreamBodyAsString)
    },
    body = upstreamBodyAsString,
    host = host,
    port = 443,
    path = "/"
  }

  -- Code all below is for grabbing the aws role from the environment
  -- Code below wa grabbed from the AWS Lambda plugin [here](https://github.com/Kong/kong-ee/blob/b8ff26d75c285d3f5f5ab2a3aaedbcdffaf5ace4/kong/plugins/aws-lambda/handler.lua#L267-L294)
  local aws_conf = {
    aws_region = region,
    aws_assume_role_arn = config.aws_assume_role_arn,
    aws_role_session_name = config.aws_role_session_name,
  }

  if not config.aws_key then
    -- no credentials provided, so try the IAM metadata service
    local iam_role_cred_cache_key = fmt(IAM_CREDENTIALS_CACHE_KEY_PATTERN, config.aws_assume_role_arn or "default")
    local iam_role_credentials, err = kong.cache:get(
      iam_role_cred_cache_key,
      nil,
      fetch_aws_credentials,
      aws_conf
    )

    if not iam_role_credentials then
      local base = "no credentials could be found"
      if err then
        base = base .. ", " .. err
      end
      return nil, base
    end

    requestSignatureOptions.access_key = iam_role_credentials.access_key
    requestSignatureOptions.secret_key = iam_role_credentials.secret_key
    requestSignatureOptions.headers["X-Amz-Security-Token"] = iam_role_credentials.session_token

  else
    requestSignatureOptions.access_key = config.aws_key
    requestSignatureOptions.secret_key = config.aws_secret
  end

  -- Return the signed request
  return aws_v4(requestSignatureOptions)
end

return _M
local plugin_name = "aws-cost-aggregator"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "1.0.0"
local rockspec_revision = "1"

local github_account_name = "Aman7123"
local github_repo_name    = "kong-"..plugin_name
local git_checkout = package_version == "dev" and "master" or package_version


package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }
source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = git_checkout,
}


description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  homepage = "https://"..github_account_name..".github.io/"..github_repo_name,
  license = "Apache 2.0",
}


dependencies = {}


build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..plugin_name..".handler"] = "kong/plugins/"..plugin_name.."/handler.lua",
    ["kong.plugins."..plugin_name..".schema"] = "kong/plugins/"..plugin_name.."/schema.lua",
    ["kong.plugins."..plugin_name..".helpers"] = "kong/plugins/"..plugin_name.."/helpers.lua",
    ["kong.plugins."..plugin_name..".aws-utils"] = "kong/plugins/"..plugin_name.."/aws-utils.lua",
    ["kong.plugins."..plugin_name..".prometheus"] = "kong/plugins/"..plugin_name.."/prometheus.lua",
    ["kong.plugins."..plugin_name..".exporter"] = "kong/plugins/"..plugin_name.."/exporter.lua",
    ["kong.plugins."..plugin_name..".api"] = "kong/plugins/"..plugin_name.."/api.lua",
    ["kong.plugins."..plugin_name..".status_api"] = "kong/plugins/"..plugin_name.."/status_api.lua",
  }
}
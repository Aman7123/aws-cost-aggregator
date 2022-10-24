AWS Cost Aggregator
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience
* Kong version: 3.0.0

This plugin will be able to serve a prometheus endpoint with aggregated cost data from AWS for the Kong service, or this plugin will export that info from the route with the plugin applied. This plugin is in early stages of development however it has tests and contains running code.

Plugin Configuration
=================================
| Value | Required | Default | Description |
|---|---|---|---|
| aws_key | ✅ | - | The AWS key credential to be used when invoking the function. |
| aws_secret | ✅ | - | The AWS secret credential to be used when invoking the function. |
| aws_region | ✅ | - | The AWS region where the Lambda function is located. The plugin does not attempt to validate the supplied region name. |
| show_raw_error_in_http | - | false | Displays more detailed errors in http log. |

Plugin Config Example
=================================
See the [Kong decK Configuration](./resources/deck_kong_v3.yaml) for an example of this plugin being configured and deployed.

Installation
=================================
Please review [plugin distribution](https://docs.konghq.com/gateway/latest/plugin-development/distribution/)

### Compile Custom Kong Gateway
```bash
docker build . -t '<image-name>:<version>`
```

Testing
=================================
This template was designed to work with the
[`kong-pongo`](https://github.com/Kong/kong-pongo) and
[`kong-vagrant`](https://github.com/Kong/kong-vagrant) development environments.

To test please install one framework above and run `pongo run` in the default repo

Example resources
=================================
* For a complete walk through of Kong plugin creation check [this blog post on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).
* For Kong PDK resources see [Kong docs](https://docs.konghq.com/gateway/latest/pdk/)
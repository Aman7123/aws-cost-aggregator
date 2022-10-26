AWS Cost Aggregator
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience
* Kong version: 3.0.0

This plugin creates additional metrics to add to the basic Kong Prometheus `/metric` endpoints. This plugin does not effect or change any exist Kong prometheus plugin metrics.

Plugin Configuration
=================================
This plugin does not have a config needing to be set within Kong. This plugin cannot be attached to a consumer/route/service through Kong.

AWS IAM Permissions
=================================
A sample IAM policy looks like:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ce:*"
            ],
            "Resource": "*"
        }
    ]
}
```

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
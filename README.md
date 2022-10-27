AWS Cost Aggregator
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience
* Kong version: 3.0.0

This plugin creates additional metrics to add to the basic Kong Prometheus `/metric` endpoints and therefor is supported in both CE and EE. This plugin does not effect or change any exist Kong prometheus plugin metrics. This plugin does not even need to be configured through Kong or applied to any service/route/consumer all execution happens automatically and can be configured through environment variables. The added metrics shows blended and unblended costs on a monthly basis for the last 12 months and for the last 30 days.

Environment Configuration
=================================
| ENV | Example | Description |
|---|---|---|
| AWS_KEY | abcd1234 | The AWS key credential to be used when invoking the function. The `aws_key` value is required if `aws_secret` is defined. If `aws_key` and `aws_secret` are not set, the plugin uses an IAM role inherited from the instance running Kong to authenticate. |
| AWS_SECRET | xF\Q12R\$$ | The AWS secret credential to be used when invoking the function. The `aws_secret` value is required if `aws_key` is defined. If `aws_key` and `aws_secret` are not set, the plugin uses an IAM role inherited from the instance running Kong to authenticate. |
| AWS_REGION | us-east-1 | The AWS region where the CostExplorer is located. The plugin does not attempt to validate the supplied region name. This field is required because our plugin uses AWS SigV4 if the `AWS_REGION` or `AWS_DEFAULT_REGION` environment variables have not been specified, or an invalid region name has been provided, the plugin errors at runtime. |
| AWS_ASSUME_ROLE_ARN |  | The target AWS IAM role ARN used to invoke the Lambda function. Typically this is used for a cross-account support. |
| AWS_ROLE_SESSION_NAME | kong | The identifier of the assumed role session. It is used for uniquely identifying a session when the same target role is assumed by different principals or for different reasons. The role session name is also used in the ARN of the assumed role principle. Default is `kong`. |
| AG_UPDATE_FREQUENCY | 300 | The default wait time between updates to the promotheus exporter, in seconds. |

Plugin Configuration
=================================
This plugin does not have a config needing to be set within Kong. This plugin cannot be attached to a consumer/route/service through Kong. Please use environment varables.

AWS IAM Permissions
=================================
### Notes
If you provide `AWS_KEY` and `AWS_SECRET` through environment variables, they will be used in the highest priority to invoke the API calls.

If you do not provide an `aws_key` and `aws_secret`, the plugin uses an IAM role inherited from the instance running Kong.

For example, if you’re running Kong on an EC2 instance, the IAM role that attached to the EC2 will be used, and Kong will fetch the credential from the [EC2 Instance Metadata service(IMDSv1)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html). If you’re running Kong in an ECS container, the task IAM role will be used, and Kong will fetch the credentials from the [container credential provider](https://docs.aws.amazon.com/sdkref/latest/guide/feature-container-credentials.html). Note that the plugin will first try to fetch from ECS metadata to get the role, and if no ECS metadata related environment variables are available, the plugin falls back on EC2 metadata.

### AWS region as environment variable
If the plugin configuration aws_region is unset, the plugin attempts to obtain the AWS region through environment variables `AWS_REGION` and `AWS_DEFAULT_REGION`, with the former taking higher precedence. For example, if both `AWS_REGION` and `AWS_DEFAULT_REGION` are set, the `AWS_REGION` value is used; otherwise, if only `AWS_DEFAULT_REGION` is set, its value is used. If neither configuration aws_region nor environment variables are set, a run-time error “no region or host specified” will be thrown.

This isformation above is the same as described here: https://docs.konghq.com/hub/kong-inc/aws-lambda/#aws-region-as-environment-variable

### Policy Example
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
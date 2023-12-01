# Initial setup

First of all, make sure you are running the latest version of the eb cli:

```shell
pip3 install --upgrade --user awsebcli
```

Use a `t2.micro` instance if you are using the AWS free tier. Otherwise, use `t3.micro` or `t3a.micro` with spot to get the lowest price.

Due to memory requirements, the `nano` size does not work since the upgrade to Amazon Linux 2023.

Create environment:

```shell
git tag -f -a -m "First deploy" eb
eb init rssbox --platform ruby-3.2 --keyname id_rsa
eb create --single --instance_type t2.micro
```

<!--
To find the `--platform` value for `eb init`, run:
eb platform list
-->

Using spot instances:

```shell
eb create --single --enable-spot --instance-types t3.micro,t3a.micro
```

With an application load balancer:

```shell
eb create --enable-spot --instance-types t3.micro,t3a.micro --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

With a network load balancer:

```shell
eb create --enable-spot --instance-types t3.micro,t3a.micro --elb-type network --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

Launch in a specific VPC (alternatively omit `--vpc` and update [vpc.config](vpc.config)):

```shell
eb create --vpc --instance-types t3.micro,t3a.micro --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

The following environment variables are automatically set:
- `BUNDLER_DEPLOYMENT_MODE=true`
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production`
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

# Deploy

Deploy with:

```shell
./bin/eb-deploy --staged
```

To export a deployable zip, use:

```shell
git archive --format zip -9 -o rssbox.zip HEAD
```

While testing, it is a lot faster to deploy if there is only one instance running.

# Upgrade major Ruby version

To upgrade an existing app to a new major version of Ruby:

```shell
aws elasticbeanstalk list-available-solution-stacks --region us-west-2 --query 'SolutionStacks[?contains(@,`Ruby`)==`true`]'
aws elasticbeanstalk update-environment --region us-west-2 --environment-name rssbox --solution-stack-name "64bit Amazon Linux 2023 v4.0.1 running Ruby 3.2"
```

Supported Ruby versions: https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.ruby

# Misc

Application files are located at:
- `/var/app/current`

Logs on the instances are available at:
- `/var/log/web.stdout.log`

Elastic Beanstalk deployment logs:
- `/var/log/eb-engine.log`

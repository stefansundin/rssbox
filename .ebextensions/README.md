# Initial setup

First of all, make sure you are running the latest version of the eb cli:
```
pip3 install -U --user awsebcli
```

Use a t2.micro instance if you are using the AWS free tier. Otherwise, use t3.nano or t3a.nano with spot to get the lowest price.

Create environment:
```
git tag -f -a -m "First deploy" eb
eb init rssbox --platform ruby-3.0 --keyname id_rsa
eb create --single --instance_type t2.micro
```

Using spot instances:
```
eb create --single --enable-spot --instance-types t3.nano,t3a.nano
```

With an application load balancer:
```
eb create --enable-spot --instance-types t3.nano,t3a.nano --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

With a network load balancer:
```
eb create --enable-spot --instance-types t3.nano,t3a.nano --elb-type network --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

Launch in a specific VPC (alternatively omit `--vpc` and update [vpc.config](vpc.config)):
```
eb create --vpc --instance-types t3.nano,t3a.nano --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB
```

The following environment variables are automatically set:
- `BUNDLER_DEPLOYMENT_MODE=true`
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production` (this is why the app still has to default `APP_ENV` to `RACK_ENV`)
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

For best experience, please set the following variables as well:
- `LANG=en_US.UTF-8`

# Deploy

Deploy with:
```
./bin/eb-deploy --staged
```

To export a deployable zip, use:
```
git archive --format zip -9 -o rssbox.zip HEAD
```

While testing, it is a lot faster to deploy if there is only one instance running.

# Upgrade major Ruby version

To upgrade an existing app to a new major version of Ruby:
```
aws elasticbeanstalk list-available-solution-stacks --region us-west-2 --query 'SolutionStacks[?contains(@,`Ruby`)==`true`]'
aws elasticbeanstalk update-environment --region us-west-2 --environment-name rssbox --solution-stack-name "64bit Amazon Linux 2 v3.4.0 running Ruby 3.0"
```

Supported Ruby versions: https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.ruby

# Misc

Application files are located at:
- `/var/app/current`

Logs on the instances are available at:
- `/var/log/web.stdout.log`

Elastic Beanstalk deployment logs:
- `/var/log/eb-engine.log`

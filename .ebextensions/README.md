# Initial setup

If you are using the free tier, then use a t2.micro instance. If not, you can use a t1.micro with spot to get the lowest price.

Create environment:
```
git tag -a -m "First deploy" eb-v1
eb init rssbox --platform "Ruby 2.6 (Puma)" --keyname id_rsa
eb create --single --instance_type t2.micro
```

Using spot instances:
```
eb create --single --instance_type t1.micro --envvars EC2_SPOT_PRICE=0.01
```

With an application load balancer:
```
eb create --instance_type t2.micro --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB,EC2_SPOT_PRICE=0.01
```

With a network load balancer:
```
eb create --instance_type t2.micro --elb-type network --envvars ASG_HEALTH_CHECK_TYPE=ELB,EC2_SPOT_PRICE=0.01
```

Launch in a specific VPC (alternatively update `vpc.config` and omit `--vpc`):
```
eb create --vpc --instance_type t2.micro --elb-type application --envvars ASG_HEALTH_CHECK_TYPE=ELB,EC2_SPOT_PRICE=0.01
```

The following environment variables are automatically set:
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production` (this is why the app still has to default `APP_ENV` to `RACK_ENV`)
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

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
aws elasticbeanstalk list-available-solution-stacks --query SolutionStacks
aws elasticbeanstalk update-environment --region us-west-2 --environment-name rssbox --solution-stack-name "64bit Amazon Linux 2018.03 v2.9.1 running Ruby 2.6 (Puma)"
```

# Misc

Application files are located at:
- `/var/app/current`

Logs on the instances are available at:
- `/var/log/puma/puma.log`

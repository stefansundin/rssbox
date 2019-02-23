When selecting Ruby as the platform, EB sets these initial variables:
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production` (this is why the app still has to default `APP_ENV` to `RACK_ENV`)
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

Logs on the instances are available at:
- `/var/log/puma/puma.log`

While testing, it is a lot faster to deploy if there is only one instance running.

To export a deployable zip, use:
```
git archive --format zip -9 -o rssbox.zip HEAD
```

To upgrade an existing app to a new major version of Ruby:
```
aws elasticbeanstalk list-available-solution-stacks --query SolutionStacks
aws elasticbeanstalk update-environment --region us-west-2 --environment-name rssbox --solution-stack-name "64bit Amazon Linux 2018.03 v2.9.1 running Ruby 2.6 (Puma)"
```

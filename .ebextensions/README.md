When selecting Ruby as the platform, EB sets these initial variables:
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production` (this is why the app still has to default `APP_ENV` to `RACK_ENV`)
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

Logs on the instances are available at:
- `/var/log/puma/puma.log`

While testing, it is a lot faster to deploy if there is only one instance running.

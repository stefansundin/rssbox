When selecting Ruby as the platform, EB sets these initial variables:
- `BUNDLE_WITHOUT=test:development`
- `RACK_ENV=production`
- `RAILS_SKIP_ASSET_COMPILATION=false`
- `RAILS_SKIP_MIGRATIONS=false`

Logs on the instances are available at:
- `/var/log/puma/puma.log`

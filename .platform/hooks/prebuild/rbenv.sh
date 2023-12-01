#!/bin/bash -ex
# Elastic Beanstalk
# Delete the .ruby-version file to avoid rbenv errors when there's a conflicting version.
# Without this it is impossible to perform even patch version upgrades. It is pretty dumb.
rm -f .ruby-version

# Work around annoying Errno::ENOENT issue?
mkdir -p /var/app/staging/vendor/bundle/ruby/3.2.0/cache

# I dunno why this directory isn't created.. and I don't care enough to figure out why.
mkdir -p /var/log/nginx/healthd
chown nginx:nginx /var/log/nginx/healthd

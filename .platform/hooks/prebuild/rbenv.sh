#!/bin/bash -ex
# Elastic Beanstalk
# Delete the .ruby-version file to avoid rbenv errors when there's a conflicting version.
# Without this it is impossible to perform even patch version upgrades. It is pretty dumb.
rm -f .ruby-version

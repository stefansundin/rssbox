$setup_env = <<SCRIPT
# To unset variables when restarting, set them to an empty string
export RBENV_ROOT=/home/vagrant/.rbenv
export PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH
export RACK_ENV=deployment
export LOG_ENABLED=1

export REDIS_URL=redis://localhost:6379/3
#export GOOGLE_API_KEY=
#export FACEBOOK_APP_ID=
#export FACEBOOK_APP_SECRET=
#export SOUNDCLOUD_CLIENT_ID=

#export GOOGLE_VERIFICATION_TOKEN=googleXXXXXXXXXXXXXXXX.html
#export GOOGLE_ANALYTICS_ID=UA-1234567-1
#export LOADERIO_VERIFICATION_TOKEN=loaderio-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
SCRIPT


$unicorn_initd = <<SCRIPT
### BEGIN INIT INFO
# Provides:          unicorn
# Required-Start:    $all
# Required-Stop:     $network $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Control unicorn.
# Description:       Unicorn init.d script.
### END INIT INFO

# Exit if a command exits with non-zero code, and treat unset variables as an error
set -u
set -e


# Setup
ENV_SCRIPT=/home/vagrant/setup_env.sh
APP_ROOT=/vagrant
PIDFILE=$APP_ROOT/tmp/unicorn.pid
USER=vagrant
CMD="source $ENV_SCRIPT; export ENV_SCRIPT=$ENV_SCRIPT; cd $APP_ROOT; bundle exec unicorn -p 8080 -c config/unicorn.rb -N -D"

# Helper to send signals to running unicorn
sig() {
  test -s "$PIDFILE" && kill -$1 `cat $PIDFILE` 2>/dev/null
}

# Helper to send signals to old unicorn (used when restarting)
oldsig() {
    test -s "$PIDFILE.oldbin" && kill -$1 `cat "$PIDFILE.oldbin"` 2>/dev/null
}

case ${1-help} in
status)
  sig 0 || (echo "Stopped" && exit 1)
  LSTART=$(ps --no-headers -p $(cat $PIDFILE) -o lstart)
  STIME=$(date -d "$LSTART" +'%Y-%m-%dT%H:%M:%SZ')
  echo "Running [pid: $(cat $PIDFILE)] $STIME" && exit 0
;;
start)
  sig 0 && echo "Already running" && exit 0
  su - $USER -c "$CMD"
  ;;
stop)
  sig QUIT && exit 0
  echo "Not running"
  ;;
force-stop)
  sig TERM && exit 0
  echo "Not running"
  ;;
restart|reload)
  # save the original unicorn pid
  orig_pid=$(cat $PIDFILE 2>/dev/null || true) # catch cat errors

  # start the process if it isn't running already
  sig USR2 || {
    echo "Couldn't reload, starting instead"
    su - $USER -c "$CMD"
    exit $?
  }

  # give unicorn a few seconds
  sleep 10

  # make sure the unicorn pid changed
  new_pid=$(cat $PIDFILE)
  if [ "$new_pid" -eq "$orig_pid" ]; then
    echo "Error reloading"
    exit 1
  fi

  # signal the old unicorn master to quit
  oldsig QUIT || {
    echo "Couldn't quit old unicorn process"
    exit $?
  }

  echo "Reloaded OK"
  exit 0
  ;;
upgrade)
  su - $USER -c "source $ENV_SCRIPT; cd $APP_ROOT; bundle install --without development:test"
  sig USR2 && sleep 2 && sig 0 && oldsig QUIT && exit 0
  echo "Couldn't upgrade, starting instead"
  su - $USER -c "$CMD"
  ;;
rotate)
  sig USR1 && echo "Rotated logs OK" && exit 0
  echo "Couldn't rotate logs" && exit 1
  ;;
*)
  echo "Usage: $0 <status|start|stop|force-stop|restart|upgrade|rotate>"
  exit 1
  ;;
esac
SCRIPT


$root_provision = <<SCRIPT
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git curl build-essential redis-server
apt-get install -y libreadline-dev libxml2-dev libxslt1-dev libpq-dev libsqlite3-dev libssl-dev

cat > /etc/init.d/unicorn << 'EOF'
#{$unicorn_initd}
EOF

chmod +x /etc/init.d/unicorn
SCRIPT
# update-rc.d unicorn defaults # does not work because /vagrant is mounted too late


$user_provision = <<SCRIPT
# install rbenv to /home/vagrant/.rbenv
export RBENV_ROOT=/home/vagrant/.rbenv
export PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

if [ -d "$RBENV_ROOT" ]; then
  rbenv update
else
  git clone https://github.com/sstephenson/rbenv.git $RBENV_ROOT
  git clone https://github.com/sstephenson/ruby-build.git $RBENV_ROOT/plugins/ruby-build
  git clone https://github.com/sstephenson/rbenv-gem-rehash.git $RBENV_ROOT/plugins/rbenv-gem-rehash
  git clone https://github.com/rkh/rbenv-update.git $RBENV_ROOT/plugins/rbenv-update
fi

export RUBY_VERSION=$(cat /vagrant/.ruby-version)
rbenv install $RUBY_VERSION
rbenv global $RUBY_VERSION

gem install bundler

ln -sf /vagrant/.irbrc /home/vagrant/.irbrc

cat > ~/setup_env.sh << 'EOF'
#{$setup_env}
EOF

cat >> ~/.bashrc << EOF

# Added by Vagrantfile
source ~/setup_env.sh
EOF

cd /vagrant
bundle install --without development:test --path=.bundle/gems
SCRIPT


Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "rssbox"
  config.vm.network "forwarded_port", guest: 8080, host: 3000
  config.vm.provision "shell", inline: $root_provision
  config.vm.provision "shell", inline: $user_provision, privileged: false
  config.vm.provision "shell", inline: "service unicorn start", run: "always"
  config.vm.post_up_message = <<EOF
Webserver should now be running at http://localhost:3000/"
Please run 'vagrant ssh' and edit ~/setup_env.sh, then run 'sudo service unicorn restart'.
EOF
end

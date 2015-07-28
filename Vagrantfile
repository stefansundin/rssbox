$root_provision = <<SCRIPT
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git curl build-essential redis-server
apt-get install -y libreadline-dev libxml2-dev libxslt1-dev libpq-dev libsqlite3-dev libssl-dev
SCRIPT


$user_provision = <<SCRIPT
# install rbenv to /usr/local/rbenv
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

rbenv install 2.2.2
rbenv global 2.2.2

gem install bundler

ln -sf /vagrant/.irbrc /home/vagrant/.irbrc

cd /vagrant
bundle install --without development:test --path=.bundle/gems
SCRIPT


Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "forwarded_port", guest: 8080, host: 3000
  config.vm.provision "shell", inline: $root_provision
  config.vm.provision "shell", inline: $user_provision, privileged: false
end

# Handy commands:
# sudo systemctl status puma.socket puma.service
# A hot restart, puma.socket keeps listening:
# sudo systemctl restart puma.service
# Normal restart:
# sudo systemctl restart puma.socket puma.service

# https://www.freedesktop.org/software/systemd/man/systemd.service.html
# https://www.freedesktop.org/software/systemd/man/systemd.socket.html
# https://github.com/puma/puma/blob/master/docs/systemd.md

$env = <<SCRIPT
PATH=/home/ubuntu/.rbenv/versions/global/bin:/home/ubuntu/.rbenv/versions/global/lib/ruby/gems/version/bin:$PATH

RACK_ENV=deployment
LOG_ENABLED=1

REDIS_URL=redis://localhost:6379/3
#GOOGLE_API_KEY=
#FACEBOOK_APP_ID=
#FACEBOOK_APP_SECRET=
#SOUNDCLOUD_CLIENT_ID=

#GOOGLE_VERIFICATION_TOKEN=googleXXXXXXXXXXXXXXXX.html
#GOOGLE_ANALYTICS_ID=UA-1234567-1
#LOADERIO_VERIFICATION_TOKEN=loaderio-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
SCRIPT

$puma_service = <<SCRIPT
[Unit]
Description=Puma
After=network.target
Requires=puma.socket

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/vagrant/
EnvironmentFile=/home/ubuntu/rssbox.env
ExecStart=/home/ubuntu/.rbenv/versions/global/bin/puma -C config/puma.rb -p 8080
Restart=always

[Install]
WantedBy=multi-user.target
SCRIPT

$puma_socket = <<SCRIPT
[Unit]
Description=Puma Socket

[Socket]
ListenStream=0.0.0.0:8080
NoDelay=true
ReusePort=true
Backlog=1024

[Install]
WantedBy=sockets.target
SCRIPT

$root_provision = <<SCRIPT
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git curl build-essential redis-server
apt-get install -y libreadline-dev libxml2-dev libxslt1-dev libpq-dev libsqlite3-dev libssl-dev

cat > /etc/systemd/system/puma.service << 'EOF'
#{$puma_service}
EOF

cat > /etc/systemd/system/puma.socket << 'EOF'
#{$puma_socket}
EOF

systemctl daemon-reload
SCRIPT

$user_provision = <<SCRIPT
# install rbenv to /home/ubuntu/.rbenv
export RBENV_ROOT=/home/ubuntu/.rbenv
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
export RUBY_MAJOR=${RUBY_VERSION%.*}.0

rbenv install $RUBY_VERSION
rbenv global $RUBY_VERSION

gem install bundler

ln -sf /vagrant/.irbrc /home/ubuntu/.irbrc
ln -sf $RUBY_VERSION /home/ubuntu/.rbenv/versions/global
ln -sf $RUBY_MAJOR /home/ubuntu/.rbenv/versions/global/lib/ruby/gems/version

cat > ~/rssbox.env << 'EOF'
#{$env}
EOF

cat >> ~/.bashrc << EOF

# Added by Vagrantfile
source ~/rssbox.env
EOF

cd /vagrant
bundle install --without development:test
SCRIPT


Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.hostname = "rssbox"
  config.vm.network "forwarded_port", guest: 8080, host: 3000
  config.vm.provision "shell", inline: $root_provision
  config.vm.provision "shell", inline: $user_provision, privileged: false
  config.vm.provision "shell", inline: "systemctl start puma.socket puma.service", run: "always"
  config.vm.post_up_message = <<EOF
Webserver should now be running at http://localhost:3000/"
Please run 'vagrant ssh' and edit ~/rssbox.env, then run 'sudo systemctl restart puma.service'.
EOF
end

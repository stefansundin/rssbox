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
PATH=/home/vagrant/.rbenv/bin:/home/vagrant/.rbenv/versions/global/bin:/home/vagrant/.rbenv/versions/global/lib/ruby/gems/version/bin:$PATH

APP_ENV=production
LOG_ENABLED=1

REDIS_URL=redis://localhost:6379/3
#TWITTER_ACCESS_TOKEN=
#GOOGLE_API_KEY=
#VIMEO_ACCESS_TOKEN=
#SOUNDCLOUD_CLIENT_ID=
#TWITCH_CLIENT_ID=
#TWITCHTOKEN_CLIENT_ID=
#IMGUR_CLIENT_ID=

#GOOGLE_VERIFICATION_TOKEN=googleXXXXXXXXXXXXXXXX.html
#GOOGLE_ANALYTICS_ID=UA-1234567-1
SCRIPT

$puma_service = <<SCRIPT
[Unit]
Description=Puma
After=network.target
Requires=puma.socket

[Service]
Type=simple
User=vagrant
WorkingDirectory=/vagrant/
EnvironmentFile=/home/vagrant/rssbox.env
ExecStart=/home/vagrant/.rbenv/versions/global/bin/puma -C config/puma.rb -p 3000
Restart=always

[Install]
WantedBy=multi-user.target
SCRIPT

$puma_socket = <<SCRIPT
[Unit]
Description=Puma Socket

[Socket]
ListenStream=0.0.0.0:3000
NoDelay=true
ReusePort=true
Backlog=1024

[Install]
WantedBy=sockets.target
SCRIPT

$root_provision = <<SCRIPT
export DEBIAN_FRONTEND=noninteractive
chmod -x /etc/cron.daily/apt-compat
chmod -x /etc/cron.weekly/update-notifier-common

apt-get update
apt-get install -y git curl build-essential redis-server jq
apt-get install -y libreadline-dev zlib1g-dev libxml2-dev libxslt1-dev libpq-dev libsqlite3-dev libssl-dev

cat > /etc/systemd/system/puma.service << 'EOF'
#{$puma_service}
EOF

cat > /etc/systemd/system/puma.socket << 'EOF'
#{$puma_socket}
EOF

systemctl daemon-reload
SCRIPT

$user_provision = <<SCRIPT
# install rbenv to /home/vagrant/.rbenv
RBENV_ROOT=/home/vagrant/.rbenv
PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

if [ -d "$RBENV_ROOT" ]; then
  rbenv update
else
  git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT
  git clone https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build
  git clone https://github.com/rkh/rbenv-update.git $RBENV_ROOT/plugins/rbenv-update
  echo 'gem: --no-document' >> ~/.gemrc
fi

RUBY_VERSION=$(cat /vagrant/.ruby-version)
RUBY_MAJOR=${RUBY_VERSION%.*}.0

rbenv install $RUBY_VERSION
rbenv global $RUBY_VERSION
gem update --system

ln -sf /vagrant/.irbrc /home/vagrant/.irbrc
ln -sf $RUBY_VERSION /home/vagrant/.rbenv/versions/global
ln -sf $RUBY_MAJOR /home/vagrant/.rbenv/versions/global/lib/ruby/gems/version

cat > ~/rssbox.env << 'EOF'
#{$env}
EOF

cat >> ~/.bashrc << EOF

# Added by Vagrantfile
source ~/rssbox.env
EOF

source ~/rssbox.env
hash -r

cd /vagrant
bundle install --retry=3 --jobs=4
SCRIPT


Vagrant.configure("2") do |config|
  config.vm.box = "debian/buster64"
  config.vm.hostname = "rssbox"
  config.vm.network "forwarded_port", guest: 3000, host: 3000
  config.vm.provision "shell", inline: $root_provision
  config.vm.provision "shell", inline: $user_provision, privileged: false
  config.vm.provision "shell", inline: "systemctl start puma.socket puma.service", run: "always"
  config.vm.post_up_message = <<EOF
Webserver should now be running at http://localhost:3000/
Please run 'vagrant ssh' and edit ~/rssbox.env, then run: sudo systemctl restart puma.service
EOF
end

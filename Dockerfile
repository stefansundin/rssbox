FROM ubuntu
MAINTAINER stefansundin https://github.com/stefansundin

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
# rbenv and ruby-build dependencies
RUN apt-get install -y git curl build-essential
# gem dependencies
RUN apt-get install -y libreadline-dev libpq-dev libxml2-dev libxslt-dev

WORKDIR /root

RUN git clone https://github.com/sstephenson/rbenv.git .rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git .rbenv/plugins/ruby-build
RUN git clone https://github.com/sstephenson/rbenv-gem-rehash.git .rbenv/plugins/rbenv-gem-rehash
RUN git clone https://github.com/rkh/rbenv-update.git .rbenv/plugins/rbenv-update
RUN git clone https://github.com/ianheggie/rbenv-binstubs.git .rbenv/plugins/rbenv-binstubs

ENV PATH /root/.rbenv/bin:/root/.rbenv/shims:$PATH
RUN rbenv install 2.2.2
RUN rbenv global 2.2.2

RUN echo 'gem: --no-rdoc --no-ri' >> .gemrc
RUN mkdir .bundle
RUN echo 'BUNDLE_WITHOUT: development:test' >> .bundle/config

RUN gem install bundler

COPY . /app
WORKDIR /app

RUN bundle install

EXPOSE 80

CMD ["server", "80"]

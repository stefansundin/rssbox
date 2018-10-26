# https://hub.docker.com/r/stefansundin/rssbox/
# docker pull stefansundin/rssbox
# docker run -i -t -p 8080:8080 stefansundin/rssbox
# docker run -i -t --entrypoint bin/cons stefansundin/rssbox
# docker run --rm --name=rssbox-redis redis redis-server --appendonly yes
# docker run --rm --name=rssbox --env-file=.dockerenv --link=rssbox-redis:redis -i -t -p 8080:8080 stefansundin/rssbox
# docker run --rm --link=rssbox-redis:redis -t redis redis-cli -h redis monitor

# docker build --squash -t stefansundin/rssbox .
# docker push stefansundin/rssbox

FROM stefansundin/ruby:2.5.3
MAINTAINER stefansundin https://github.com/stefansundin/rssbox

# install gem dependencies
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends libxml2-dev libxslt1-dev libcurl4 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development:test --path=.bundle/gems
COPY . .

EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["bin/server"]

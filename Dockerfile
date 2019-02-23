# https://hub.docker.com/r/stefansundin/rssbox/
# docker pull stefansundin/rssbox
# docker run -i -t -p 8080:8080 stefansundin/rssbox
# docker run -i -t --entrypoint bin/cons stefansundin/rssbox

# docker network create rssbox
# docker run --rm --network=rssbox --name=redis redis redis-server --appendonly yes
# docker run --rm --network=rssbox --name=rssbox --env-file=.dockerenv -i -t -p 8080:8080 stefansundin/rssbox
# docker run --rm --network=rssbox -t redis redis-cli -h redis monitor

# docker build --squash -t stefansundin/rssbox .
# docker push stefansundin/rssbox

FROM stefansundin/ruby:2.6
MAINTAINER stefansundin https://github.com/stefansundin/rssbox

# install gem dependencies
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends libxml2-dev libxslt1-dev libcurl4 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --retry=3 --without=development:test --path=.bundle/gems
COPY . .

EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["bin/server"]

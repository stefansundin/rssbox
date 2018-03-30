# docker build --squash -t stefansundin/rssbox .
# docker push stefansundin/rssbox
# docker run -i -t -p 8080:8080 stefansundin/rssbox
# docker run -i -t stefansundin/rssbox bin/cons

# docker run --name=rssbox-redis redis redis-server --appendonly yes
# docker run --name=rssbox --env-file=.dockerenv --link=rssbox-redis:redis -i -t -p 8080:8080 stefansundin/rssbox

FROM stefansundin/ruby:2.5.1
MAINTAINER stefansundin https://github.com/stefansundin/rssbox

# install gem dependencies
RUN apt-get update && apt-get install -y --no-install-recommends libxml2-dev libxslt1-dev libcurl3
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development:test --path=.bundle/gems
COPY . .

EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["bin/server"]

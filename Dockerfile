# docker build -t stefansundin/rssbox .
# docker push stefansundin/rssbox
# docker run -d -P stefansundin/rssbox
# docker run -i -t stefansundin/rssbox bin/cons

# docker run -d --name=rssbox-redis redis redis-server --appendonly yes
# docker run -d --name=rssbox --env-file=.dockerenv --link=rssbox-redis:redis -P stefansundin/rssbox

FROM stefansundin/rbenv:2.4.0
MAINTAINER stefansundin https://github.com/stefansundin/rssbox

ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock

RUN bundle install --without development:test --path=.bundle/gems

COPY . /app

EXPOSE 8080

CMD ["bin/server", "8080"]

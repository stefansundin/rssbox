# docker build -t stefansundin/rssbox .
# docker push stefansundin/rssbox
# docker run -i -t -p 8080:8080 stefansundin/rssbox
# docker run -i -t stefansundin/rssbox bin/cons

# docker run --name=rssbox-redis redis redis-server --appendonly yes
# docker run --name=rssbox --env-file=.dockerenv --link=rssbox-redis:redis -i -t -p 8080:8080 stefansundin/rssbox

FROM stefansundin/rbenv:2.5.0
MAINTAINER stefansundin https://github.com/stefansundin/rssbox

ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock

RUN bundle install --without development:test --path=.bundle/gems

COPY . /app

EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["bin/server"]

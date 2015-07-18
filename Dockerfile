# docker build -t stefansundin/rssbox .
# docker push stefansundin/rssbox
# docker run -d -P stefansundin/rssbox
# docker run -i -t stefansundin/rssbox bin/cons

FROM stefansundin/rbenv:2.2.2
MAINTAINER stefansundin https://stefansundin.com

ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock

RUN bundle install --without development:test --path=.bundle/gems

COPY . /app
WORKDIR /app

EXPOSE 8080

CMD ["bin/server", "8080"]

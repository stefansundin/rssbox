# https://hub.docker.com/r/stefansundin/rssbox
# docker pull stefansundin/rssbox
# docker run -i -t -p 3000:3000 stefansundin/rssbox
# docker run -i -t --entrypoint bin/cons stefansundin/rssbox

# docker network create rssbox
# docker run --rm --network=rssbox --name=redis redis redis-server --appendonly yes
# docker run --rm --network=rssbox --name=rssbox --env-file=.dockerenv -i -t -p 3000:3000 stefansundin/rssbox
# docker run --rm --network=rssbox -t redis redis-cli -h redis monitor

# docker build --pull --squash -t stefansundin/rssbox .
# docker push stefansundin/rssbox

# Multi-arch:
# docker buildx create --use --name multiarch --node multiarch0
# docker buildx build --pull --push --platform linux/amd64,linux/arm64,linux/arm/v7 -t stefansundin/rssbox .
# Push to public ECR:
# export AWS_PROFILE=stefansundin
# docker buildx build --push --platform linux/amd64,linux/arm64,linux/arm/v7 -t public.ecr.aws/stefansundin/rssbox .

FROM stefansundin/ruby:3.0
LABEL org.opencontainers.image.authors="Stefan Sundin"
LABEL org.opencontainers.image.url="https://github.com/stefansundin/rssbox"

# install gem dependencies
RUN \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends libxml2-dev libxslt1-dev libcurl4 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --retry=3 --jobs=4 --without=development:test --path=.bundle/gems
COPY . .

# Run the container as an unprivileged user
RUN mkdir -p tmp
RUN chown nobody:nogroup tmp
USER nobody:nogroup

EXPOSE 3000
ENV PORT=3000
ENTRYPOINT ["bin/server"]

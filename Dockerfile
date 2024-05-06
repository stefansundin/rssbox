# https://hub.docker.com/r/stefansundin/rssbox
# docker pull stefansundin/rssbox
# docker run -i -t -p 3000:3000 stefansundin/rssbox
# docker run -i -t --entrypoint bin/cons stefansundin/rssbox

# docker network create rssbox
# docker run --rm --network=rssbox --name=redis redis redis-server --appendonly yes
# docker run --rm --network=rssbox --name=rssbox --env-file=.dockerenv -i -t -p 3000:3000 stefansundin/rssbox
# docker run --rm --network=rssbox -t redis redis-cli -h redis monitor

# Simple build:
# docker build --pull --progress plain -t stefansundin/rssbox .

# Multi-arch:
# docker buildx create --use --name multiarch --node multiarch0
# docker buildx build --pull --push --progress plain --platform linux/amd64,linux/arm64,linux/arm/v7 -t stefansundin/rssbox .
# Push to public ECR:
# docker buildx imagetools create -t public.ecr.aws/stefansundin/rssbox stefansundin/rssbox

FROM stefansundin/ruby:3.3-jemalloc
LABEL org.opencontainers.image.authors="Stefan Sundin"
LABEL org.opencontainers.image.url="https://github.com/stefansundin/rssbox"

# install system utilities that are useful when debugging
RUN \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    vim less && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development:test
RUN bundle config set --local deployment 'true'
RUN bundle install --retry=3 --jobs=4
COPY . .
RUN find -not -path './vendor/*'

# Disable irb history to prevent .irb_history permission error from showing
RUN echo "IRB.conf[:SAVE_HISTORY] = nil" >> .irbrc

# Run the container as an unprivileged user
RUN mkdir -p tmp
RUN chown nobody:nogroup tmp
USER nobody:nogroup

EXPOSE 3000
ENV PORT=3000
ENTRYPOINT ["bundle", "exec", "puma", "-C", "config/puma.rb"]

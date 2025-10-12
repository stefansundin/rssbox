# https://hub.docker.com/r/stefansundin/rssbox
# docker pull stefansundin/rssbox
# docker run --rm -it -p 3000:3000 stefansundin/rssbox
# docker run --rm -it --entrypoint bin/cons stefansundin/rssbox

# docker network create rssbox
# docker run --rm --network=rssbox --name=redis redis redis-server --appendonly yes
# docker run --rm --network=rssbox --name=rssbox --env-file=.dockerenv -i -t -p 3000:3000 stefansundin/rssbox
# docker run --rm --network=rssbox -t redis redis-cli -h redis monitor

# Simple build:
# docker build --pull --progress plain -t stefansundin/rssbox .

# Multi-arch:
# docker buildx create --use --name multiarch --node multiarch0
# docker buildx build --pull --push --progress plain --platform linux/amd64,linux/arm64,linux/riscv64 -t stefansundin/rssbox .
# Push to public ECR:
# docker buildx imagetools create -t public.ecr.aws/stefansundin/rssbox stefansundin/rssbox

# Verify jemalloc:
# docker run --rm -it --entrypoint ruby -e MALLOC_CONF=stats_print:true stefansundin/rssbox -- -e exit
# Verify YJIT:
# docker run --rm -it --entrypoint ruby -e RUBYOPT="--yjit" stefansundin/rssbox -e "puts RUBY_DESCRIPTION"

FROM ruby:3.4 AS builder

RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc

WORKDIR /app
COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without development:test
RUN bundle config set --local deployment true
RUN bundle install --retry=3 --jobs=4


FROM ruby:3.4-slim

LABEL org.opencontainers.image.authors="Stefan Sundin"
LABEL org.opencontainers.image.url="https://github.com/stefansundin/rssbox"

RUN \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    libjemalloc2 \
    # Uncomment if you need YJIT:
    # rustc \
    vim less && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN ln -s $(uname -m)-linux-gnu/libjemalloc.so.2 /usr/lib/libjemalloc.so.2
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV MALLOC_ARENA_MAX=2

ENV APP_ENV=production

WORKDIR /app
COPY --from=builder /usr/local/etc/gemrc /usr/local/etc/gemrc
COPY --from=builder /usr/local/bundle/config /usr/local/bundle/config
COPY --from=builder /app /app

RUN bundle check

COPY . .
RUN find -not -path './vendor/*'

# Disable irb history to prevent .irb_history permission error from showing
RUN echo "IRB.conf[:SAVE_HISTORY] = nil" >> .irbrc

# Touch config/application.rb to indicate when the docker image was built
RUN touch config/application.rb

# Run the container as an unprivileged user
RUN mkdir -p tmp /nonexistent
RUN chown nobody:nogroup tmp /nonexistent
USER nobody:nogroup

EXPOSE 3000
ENV PORT=3000
ENTRYPOINT ["bundle", "exec", "puma", "-C", "config/puma.rb"]

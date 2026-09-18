# syntax=docker/dockerfile:1
############################################
# Stage 1: gem / node 依存のビルド
############################################
FROM ruby:3.0.4-slim AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential git libpq-dev curl ca-certificates gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 && \
    rm -rf ${BUNDLE_PATH}/ruby/*/cache ${BUNDLE_PATH}/ruby/*/bundler/gems/*/.git

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production=false

COPY . .

# credentials が無くても assets:precompile を通すためのダミー鍵
RUN SECRET_KEY_BASE=dummy RAILS_MASTER_KEY=dummy bundle exec rails assets:precompile && \
    rm -rf node_modules tmp/cache

############################################
# Stage 2: 実行イメージ
############################################
FROM ruby:3.0.4-slim AS runtime

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    PORT=3000

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libpq5 curl tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 1000 rails && \
    useradd --uid 1000 --gid rails --create-home --shell /bin/bash rails

WORKDIR /app

COPY --from=builder ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --from=builder --chown=rails:rails /app /app

USER rails

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://localhost:${PORT}/ -o /dev/null || exit 1

CMD ["bin/rails", "server", "-b", "0.0.0.0"]

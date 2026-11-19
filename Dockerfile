# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=4.0.10
FROM docker.io/library/ruby:${RUBY_VERSION}-slim-bookworm@sha256:2ae2957252f1d59985f012f876f4f70d8fc643537766499ba5efa2c991319823 AS base
ARG RUBY_VERSION
RUN ruby --disable-gems -e 'abort unless RUBY_VERSION == ARGV.fetch(0)' "$RUBY_VERSION"

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Upgrade packages
RUN apt-get update -qq
RUN apt-get upgrade -y

RUN apt-get install --no-install-recommends -y ca-certificates lsb-release curl && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' ca-certificates)" ge '20250419~deb12u2'

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get install --no-install-recommends -y build-essential git pkg-config libyaml-dev libsqlite3-dev

# Install application gems
COPY Gemfile Gemfile.lock .ruby-version ./
RUN gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Install runtime dependencies for SQLite
RUN apt-get install --no-install-recommends -y libsqlite3-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    mkdir -p /rails/log /rails/storage /rails/tmp /rails/data && \
    chown -R rails:rails /rails

# Copy built artifacts: gems, application
COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]

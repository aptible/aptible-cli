FROM ruby:2.7.8

# Install and use an compatible bundler
ENV BUNDLER_VERSION=1.17.3
RUN gem install bundler -v "${BUNDLER_VERSION}"

# Install required gems before copying in code
# to avoid re-installing gems when developing
WORKDIR /app
COPY Gemfile /app
COPY Gemfile.lock /app
COPY aptible-cli.gemspec /app

# We reference the version, so copy that in, too
CMD mkdir -p /app/lib/aptible/cli/
COPY lib/aptible/cli/version.rb /app/lib/aptible/cli/

RUN bundle install

COPY . /app

# Save on typing while testing
RUN echo '#!/bin/bash' > /usr/bin/aptible \
 && echo 'bundle exec bin/aptible $@' >> /usr/bin/aptible \
 && chmod +x /usr/bin/aptible

CMD ["aptible"]

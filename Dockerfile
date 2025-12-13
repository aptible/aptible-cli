ARG RUBY_VERSION=2.3.1
FROM ruby:${RUBY_VERSION}

ARG BUNDLER_VERSION=1.17.3
ENV BUNDLER_VERSION=${BUNDLER_VERSION}
RUN if [ "${BUNDLER_VERSION}" != "" ] ; then \
      gem install bundler -v "${BUNDLER_VERSION}" ; \
    fi

# Install required gems before copying in code
# to avoid re-installing gems when developing
WORKDIR /app
COPY Gemfile /app
COPY Gemfile.lock /app
COPY aptible-cli.gemspec /app

# We reference the version, so copy that in, too
RUN mkdir -p /app/lib/aptible/cli/
COPY lib/aptible/cli/version.rb /app/lib/aptible/cli/

RUN bundle install

COPY . /app

# Save on typing while testing
RUN echo '#!/bin/bash' > /usr/bin/aptible \
 && echo 'bundle exec bin/aptible $@' >> /usr/bin/aptible \
 && chmod +x /usr/bin/aptible

CMD ["aptible"]

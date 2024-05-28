FROM ruby:2.7.8

WORKDIR /app
COPY . /app

RUN ./cleanup_bundler
RUN gem install bundler -v '< 2'
RUN bundle install

CMD ["/app/bin/aptible"]

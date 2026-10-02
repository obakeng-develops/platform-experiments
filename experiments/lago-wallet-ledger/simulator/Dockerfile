FROM ruby:3.3.4-slim

RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y build-essential \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /simulator

COPY Gemfile ./
RUN bundle install

COPY . .

CMD ["ruby", "simulate.rb"]

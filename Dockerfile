FROM ruby:2.3.1

RUN apt-get update
RUN apt-get install -y \
  build-essential \
  libpq-dev imagemagick \
  libmagickwand-dev \
  libmagic-dev \
  libpq-dev \
  python-pygments \
  ghostscript

ADD . /doubtfire-api
WORKDIR /doubtfire-api

EXPOSE 3000

RUN bundle install --without production test replica

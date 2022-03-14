FROM ruby:3.1-buster

# DEBIAN_FRONTEND=noninteractive is required to install tzdata in non interactive way
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
  ffmpeg \
  ghostscript \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmariadb-dev \
  python3-pygments \
  tzdata \
  wget

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

COPY ./.ci-setup/ /doubtfire/.ci-setup/
RUN ./.ci-setup/texlive-install.sh
ENV PATH /tmp/texlive/bin/x86_64-linux:$PATH

RUN gem install bundler -v '~> 2.2.0'

# Install the Gems
COPY ./Gemfile ./Gemfile.lock /doubtfire/
RUN bundle install

# Copy code locally to allow container to be used without the code volume
COPY . .

EXPOSE 3000

ENV RAILS_ENV development
CMD  rm -f tmp/pids/server.pid && bundle exec rake db:migrate && bundle exec rails s -b 0.0.0.0

#
# deployApi.Dockerfile - the container used to host the API only
#
FROM ruby:3.1-buster

# Setup dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  ffmpeg \
  ghostscript \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmariadb-dev \
  tzdata

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

# Copy doubtfire-api source
COPY . /doubtfire/

# Install bundler
RUN gem install bundler -v '~> 2.2.0'
RUN bundle config set --global without development test staging

# Install the Gems
RUN bundle install

EXPOSE 3000

# Set default to production
ENV RAILS_ENV production

# Run migrate and server on launch
CMD bundle exec rake db:migrate && bundle exec rails s -b 0.0.0.0

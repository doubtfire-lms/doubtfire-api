#
# deployApi.Dockerfile - the container used to host the API only
#
FROM ruby:3.4-bookworm

# Setup dependencies
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list \
  && curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

RUN apt-get update \
  && apt-get install -y \
    bc \
    ffmpeg \
    ghostscript \
    imagemagick \
    libmagic-dev \
    libmagickwand-dev \
    libmariadb-dev \
    tzdata \
    redis \
    docker-ce \
    docker-ce-cli \
    containerd.io \
  && apt-get clean

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

# Copy doubtfire-api source
COPY . /doubtfire/

# Install bundler
RUN gem install bundler -v '2.6.6'
RUN bundle config set --global without development test staging

# Install the Gems
RUN bundle install

EXPOSE 3000

# Set default to production
ENV RAILS_ENV production

# Run migrate and server on launch
CMD bundle exec rake db:migrate && bundle exec rails s -b 0.0.0.0

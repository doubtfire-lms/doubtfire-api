#
# deployAppSrc.Dockerfile - the container used for back end processing
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
    ghostscript qpdf \
    imagemagick \
    libmagic-dev \
    libmagickwand-dev \
    libmariadb-dev \
    python3-pygments \
    tzdata \
    cron \
    msmtp-mta bsd-mailx \
    redis \
    docker-ce \
    docker-ce-cli \
    containerd.io \
  && apt-get clean

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

# Install bundler
RUN gem install bundler -v '2.6.6'
RUN bundle config set --global without development test staging

# Install the Gems
COPY ./Gemfile ./Gemfile.lock /doubtfire/
RUN bundle install

# Copy doubtfire-api source
COPY . /doubtfire/

# Crontab file copied to cron.d directory.
COPY ./.ci-setup/crontab /etc/cron.d/container_cronjob

RUN touch /var/log/cron.log

CMD /doubtfire/lib/shell/pdfgen_entry_point.sh

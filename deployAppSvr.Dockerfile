#
# deployAppSrc.Dockerfile - the container used for back end processing
#
FROM ruby:3.1-bullseye

# Setup dependencies
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
  && add-apt-repository "deb [arch=amd64,arm64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
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
    inkscape \
    docker-ce \
    docker-ce-cli \
    containerd.io \
  && apt-get clean

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

# Install LaTex
COPY ./.ci-setup /doubtfire/.ci-setup
RUN /doubtfire/.ci-setup/texlive-install.sh

# Install bundler
RUN gem install bundler -v '2.4.5'
RUN bundle config set --global without development test staging

# Install the Gems
COPY ./Gemfile ./Gemfile.lock /doubtfire/
RUN bundle install

# Setup path
ENV PATH /tmp/texlive/bin/x86_64-linux:/tmp/texlive/bin/aarch64-linux:$PATH

# Copy doubtfire-api source
COPY . /doubtfire/

# Crontab file copied to cron.d directory.
COPY ./.ci-setup/pdfGen/entry_point.sh /doubtfire/
COPY ./.ci-setup/pdfGen/crontab /etc/cron.d/container_cronjob

RUN touch /var/log/cron.log

CMD /doubtfire/entry_point.sh

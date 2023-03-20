FROM ruby:3.1-bullseye

# DEBIAN_FRONTEND=noninteractive is required to install tzdata in non interactive way
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
  bc \
  ffmpeg \
  ghostscript qpdf \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmariadb-dev \
  python3-pygments \
  tzdata \
  wget \
  libc6-dev \
  inkscape \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg2 \
  software-properties-common

# docker-ce-cli apt dependencies
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64,arm64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt-get update
RUN apt-get -y install docker-ce docker-ce-cli containerd.io

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

COPY ./.ci-setup/ /doubtfire/.ci-setup/
RUN ./.ci-setup/texlive-install.sh
ENV PATH /tmp/texlive/bin/x86_64-linux:/tmp/texlive/bin/aarch64-linux:$PATH

RUN gem install bundler -v '2.4.5'

COPY Gemfile /doubtfire/Gemfile
COPY Gemfile.lock /doubtfire/Gemfile.lock

# Install the Gems
RUN bundle install

# Add a script to be executed every time the container starts.
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# Copy code locally to allow container to be used without the code volume
COPY . .

EXPOSE 3000

ENV RAILS_ENV development
CMD  rm -f tmp/pids/server.pid && bundle exec rake db:migrate && bundle exec rails s -b 0.0.0.0

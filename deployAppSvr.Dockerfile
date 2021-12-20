#
# deployAppSrc.Dockerfile - the container used for back end processing
#
FROM ruby:2.6.7-buster

# Setup dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  ffmpeg \
  ghostscript \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmariadb-dev \
  python3-pygments \
  tzdata

# Setup the folder where we will deploy the code
WORKDIR /doubtfire

# Install LaTex
COPY ./.ci-setup /doubtfire/.ci-setup
RUN /doubtfire/.ci-setup/texlive-install.sh

# Install bundler
RUN gem install bundler -v '~> 2.2.0'
RUN bundle config set --global without development test staging

# Install the Gems
COPY ./Gemfile ./Gemfile.lock /doubtfire/
RUN bundle install

# Setup path
ENV PATH /tmp/texlive/bin/x86_64-linux:$PATH

# Copy doubtfire-api source
COPY . /doubtfire/

CMD bundle exec rake submission:generate_pdfs

FROM ubuntu:18.04

RUN apt-get update && apt-get install -y curl git
ENV PATH /root/.rbenv/bin:/root/.rbenv/shims:$PATH
RUN curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer | bash

# Dependencies to build Ruby (https://github.com/rbenv/ruby-build/wiki#suggested-build-environment)
# Uses libssl 1.0 for old Ruby (https://github.com/rbenv/ruby-build/wiki#openssl-usrincludeopensslasn1_mach102-error-error-this-file-is-obsolete-please-update-your-software)
RUN apt-get update && apt-get install -y autoconf bison build-essential libssl1.0-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 libgdbm-dev
RUN rbenv install 2.3.8 && rbenv global 2.3.8

RUN gem install bundler -v 1.17.3
RUN gem update --system
RUN gem install bundler && rbenv rehash


# DEBIAN_FRONTEND=noninteractive is required to install tzdata in non interactive way
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
  ffmpeg \
  ghostscript \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmysqlclient-dev \
  libpq-dev \
  python-pygments \
  tzdata \
  wget 

RUN mkdir /doubtfire-api
WORKDIR /doubtfire-api

COPY ./.ci-setup/ /doubtfire-api/.ci-setup/
#RUN ./.ci-setup/texlive-install.sh
ENV PATH /tmp/texlive/bin/x86_64-linux:$PATH

COPY Gemfile Gemfile.lock /doubtfire-api/
RUN bundle install 

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

EXPOSE 3000

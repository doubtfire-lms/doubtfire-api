FROM ruby:2.3.1

RUN apt-get update && apt-get install -y \
  ghostscript \
  imagemagick \
  libmagic-dev \
  libmagickwand-dev \
  libmagic-dev \
  libpq-dev \
  python-pygments \
  libav-tools

RUN mkdir /doubtfire-api
WORKDIR /doubtfire-api

COPY ./.ci-setup/ /doubtfire-api/.ci-setup/
RUN ./.ci-setup/texlive-install.sh
ENV PATH /tmp/texlive/bin/x86_64-linux:$PATH

COPY Gemfile Gemfile.lock /doubtfire-api/
RUN bundle install --without production replica

# To rebuild Docker image faster, copy application code after installing TeX and Ruby gems
COPY . /doubtfire-api

CMD bundle exec rails s

EXPOSE 3000

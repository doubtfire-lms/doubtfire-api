![Doubtfire Logo](http://puu.sh/lyClF/fde5bfbbe7.png)

# Doubtfire API

A modern, lightweight learning management system.

## Table of Contents

1. [Getting Started](#getting-started)
  1. [...on OS X](#getting-started-on-os-x)
  2. [...on Linux](#getting-started-on-linux)
  3. [...via Docker](#getting-started-via-docker)
2. [Running Rake Tasks](#running-rake-tasks)
3. [PDF Generation Prerequisites](#pdf-generation-prerequisites)
4. [Testing](#testing)
5. [Contributing](#contributing)
6. [License](#license)

## Getting started

### Getting started on OS X

#### 1. Install Homebrew and Homebrew Cask

Install [Homebrew](http://brew.sh) for easy package management, if you haven't already, as well as [Homebrew Cask](http://caskroom.io):

```
$ ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
$ brew install caskroom/cask/brew-cask
```

#### 2. Install rbenv and ruby-build

Install [rbenv](https://github.com/sstephenson/rbenv) and ruby-build:

```
$ brew install ruby-build rbenv
```

Add the following to your `.bashrc`:

```
$ echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

_or_, if you're using [Oh-My-Zsh](http://ohmyz.sh), add to your `.zshrc`:

```
$ echo 'eval "$(rbenv init -)"' >> ~/.zshrc
```

Now install Ruby v2.3.1:

```
$ rbenv install 2.3.1
```

#### 3. Install Postgres

Install the [Postgres App](http://postgresapp.com):

```
$ brew cask install postgres --appdir=/Applications
```

Ensure `pg_config` is on the `PATH`, and then login to Postgres:

```
$ export PATH=/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH
$ psql
```

Create the Doubfire user the following at the Postgres prompt:

```
CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
```

#### 4. Install native tools

Install `imagemagick`, `libmagic` and `ghostscript` using Homebrew:

```
$ brew install imagemagick libmagic ghostscript
```

You will also need to install the Python `pygments` package:

```
$ sudo easy_install Pygments
```

#### 5. Install Doubtfire API dependencies

Clone project and change your working directory to the api:

```
$ git clone https://github.com/doubtfire-lms/doubtfire-api.git
$ cd ./doubtfire-api
```

Set up [overcommit](https://github.com/brigade/overcommit) and install hooks:

```
$ gem install overcommit
$ rbenv rehash
$ overcommit --install
$ overcommit --sign
```

Then install Doubtfire API dependencies using [bundler](http://bundler.io):

```
$ gem install bundler
$ rbenv rehash
$ bundle install --without production test replica
```

##### Bundle resolutions

You may encounter build issues when using Homebrew/Homebrew Cask to install dependencies. Some resolutions to these are listed below:

###### eventmachine

The `eventmachine` gem cannot find `openssl/ssl.h` when compiling with native extensions:

```
Installing eventmachine 1.0.3 with native extensions

...


make "DESTDIR="
compiling binder.cpp
In file included from binder.cpp:20:
./project.h:107:10: fatal error: 'openssl/ssl.h' file not found
#include <openssl/ssl.h>
         ^
1 error generated.
make: *** [binder.o] Error 1
```

To resolve, add the following to your global bundle config:

```
$ bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

Then try installing dependencies again.

###### pg

The `pg` gem cannot find `pg_config` when compiling with native extensions:

```
Installing pg 0.17.1 with native extensions

Gem::Installer::ExtensionBuildError: ERROR: Failed to build gem native extension.

    /Users/[User]/.rbenv/versions/2.3.1/bin/ruby extconf.rb
checking for pg_config... no
No pg_config... trying anyway. If building fails, please try again with
 --with-pg-config=/path/to/pg_config
checking for libpq-fe.h... no
Can't find the 'libpq-fe.h header
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.
```

To resolve, ensure `pg_config` is on the `PATH`:

```
$ export PATH=/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH
```

_or_, add the following to your global bundle config:

```
$ bundle config build.pg --with-pg-config=/Applications/Postgres.app/Contents/Versions/9.4/bin/pg_config
```

You may need to confirm the `Postgres.app` version (it may not be `9.4`).

Then try installing dependencies again.

###### ruby-filemagic

The `ruby-filemagic` gem cannot find `libmagic` libraries when compiling with native extensions:

```
Installing ruby-filemagic 0.6.0 with native extensions

Gem::Installer::ExtensionBuildError: ERROR: Failed to build gem native extension.

    /Users/[User]/.rbenv/versions/2.3.1/bin/ruby extconf.rb
checking for magic_open() in -lmagic... no
checking for magic.h... no
*** ERROR: missing required library to compile this module
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.
```

To resolve, add the following to your global bundle config:

```
$ bundle config build.ruby-filemagic --with-magic-include=/usr/local/include --with-magic-lib=/usr/local/opt/libmagic/lib
```

Then try installing dependencies again.

#### 6. Create and populate Doubtfire development databases

Whilst still in the Doubtfire API project root, execute:

```
$ rake db:create
$ rake db:populate
```

#### 7. Get it up and running!

Run the Rails server and check the API is up by viewing Grape Swagger documentation:

```
$ rails s
$ open http://localhost:3000/api/docs/
```

You should see all the Doubtfire endpoints at **[http://localhost:3000/api/docs/](http://localhost:3000/api/docs/)**, which means the API is running.

### Getting started on Linux

#### 1. Install rbenv and ruby-build

Install [rbenv](https://github.com/sstephenson/rbenv) and ruby-build:

```
$ cd ~
$ git clone git://github.com/sstephenson/rbenv.git .rbenv
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
$ echo 'eval "$(rbenv init -)"' >> ~/.bashrc
$ exec $SHELL
$
$ git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
$ echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
$ exec $SHELL
```

_note_: if you're using [Oh-My-Zsh](http://ohmyz.sh), add to your `.zshrc`:

```
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
$ echo 'eval "$(rbenv init -)"' >> ~/.zshrc
$ echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.zshrc
```

Now install Ruby v2.3.1:

```
$ sudo apt-get install -y libreadline-dev
$ rbenv install 2.3.1
```

#### 3. Install Postgres

Install [Postgres](http://www.postgresql.org/download/linux/):

```
$  sudo apt-get install postgresql \
                        postgresql-contrib \
                        libpq-dev
```

Ensure `pg_config` is on the `PATH`, and then login to Postgres. You will need to locate where `apt-get` has installed your  Postgres binary and add this to your `PATH`. You can use `whereis psql` for that, but ensure you add the directory and not the executable to the path

```
$ whereis pqsl

/usr/bin/psql

$ export PATH=/usr/bin:$PATH
$ sudo -u postgres createuser --superuser $USER
$ sudo -u postgres createdb $USER
$ psql
```

Create the Doubfire user the following at the Postgres prompt:

```
CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
```

#### 4. Install native tools

Install `imagemagick`, `libmagic` and `ghostscript`. You will also need to
install the Python `pygments` package:

```
$ sudo apt-get install ghostscript \
                       imagemagick \
                       libmagickwand-dev \
                       libmagic-dev \
                       python-pygments
```

#### 5. Install Doubtfire API dependencies

Clone project and change your working directory to the api:

```
$ git clone https://github.com/doubtfire-lms/doubtfire-api.git
$ cd ./doubtfire-api
```

Set up [overcommit](https://github.com/brigade/overcommit) and install hooks:

```
$ gem install overcommit
$ rbenv rehash
$ overcommit --install
$ overcommit --sign
```

Then install Doubtfire API dependencies using [bundler](http://bundler.io):

```
$ gem install bundler
$ rbenv rehash
$ bundle install --without production test replica
```

##### Bundle resolutions

You may encounter issues when trying to install bundle dependencies.

###### ruby-filemagic

The `ruby-filemagic` gem cannot find `libmagic` libraries when compiling with native extensions:

```
Installing ruby-filemagic 0.6.0 with native extensions

Gem::Installer::ExtensionBuildError: ERROR: Failed to build gem native extension.

    /Users/[User]/.rbenv/versions/2.3.1/bin/ruby extconf.rb
checking for magic_open() in -lmagic... no
checking for magic.h... no
*** ERROR: missing required library to compile this module
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.
```

To resolve, add the following to your global bundle config:

```
$ bundle config build.ruby-filemagic --with-magic-include=/usr/local/include --with-magic-lib=/usr/lib
```

Then try installing dependencies again.

#### 6. Create and populate Doubtfire development databases

Whilst still in the Doubtfire API project root, execute:

```
$ rake db:create
$ rake db:populate
```

#### 7. Get it up and running!

Run the Rails server and check the API is up by viewing Grape Swagger documentation:

```
$ rails s
```

You should see all the Doubtfire endpoints at **[http://localhost:3000/api/docs/](http://localhost:3000/api/docs/)**, which means the API is running.

## Getting started via Docker

### 1. Install Docker

Download and install [Docker](https://www.docker.com), [Docker Machine](https://docs.docker.com/machine/) and [Docker Compose](https://docs.docker.com/machine/install-machine/) for your platform:

#### OS X

For OS X with [Homebrew](http://brew.sh) and [Homebrew Cask](http://caskroom.io) installed, run:

```
$ brew cask install virtualbox
$ brew install docker docker-machine docker-compose
```

For OS X without Homebrew installed, you can download the [Docker toolbox](https://www.docker.com/toolbox) instead.

#### Linux

Install following the instructions for [Docker](https://docs.docker.com/linux/step_one/), [Docker Machine](https://docs.docker.com/machine/install-machine/), and [Docker Compose](https://docs.docker.com/compose/install/)

#### Windows

Download and install [Docker toolkit](https://www.docker.com/toolbox) and run through the [getting started guide](https://docs.docker.com/windows/step_one/)

### 2. Create the virtual machine

```
docker-machine create --driver virtualbox doubtfire
```

Add the docker daemon to your `.bashrc`:

```
$ echo eval "$(docker-machine env doubtfire)" >> ~/.bashrc
```

_or_, if you're using [Oh-My-Zsh](http://ohmyz.sh), add to your `.zshrc`:

```
$ echo eval "$(docker-machine env doubtfire)" >> ~/.zshrc
```

### 3. Clone Repos

Clone the doubtfire API and web repos to the same directory:

```
$ git clone https://github.com/doubtfire-lms/doubtfire-web.git
$ git clone https://github.com/doubtfire-lms/doubtfire-api.git
```

Set up [overcommit](https://github.com/brigade/overcommit) and install hooks:

```
$ sudo gem install overcommit
$ cd /path/to/doubtfire-api
$ overcommit --install
$ overcommit --sign
$ cd /path/to/doubtfire-web
$ overcommit --install
$ overcommit --sign
```

If `gem` fails, you should ensure Ruby is installed on your system:

- **OS X**: ruby comes installed with OS X
- **Linux**: try installing using `apt-get install ruby-full`
- **Windows**: try [RubyInstaller](http://rubyinstaller.org)

### 4. Starting Doubtfire

Execute the docker start script under `doubtfire-api`:

```
$ cd /path/to/doubtfire-api
$ ./docker.sh start
```

The populate script will ask you if you would like extended population.

Note that the API and Web servers will take a moment to get up and running.

### 5. Stopping Doubtfire

To stop Doubtfire running, run the stop script under `doubtfire-api`:

```
$ cd /path/to/doubtfire-api
$ ./docker.sh stop
```

### 6. For future reference...

#### Attaching to the Doubtfire containers

##### Doubtfire Web

You should attach to the grunt watch server if working on the web app to view output, if in case you make a lint error. To do so, run:

```
$ cd /path/to/doubtfire-api
$ ./docker.sh attach web
```

##### Doubtfire API

You should attach to the rails app if working on the API to view debug output. To do so, run:

```
$ cd /path/to/doubtfire-api
$ ./docker.sh attach api
```

#### Executing rake or grunt tasks within the Docker container

Should you need to execute any commands from inside the Docker container, such as running rake tasks, or a rails migration, use `docker-compose` but execute from within `doubtfire-api`:

```
$ cd /path/to/doubtfire-api
$ docker-compose -p doubtfire run api <api command>
$ docker-compose -p doubtfire run web <web command>
```

## Running Rake Tasks

You can perform developer-specific tasks using `rake`. For a list of all tasks, execute in the root directory:

```
rake --tasks
```

## PDF Generation Prerequisites

PDF generation requires [LaTeX](https://en.wikipedia.org/wiki/LaTeX) to be installed. If you do not install LaTeX and execute the `submission:generate_pdfs` task, you will encounter errors.

Install LaTeX on your platform before running this task.

### Installing LaTeX on OS X

For OS X with Homebrew Cask, use:

```
$ brew cask install mactex
```

For OS X without Homebrew, download and install the [MacTeX distribution](http://www.tug.org/mactex/mactex-download.html).

A note especially for OS X users who have installed LaTeX under El Capitan, your installation will be under `/Library/TeX/texbin`. This **needs to be added to the `PATH`**:

```
$ echo "export PATH=$PATH:/Library/TeX/texbin" >> ~/.bashrc
```

or, if using zsh:

```
$ echo "export PATH=$PATH:/Library/TeX/texbin" >> ~/.zshrc
```

Refer to [this artcile](http://www.tug.org/mactex/elcapitan.html) for more about MacTeX installs on El Capitan.

### Installing LaTeX on Linux

For Linux, use:

```
$ apt-get install texlive-full
```

### Installing LaTeX on a Docker container

By default, LaTeX is not installed within the Doubtfire API container to save time and space.

Should you need to install LaTeX within the container run:

```
$ docker-compose -p doubtfire run api "bash -c 'apt-get update && apt-get install texlive-full'"
```

### Check your PATH for Linux and OS X

After installing LaTeX, you must ensure the following are listed on the `PATH`:

```
$ which convert
/usr/local/bin/convert
$ which pygmentize
/usr/local/bin/pygmentize
$ which pdflatex
/Library/TeX/texbin/pdflatex
```

If any of the following are not found, then you will need to double check your installation and ensure the binaries are on the `PATH`. If they are not installed correctly, refer to the install native tools section for [OS X](#4-install-native-tools) and [Linux](#4-install-native-tools-1) and ensure the native tools are installing properly.

This section does not apply to users using Docker for Doubtfire.

## Testing

Our aim with testing Doubtfire is to migrate to a [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
strategy, testing all new models and API endpoints (although we plan on writing
more tests for _existing_ models and API endpoints). If you are writing a new
API endpoint or model, we strongly suggest you include unit tests in the
appropriate folders (see below).

To run unit tests, execute:

```bash
$ rake test
```

A report will be generated under `spec/reports/hyper/index.html`.

Unit tests are located in the `test` directory, where **model** tests are under
the `model` subdirectory and **API** tests are under the `api` subdirectory.

Any **helpers** should be included in the `helpers` subdirectory and helper
modules should be written under the `TestHelpers` module.

## Contributing

Refer to CONTRIBUTING.md

## License

Licensed under GNU Affero General Public License (AGPL) v3

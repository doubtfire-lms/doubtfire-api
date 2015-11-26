![Doubtfire Logo](http://puu.sh/lyClF/fde5bfbbe7.png)

# Doubtfire API
            
A modern, lightweight learning management system.

## Getting started

### OS X

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

Now install Ruby v2.0.0-p353:

```
$ rbenv install 2.0.0-p353
```

#### 3. Install Postgres

Install the [Postgres App](http://postgresapp.com):

```
$ brew cask install postgres
```

Ensure `pg_config` is on the `PATH`, and then login to Postgres:

```
$ export PATH=~/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH
$ psql
``` 

Create the Doubfire user the following at the Postgres prompt:

```
CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
```

#### 4. Install native tools

Install imagemagick, libmagic, and pdftk:

```
$ brew tap docmunch/pdftk
$ brew install imagemagick libmagic pdftk
```

This step may take up to 20 minutes to complete as the pdftk compilation process is slow. Refer to the GitHub issue [here](https://github.com/docmunch/homebrew-pdftk/issues/5).

#### 5. Install Doubtfire API dependencies

Clone project and change your working directory to the api:

```
$ git clone https://[user]@bitbucket.org/itig/doubtfire-api.git
$ cd ./doubtfire-api
```

Then install Doubtfire API dependencies using [bundler](http://bundler.io):

```
$ gem install bundler
$ bundle install --without production test
```

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

You should see all the Doubtfire endpoints here, which means the API is running.

### Linux

#### 1. Install rbenv and ruby-build

Install [rbenv](https://github.com/sstephenson/rbenv) and ruby-build:

```
$ sudo apt-get update
$ sudo apt-get install ruby-build rbenv
```

Add the following to your `.bashrc`:

```
$ echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

_or_, if you're using [Oh-My-Zsh](http://ohmyz.sh), add to your `.zshrc`:

```
$ echo 'eval "$(rbenv init -)"' >> ~/.zshrc
```

Now install Ruby v2.0.0-p353:

```
$ rbenv install 2.0.0-p353
```

#### 3. Install Postgres

Install [Postgres](http://www.postgresql.org/download/linux/):

```
$ sudo apt-get install postgresql postgresql-contrib
```

Ensure `pg_config` is on the `PATH`, and then login to Postgres. You will need to locate where `apt-get` has installed your  Postgres binary and add this to your `PATH`. You can use `whereis psql` for that, but ensure you add the directory and not the executable to the path

```
$ whereis pqsl

/usr/bin/psql

$ export PATH=/usr/bin:$PATH
$ psql
```

Create the Doubfire user the following at the Postgres prompt:

```
CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
```

#### 4. Install native tools

Install imagemagick, libmagic, and pdftk:

```
$ sudo apt-get install imagemagick --fix-missing
$ sudo apt-get install libmagic-dev
$ sudo apt-get install pdftk
```

#### 5. Install Doubtfire API dependencies

Clone project and change your working directory to the api:

```
$ git clone https://[user]@bitbucket.org/itig/doubtfire-api.git
$ cd ./doubtfire-api
```

Then install Doubtfire API dependencies using [bundler](http://bundler.io):

```
$ gem install bundler
$ bundle install --without production test
```

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

You should see all the Doubtfire endpoints here, which means the API is running.

## Rake Tasks

You can perform developer-specific tasks using `rake`. For a list of all tasks, execute in the root directory:

```
rake --tasks
```

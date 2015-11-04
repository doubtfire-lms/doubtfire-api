# Getting Started On Linux#

Setting up a dev environment:

1. Install rbenv
    1. `apt-get install ruby-build`
    2. `apt-get install rbenv`
    3. Add `eval "$(rbenv init -)"` to .bashrc
2. Install ruby (version 2.1.2)
    1. `rbenv install 2.0.0-p353`
    2. `rbenv global 2.0.0-p353`
3. Install postgres
    1. Ensure pg_config is on the path
    2. eg: `export PATH=/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH`
    3. Login using `psql`
    4. Setup itig user with: `CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;`
4. Install imagemagick
4. Checkout project
    1. cd to working source location (dev folder on your machine)
    2. `git clone https://macite@bitbucket.org/itig/doubtfire-api.git`
5. Install rails
    1. `gem install bundler`
    2. `bundle install --without production test` (in project root)
6. Create Database
    1. `rake db:create`
    2. `rake db:populate`
7. View grape swagger
    1. Launch server: `rails s`
    2. Navigate browser to http://localhost:3000/api/docs/

# Getting Started On Mac#

Setting up a dev environment:

1. Install rbenv
    1. `brew install ruby-build`
    2. `brew install rbenv`
    3. Add `eval "$(rbenv init -)"` to .bashrc/.zshrc
2. Install ruby (version 2.0.0)
    1. `rbenv install 2.0.0-p353`
    2. `rbenv global 2.0.0-p353`
    3. Restart the terminal
3. Install postgres
    1. Ensure pg_config is on the path
    2. eg: `export PATH=/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH`
    3. Login using `psql`
    4. Setup itig user with: `CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;`
4. Install native tools
    1. `brew install imagemagick`
    1. `brew install libmagic`
    1. pre 10.11 `brew cask install pdftk` (note if the cask is not found, try `brew install https://raw.github.com/quantiverge/homebrew-binary/pdftk/pdftk.rb`)
    1. 10.11 Install from https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg see https://stackoverflow.com/questions/32505951/pdftk-server-on-os-x-10-11
4. Checkout project
    1. cd to working source location (dev folder on your machine)
    2. `git clone https://macite@bitbucket.org/itig/doubtfire-api.git`
5. Install rails
    1. `gem install bundler`
    2. `bundle install --without production test replica` (in project root)
6. Create Database
    1. `rake db:create`
    2. `rake db:populate`
7. View grape swagger
    1. Launch server: `rails s`
    2. Navigate browser to http://localhost:3000/api/docs/

# Getting Started On Windows#

Setting up a dev environment:

1. Install RailsInstaller Alpha (http://railsinstaller.org/en)
2. Install postgres for Windows (http://www.postgresql.org/download/windows/)
    1. Setup itig user with: `CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;`
4. Checkout project
    1. cd to working source location (dev folder on your machine)
    2. `git clone https://macite@bitbucket.org/itig/doubtfire-api.git`
5. Open Command Prompt with Ruby and Rails prompt
    1. cd to working source location
6. Run Bundler
    1. `bundle install` (in project root)
6. Create Database
    1. `rake db:create`
    2. `rake db:populate`
7. View grape swagger
    1. Launch server: `rails s`
    2. Navigate browser to http://localhost:3000/api/docs/
==Getting Started==

Settung up a dev environment:

# Install rbenv
# Install ruby (version 2.1.0)
## rbenv install 2.1.0
## rbenv global 2.1.0
# Install postgres
## Ensure pg_config is on the path
## eg: export PATH=/Applications/Postgres.app/Contents/Versions/9.3/bin:$PATH
## Login using psql
## Setup itig user with: CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
# Install rails
## gem install bundler
## bundle install (in project root)
# Create Database
## rake db:create
## rake db:populate

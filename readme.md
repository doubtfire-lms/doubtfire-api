# Getting Started #

Settung up a dev environment:

1. Install rbenv
2. Install ruby (version 2.1.0)
2.1. rbenv install 2.1.0
2.2 rbenv global 2.1.0
3. Install postgres
3.1. Ensure pg_config is on the path
3.2. eg: export PATH=/Applications/Postgres.app/Contents/Versions/9.3/bin:$PATH
3.3. Login using psql
3.4. Setup itig user with: CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;
4. Install rails
4.1. gem install bundler
4.2. bundle install (in project root)
5. Create Database
5.1. rake db:create
5.2. rake db:populate
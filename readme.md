# Getting Started #

Setting up a dev environment:

1. Install rbenv
2. Install ruby (version 2.1.0)
    1. `rbenv install 2.1.0`
    2. `rbenv global 2.1.0`
3. Install postgres
    1. Ensure pg_config is on the path
    2. eg: `export PATH=/Applications/Postgres.app/Contents/Versions/9.3/bin:$PATH`
    3. Login using `psql`
    4. Setup itig user with: `CREATE ROLE itig WITH CREATEDB PASSWORD 'd872$dh' LOGIN;`
4. Checkout project
    1. cd to working source location (dev folder on your machine)
    2. `git clone https://macite@bitbucket.org/itig/doubtfire-api.git`
5. Install rails
    1. `gem install bundler`
    2. `bundle install` (in project root)
6. Create Database
    1. `rake db:create`
    2. `rake db:populate`
7. View grape swagger
    1. Launch server: `rails s`
    2. Navigate browser to http://localhost:3000/api/docs/
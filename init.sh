#!/bin/sh

rake db:drop
rake db:migrate
rake db:init
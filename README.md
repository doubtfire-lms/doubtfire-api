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

### Getting started on MacOS, Linux or Docker.

#### 1. Install script

#### 2. Manual install
The manual installation guide can be found on the wiki at: Linux, MacOS, Docker

#### 3. Get it up and running!
Once you've installed using either in install script or the manual install steps,
Run the Rails server and check the API is up by viewing Grape Swagger documentation:

```
$ rails s
$ open http://localhost:3000/api/docs/
```

You should see all the Doubtfire endpoints at **[http://localhost:3000/api/docs/](http://localhost:3000/api/docs/)**, which means the API is running.

## Running Rake Tasks

You can perform developer-specific tasks using `rake`. For a list of all tasks, execute in the root directory:

```
rake --tasks
```

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

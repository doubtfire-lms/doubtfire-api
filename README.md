![Doubtfire Logo](http://puu.sh/lyClF/fde5bfbbe7.png)

# Doubtfire API  [![Build Status](https://travis-ci.org/doubtfire-lms/doubtfire-api.svg?branch=development)](https://travis-ci.org/doubtfire-lms/doubtfire-api)

A modern, lightweight learning management system.

## Table of Contents

1. [Getting Started](#getting-started)
  1. [Install Script](#install-script)
  2. [Manual Install](#manual-install)
2. [Environment Variables](#environment-variables)
3. [Getting up and Running](#getting-up-and-running)
4. [Running Rake Tasks](#running-rake-tasks)
5. [PDF Generation Prerequisites](#pdf-generation-prerequisites)
6. [Testing](#testing)
7. [Contributing](#contributing)
8. [License](#license)

## Getting started

### Install script

The install script will try to setup the development environment for either macOS or Linux, and can be found in the root of the project as `setup.sh`.

### Manual install

The manual installation guide can be found on the wiki for: [Linux](https://github.com/doubtfire-lms/doubtfire-api/wiki/Manual-install-on-Linux), [macOS](https://github.com/doubtfire-lms/doubtfire-api/wiki/Manual-install-on-macOS), or [Docker](https://github.com/doubtfire-lms/doubtfire-api/wiki/Getting-Started-Using-Docker).

## Environment variables

Doubtfire requires multiple environment variables that help define settings about the Doubtfire instance running. Whilst these will default to other values, you may want to override them in production.


| Key                           | Description                                                                                                                                                                                                                                                                   | Default               |
|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| `DF_AUTH_METHOD`              | The authentication method you would like Doubtfire to use. Possible values are `database` for standard authentication with the database, `ldap` for [LDAP](https://www.freebsd.org/doc/en/articles/ldap-auth/), and `aaf` for [AAF Rapid Connect](https://rapid.aaf.edu.au/). | `database`            |
| `DF_STUDENT_WORK_DIR`         | The directory to store uploaded student work for processing.                                                                                                                                                                                                                  | `student_work`        |
| `DF_INSTITUTION_NAME`         | The name of your institution running Doubtfire.                                                                                                                                                                                                                               | _University of Foo_   |
| `DF_INSTITUTION_EMAIL_DOMAIN` | The email domain from which emails are sent to and from in your institution.                                                                                                                                                                                                  | `doubtfire.com`       |
| `DF_INSTITUTION_HOST`         | The host running the Doubtfire instance.                                                                                                                                                                                                                                      | `localhost:3000`      |
| `DF_INSTITUTION_PRODUCT_NAME` | The name of the product (i.e. Doubtfire) at your institution.                                                                                                                                                                                                                 | _Doubtfire_           |
| `DF_SECRET_KEY_BASE`          | The Rails secret key.                                                                                                                                                                                                                                                         | Default key provided. |
| `DF_SECRET_KEY_ATTR`          | The secret key to encrypt certain database fields.                                                                                                                                                                                                                            | Default key provided. |
| `DF_SECRET_KEY_DEVISE`        | The secret key provided to Devise.                                                                                                                                                                                                                                            | Default key provided. |
| `DF_SECRET_KEY_MOSS`          | The secret key provided to [Moss](http://theory.stanford.edu/~aiken/moss/) for plagiarism detection. This value will need to be set to run `rake submission:check_plagiarism` (otherwise you **won't** need it). You will need to register for a Moss account to use this.    | No default.           |
| `DF_INSTITUTION_PRIVACY`      | A statement related to the need for students to submit their own work, and that this work may be uploaded to 3rd parties for the purpose of plagiarism detection.                                                                                                                                    | Default statement provided |
| `DF_INSTITUTION_PLAGIARISM`      | A statement clarifying the terms plagiarism and collusion.                                                                                                                                    | Default statement provided |
| `DF_INSTITUTION_SETTINGS_RB`      | The path of the institution specific settings rb code - used to map student imports from institutional exports to a format understood by Doubtfire.                                                                                                                | No default |

If you have chosen to use AAF Rapid Connect authentication, then you will also need to provide the following:

| Key                            | Description                                                                                                                                                                            | Default                         |
|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| `DF_AAF_ISSUER_URL`            | The URL of the AFF issuer, either `https://rapid.test.aaf.edu.au` for testing or `https://rapid.aaf.edu.au` for production.                                                            | `https://rapid.test.aaf.edu.au` |
| `DF_AAF_AUDIENCE_URL`          | The URL of the AAF registered application.                                                                                                                                             | No default - required           |
| `DF_AAF_CALLBACK_URL`          | The secure endpoint within your application that AAF Rapid Connect should POST responses to. It **must end with `/api/auth/jwt`** to access the Doubtfire JWT authentication endpoint. | No default - required           |
| `DF_AAF_UNIQUE_URL`            | The unique URL provided by AAF Rapid Connect used for redirection out of Doubtfire.                                                                                                    | No default - required           |
| `DF_AAF_IDENTITY_PROVIDER_URL` | The URL of the AAF-registered identity provider.                                                                                                                                       | No default - required           |
| `DF_SECRET_KEY_AAF`            | The secret used to register your application with AAF.                                                                                                                                 | `secretsecret12345`             |

You may choose to keep your environment variables inside a `.env` file using key-value pairs:

```
DF_INSTITUTION_HOST=doubtfire.unifoo.edu.au
DF_INSTITUTION_NAME="University of Foo"
```

You can also keep multiple `.env` files for different environments, e.g.: `.env.production` is different to `.env.develoment`. Doubtfire uses the [dotenv](https://github.com/bkeepers/dotenv) gem to make this happen.


### Get it up and running!

Once you've installed using either in install script or the manual install steps.

```
$ rails s
```

You should see all the Doubtfire endpoints at **[http://localhost:3000/api/docs/](http://localhost:3000/api/docs/)**, which means the API is running.

# Running Rake Tasks

You can perform developer-specific tasks using `rake`. For a list of all tasks, execute in the root directory:

```
rake --tasks
```

# Testing

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

# Contributing

Refer to CONTRIBUTING.md

# License

Licensed under GNU Affero General Public License (AGPL) v3

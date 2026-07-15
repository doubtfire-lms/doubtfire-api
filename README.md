<p align="center">
	<img alt="OnTrack logo" src="public/assets/images/logo.svg" width="192">
</p>

# OnTrack API

[![test-doubtfire-api](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/push.yml/badge.svg)](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/push.yml) [![CodeQL](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/codeql.yml/badge.svg)](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/codeql.yml) [![RuboCop](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/rubocop.yml/badge.svg)](https://github.com/doubtfire-lms/doubtfire-api/actions/workflows/rubocop.yml)

OnTrack (formerly Doubtfire) is a feedback-driven learning support system. This repository contains
the Rails and Grape API used by OnTrack.

## Development and deployment

Use the
[doubtfire-deploy](https://github.com/doubtfire-lms/doubtfire-deploy)
repository for the supported development environment and the deployment guide.
It checks out this API as a submodule and provides the database, Redis, PDF
services, web app, and required configuration in one place.

When the development environment is running, the API documentation is available
at <http://localhost:3000/api/docs/>.

## Testing

Run API commands inside the `doubtfire-deploy` Dev Container:

```sh
cd /workspace/doubtfire-api
rails test

# Running an individual test
rails test test/api/settings_test:14 # test_get_config_details
```

Tests are grouped under `test/models`, `test/api`, and `test/helpers`. List the
available maintenance and development tasks with `rails --tasks`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the GNU Affero General Public License (AGPL) v3.

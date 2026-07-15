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

## Environment variables

The API supports the environment variables below. The production deployment
template is maintained in
[`doubtfire-deploy`](https://github.com/doubtfire-lms/doubtfire-deploy/blob/main/production/api/.env.production).
An unset variable uses its application default where one exists; an empty value
may override that default with an empty string.

### Application and database

| Variable                    | Purpose                                   | Default                    |
| --------------------------- | ----------------------------------------- | -------------------------- |
| `RAILS_ENV`                 | Rails runtime environment.                | `development`              |
| `DF_LOG_TO_STDOUT`          | Send Rails logs to standard output.       | `false`                    |
| `DF_PRODUCTION_DB_ADAPTER`  | Production database adapter.              | Deployment-specific        |
| `DF_PRODUCTION_DB_HOST`     | Production database host.                 | Deployment-specific        |
| `DF_PRODUCTION_DB_DATABASE` | Production database name.                 | Deployment-specific        |
| `DF_PRODUCTION_DB_USERNAME` | Production database username.             | Deployment-specific        |
| `DF_PRODUCTION_DB_PASSWORD` | Production database password.             | Deployment-specific        |
| `DF_REDIS_CACHE_URL`        | Redis connection used by the Rails cache. | `redis://localhost:6379/0` |
| `DF_REDIS_SIDEKIQ_URL`      | Redis connection used by Sidekiq.         | `redis://localhost:6379/1` |

### Storage and processing

| Variable                              | Purpose                                                          | Default                         |
| ------------------------------------- | ---------------------------------------------------------------- | ------------------------------- |
| `DF_STUDENT_WORK_DIR`                 | Directory containing uploaded student work.                      | `student_work`                  |
| `DF_ARCHIVE_DIR`                      | Directory containing archived student work.                      | `DF_STUDENT_WORK_DIR/archive`   |
| `DF_ARCHIVE_UNITS`                    | Enable automatic unit archiving.                                 | `false`                         |
| `DF_UNIT_ARCHIVE_PERIOD`              | Years to retain units before archiving.                          | `2`                             |
| `DF_MAX_PDF_GEN_PROCESSES`            | Maximum concurrent PDF-generation processes.                     | `2`                             |
| `DF_MAX_FILE_SIZE`                    | Maximum uploaded file size in bytes.                             | `10000000`                      |
| `DF_ZIP_ENTRY_LIMIT`                  | Maximum number of entries in an uploaded ZIP.                    | `1000`                          |
| `DF_ZIP_COMPRESSION_RATIO_LIMIT`      | Maximum permitted ZIP compression ratio.                         | `100`                           |
| `DF_ZIP_UNCOMPRESSED_SIZE_MULTIPLIER` | Maximum expanded ZIP size as a multiple of `DF_MAX_FILE_SIZE`.   | `10`                            |
| `DF_AUDITOR_UNIT_ACCESS_YEARS`        | Number of years of units visible to auditors.                    | `2`                             |
| `DF_IMPORT_STUDENTS_WEEKS_BEFPRE`     | Weeks before a teaching period that student imports are allowed. | `1`                             |
| `DF_FFMPEG_PATH`                      | Path to FFmpeg for audio processing.                             | `ffmpeg`                        |
| `LATEX_CONTAINER_NAME`                | Container used for LaTeX PDF generation.                         | Unset                           |
| `LATEX_BUILD_PATH`                    | LaTeX build script inside that container.                        | `/texlive/shell/latex_build.sh` |

### Institution

| Variable                       | Purpose                                       | Default                               |
| ------------------------------ | --------------------------------------------- | ------------------------------------- |
| `DF_INSTITUTION_NAME`          | Institution display name.                     | Institution configuration             |
| `DF_INSTITUTION_EMAIL_DOMAIN`  | Institution email domain.                     | Institution configuration             |
| `DF_INSTITUTION_HOST`          | Public application URL.                       | Institution configuration             |
| `DF_COOKIE_DOMAIN`             | Domain assigned to secure cookies.            | Derived from `DF_INSTITUTION_HOST`    |
| `DF_INSTITUTION_PRODUCT_NAME`  | Product name shown to users.                  | Institution configuration             |
| `DF_INSTITUTION_HAS_LOGO`      | Enable an institution logo.                   | `false`                               |
| `DF_INSTITUTION_LOGO_URL`      | Institution logo URL.                         | `/assets/images/institution-logo.png` |
| `DF_INSTITUTION_LOGO_LINK_URL` | Destination opened from the institution logo. | `/`                                   |
| `DF_INSTITUTION_PRIVACY`       | Submission privacy and authorship statement.  | Institution configuration             |
| `DF_INSTITUTION_PLAGIARISM`    | Plagiarism and collusion statement.           | Institution configuration             |
| `DF_INSTITUTION_SETTINGS_RB`   | Institution-specific Ruby configuration file. | Unset                                 |

### Authentication and encryption

Rails credentials take precedence over the corresponding environment fallback
for `DF_SECRET_KEY_BASE`, `DF_SECRET_KEY_ATTR`, `DF_SECRET_KEY_DEVISE`,
`DF_SECRET_KEY_AAF`, `DF_SECRET_KEY_MOSS`, and `LTI_SHARED_API_SECRET`.

| Variable                            | Purpose                                                      | Default                          |
| ----------------------------------- | ------------------------------------------------------------ | -------------------------------- |
| `DF_AUTH_METHOD`                    | Authentication method: `database`, `ldap`, `aaf`, or `saml`. | `database`                       |
| `DF_ACCESS_TOKEN_EXPIRY_SECONDS`    | Access-token lifetime in seconds.                            | `7200`                           |
| `DF_REFRESH_TOKEN_EXPIRY_SECONDS`   | Refresh-token lifetime in seconds.                           | `604800`                         |
| `DF_SECRET_KEY_BASE`                | Rails secret key base fallback.                              | Required in production           |
| `DF_SECRET_KEY_ATTR`                | Legacy encrypted-attribute key fallback.                     | Required in production           |
| `DF_SECRET_KEY_DEVISE`              | Devise secret fallback.                                      | Required in production           |
| `DF_SECRET_KEY_MOSS`                | MOSS integration secret fallback.                            | Unset                            |
| `DF_ENCRYPTION_PRIMARY_KEY`         | Active Record Encryption primary key.                        | Required when encryption is used |
| `DF_ENCRYPTION_DETERMINISTIC_KEY`   | Active Record Encryption deterministic key.                  | Required when encryption is used |
| `DF_ENCRYPTION_KEY_DERIVATION_SALT` | Active Record Encryption derivation salt.                    | Required when encryption is used |

#### AAF Rapid Connect

| Variable                       | Purpose                                   | Default                         |
| ------------------------------ | ----------------------------------------- | ------------------------------- |
| `DF_AAF_ISSUER_URL`            | AAF issuer URL.                           | `https://rapid.test.aaf.edu.au` |
| `DF_AAF_AUDIENCE_URL`          | Registered application URL.               | Required for AAF                |
| `DF_AAF_CALLBACK_URL`          | API JWT callback URL.                     | Required for AAF                |
| `DF_AAF_IDENTITY_PROVIDER_URL` | Registered identity-provider URL.         | Required for AAF                |
| `DF_AAF_UNIQUE_URL`            | Rapid Connect authentication-request URL. | Required for AAF                |
| `DF_AAF_AUTH_SIGNOUT_URL`      | URL used after sign-out.                  | Unset                           |
| `DF_SECRET_KEY_AAF`            | AAF shared-secret fallback.               | Required for AAF in production  |

#### SAML

| Variable                                  | Purpose                                                     | Default                |
| ----------------------------------------- | ----------------------------------------------------------- | ---------------------- |
| `DF_SAML_METADATA_URL`                    | Identity-provider metadata URL.                             | Unset                  |
| `DF_SAML_METADATA_FILE_PATH`              | Local identity-provider metadata file.                      | Unset                  |
| `DF_SAML_CONSUMER_SERVICE_URL`            | SAML assertion consumer URL.                                | Required for SAML      |
| `DF_SAML_SP_ENTITY_ID`                    | Service-provider entity ID.                                 | Required for SAML      |
| `DF_SAML_IDP_TARGET_URL`                  | Identity-provider login URL.                                | Required for SAML      |
| `DF_SAML_IDP_SIGNOUT_URL`                 | Identity-provider logout URL.                               | Unset                  |
| `DF_SAML_IDP_CERT`                        | Identity-provider certificate when metadata is unavailable. | Conditionally required |
| `DF_SAML_IDP_SAML_NAME_IDENTIFIER_FORMAT` | SAML NameID format.                                         | Email address          |

#### LDAP

| Variable                    | Purpose                                              | Default              |
| --------------------------- | ---------------------------------------------------- | -------------------- |
| `DF_LDAP_HOST`              | LDAP server host.                                    | Required for LDAP    |
| `DF_LDAP_PORT`              | LDAP server port.                                    | LDAP library default |
| `DF_LDAP_ATTRIBUTE`         | LDAP attribute used as the login identifier.         | Required for LDAP    |
| `DF_LDAP_BASE`              | LDAP search base.                                    | Required for LDAP    |
| `DF_LDAP_SSL`               | Enable an encrypted LDAP connection.                 | `false`              |
| `DF_LDAP_USE_ADMIN_TO_BIND` | Bind with an administrator account before searching. | `false`              |
| `DF_LDAP_ADMIN_USER`        | LDAP administrator bind user.                        | Unset                |
| `DF_LDAP_ADMIN_PWD`         | LDAP administrator bind password.                    | Unset                |

#### D2L

| Variable                       | Purpose                                               | Default                        |
| ------------------------------ | ----------------------------------------------------- | ------------------------------ |
| `D2L_ENABLED`                  | Enable D2L integration.                               | `false`                        |
| `D2L_CLIENT_ID`                | D2L OAuth client ID.                                  | Unset                          |
| `D2L_CLIENT_SECRET`            | D2L OAuth client secret.                              | Unset                          |
| `D2L_REDIRECT_URI`             | D2L OAuth callback URL ending in `/api/d2l/callback`. | Unset                          |
| `D2L_API_HOST`                 | Institution D2L API host.                             | Unset                          |
| `D2L_OAUTH_SITE`               | D2L authorization server.                             | `https://auth.brightspace.com` |
| `D2L_OAUTH_SITE_AUTHORIZE_URL` | D2L authorization path.                               | `/oauth2/auth`                 |
| `D2L_OAUTH_SITE_TOKEN_URL`     | D2L token path.                                       | `/core/connect/token`          |

### Email

| Variable                     | Purpose                                  | Default             |
| ---------------------------- | ---------------------------------------- | ------------------- |
| `DF_MAIL_PERFORM_DELIVERIES` | Enable outgoing email delivery.          | Disabled            |
| `DF_MAIL_DELIVERY_METHOD`    | Action Mailer delivery method.           | Deployment-specific |
| `DF_SMTP_ADDRESS`            | SMTP server address.                     | Unset               |
| `DF_SMTP_PORT`               | SMTP server port.                        | Unset               |
| `DF_SMTP_DOMAIN`             | SMTP HELO domain.                        | Unset               |
| `DF_SMTP_USERNAME`           | SMTP username.                           | Unset               |
| `DF_SMTP_PASSWORD`           | SMTP password.                           | Unset               |
| `DF_SMTP_AUTHENTICATION`     | SMTP authentication method.              | Unset               |
| `DF_EMAIL_ERRORS_TO`         | Address receiving PDF-generation errors. | Unset               |

### Integrations and background services

| Variable                         | Purpose                                                         | Default |
| -------------------------------- | --------------------------------------------------------------- | ------- |
| `TII_ENABLED`                    | Enable Turnitin integration.                                    | `false` |
| `TII_INDEX_SUBMISSIONS`          | Index submissions in Turnitin.                                  | `false` |
| `TII_REGISTER_WEBHOOK`           | Register the Turnitin webhook.                                  | `false` |
| `TCA_API_KEY`                    | Turnitin Core API key.                                          | Unset   |
| `TCA_HOST`                       | Turnitin institution host.                                      | Unset   |
| `DF_JPLAG_MIN_TOKENS`            | Minimum matching-token threshold used by JPlag.                 | `-1`    |
| `DF_JPLAG_SKIP_CLUSTER_CHECK`    | Skip JPlag cluster calculation.                                 | `false` |
| `DF_JPLAG_MAX_SHOWN_COMPARISONS` | Maximum comparisons retained in a JPlag report; `-1` means all. | `2500`  |
| `LTI_ENABLED`                    | Enable LTI routes and authentication.                           | `false` |
| `LTI_SHARED_API_SECRET`          | Shared secret between the Rails and LTI APIs.                   | Unset   |
| `MODERATION_SCORE_FACTOR`        | Multiplier applied to moderation score changes.                 | `1.0`   |

### Overseer and container access

| Variable                                             | Purpose                                                       | Default                           |
| ---------------------------------------------------- | ------------------------------------------------------------- | --------------------------------- |
| `OVERSEER_ENABLED`                                   | Enable Overseer assessment services.                          | `false`                           |
| `OVERSEER_WORKDIR_VOLUME_MOUNT`                      | Host directory used for isolated Overseer work.               | Required when Overseer is enabled |
| `OVERSEER_FALLBACK_VOLUME_CONTAINER`                 | Shared-container fallback when a host mount cannot be used.   | Unset                             |
| `OVERSEER_STUDENT_NOTIFICATION_GRACE_PERIOD_MINUTES` | Delay before notifying students of unread failed assessments. | `30`                              |
| `DISK_SPACE_ENDPOINT_ENABLED`                        | Expose host storage availability to Overseer administrators.  | `false`                           |
| `DOCKER_REGISTRY_URL`                                | Registry used for Overseer images.                            | Unset                             |
| `DOCKER_PROXY_URL`                                   | Docker proxy or registry login endpoint.                      | Unset                             |
| `DOCKER_USER`                                        | Docker registry username.                                     | Unset                             |
| `DOCKER_TOKEN`                                       | Docker registry access token.                                 | Unset                             |

### Error reporting

| Variable             | Purpose                                      | Default           |
| -------------------- | -------------------------------------------- | ----------------- |
| `SENTRY_DSN`         | Sentry project data-source name.             | Unset             |
| `SENTRY_ENVIRONMENT` | Environment label attached to Sentry events. | Rails environment |

## Testing

OnTrack aims to follow a
[Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
approach. New or changed models and API endpoints should be accompanied by
tests that describe and verify their expected behaviour.

Run API commands inside the `doubtfire-deploy` Dev Container:

```sh
cd /workspace/doubtfire-api
rails test

# Running an individual test
rails test test/api/settings_test:14 # test_get_config_details
```

Tests are grouped under `test/models`, `test/api`, and `test/helpers`. Shared
test helpers should be placed in `test/helpers`, with helper modules defined
under the `TestHelpers` namespace. List the available maintenance and
development tasks with `rails --tasks`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the GNU Affero General Public License (AGPL) v3.

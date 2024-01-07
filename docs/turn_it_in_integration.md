# Turn It In Integration

This file describes the details needed to work with the Turn It In integration.

## Running

The Turn It In integration requires caching to be enabled. In development you need to run the following to enable or disable caching.

```sh
rails dev:cache
```

To enable, you need to set the following environment variables.

```sh
TII_ENABLED=true
TCA_HOST=https://...
TCA_API_KEY=...
TII_INDEX_SUBMISSIONS=true
```

Ensure that you have sidekiq running to process the turnitin jobs.

```sh
bundle exec sidekiq
```

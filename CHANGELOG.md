## Unreleased

- **Add OAuth client support**: The buildpack now supports Tailscale OAuth clients as an authentication method. OAuth client secrets never expire (unlike traditional auth keys which expire every 90 days), making them the recommended approach for Heroku deployments. When using OAuth clients:
  - Set `TAILSCALE_AUTH_KEY` to your OAuth client secret (starts with `tskey-client-`)
  - Set `TAILSCALE_ADVERTISE_TAGS` to match the tags configured in your OAuth client (required)
  - The buildpack automatically configures `ephemeral=true` and `preauthorized=true` for Heroku's dyno lifecycle
  - Traditional auth keys remain fully supported for backward compatibility
- **Fix**: `TAILSCALE_ADVERTISE_TAGS` now properly passed to `tailscale up` command
- Update README with OAuth client setup instructions
- Upgrade Tailscale (1.76.6)

## 1.1.2

- Remove proxychains.

## 1.1.1 (2023-06-15)

- Swap the `_` character for `-` in the hostname for
  the DYNO environment variable.

## 1.1.0 (2023-06-15)

- Updated the default TAILSCALE_HOSTNAME to be `[commit]-[dyno]-[appname]`.
  This requires [Heroku Labs runtime-dyno-metadata](https://devcenter.heroku.com/articles/dyno-metadata) to be enabled.

## 1.0.1 (2023-06-15)

- Added `TAILSCALE_BUILD_EXCLUDE_START_SCRIPT_FROM_PROFILE_D` build environment variable
  to control when the tailscale script starts.

## 1.0.1 (2023-06-13)

- Updated default tailscale version from 1.40.0 to 1.42.0

## 1.0.0 (2023-05-11)

- Implement buildpack sourcing ideas from
  https://github.com/moneymeets/python-poetry-buildpack,
  https://github.com/heroku/heroku-buildpack-pgbouncer and
  tailscale-docker and tailscale-heroku.
- Move the process to start tailscale into the .profile.d/ script.
- Only start Tailscale when the auth key is present in the environment
  variables.
- Create a `heroku-tailscale-test.sh` script for easier testing/verification.

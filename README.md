# Heroku buildpack to use Tailscale on Heroku

Run [Tailscale](https://tailscale.com/) on a Heroku dyno.

## Usage

### OAuth Clients (Recommended)

OAuth clients are the recommended authentication method because they **never expire**, unlike traditional auth keys which expire every 90 days.

**1. Create an OAuth client in Tailscale:**
   - Go to [Tailscale Admin Console → Settings → OAuth clients](https://login.tailscale.com/admin/settings/oauth)
   - Click "Generate OAuth client"
   - Select the `auth_keys` scope (under "Read" section)
   - Select one or more tags (e.g., `tag:heroku`, `tag:production`)
   - Save the **Client Secret** (starts with `tskey-client-`)

**2. Configure your Heroku app:**

```bash
$ heroku buildpacks:add https://github.com/sundaycarwash/heroku-buildpack-tailscale
$ heroku config:set TAILSCALE_AUTH_KEY="tskey-client-..."
$ heroku config:set TAILSCALE_ADVERTISE_TAGS="tag:heroku"  # Must match tags from OAuth client
```

**Note:** The `TAILSCALE_ADVERTISE_TAGS` must match one of the tags you selected when creating the OAuth client.

### Traditional Auth Keys (Legacy)

You can also use traditional auth keys, but note they expire every 90 days:

```bash
$ heroku buildpacks:add https://github.com/sundaycarwash/heroku-buildpack-tailscale
$ heroku config:set TAILSCALE_AUTH_KEY="tskey-auth-..."
```

### Using the SOCKS5 Proxy

To have your processes connect through the Tailscale proxy, you need to use
the `socks5` proxy provided by `tailscaled`.

```
curl --socks5-hostname localhost:1055 <device-name>
```

```ruby
    TCPSocket.socks_server = "localhost"
    TCPSocket.socks_port = 1055
```

## Testing the integration

To test a connection, you can add the `hello.ts.net` machine into your network.
[Follow the instructions here](https://tailscale.com/kb/1073/hello/?q=testing). You
may need to modify your ACLs to allow access to the test machine. For example, I have
a separate Tailscale token that is tagged with `tag:test`. My ACL looks like:

```json
{
  "hosts": {
    "hello-test": "100.101.102.103"
  },

  // Access control lists.
  "acls": [
    // Only allow the test tag to access anything.
    { "action": "accept", "src": ["tag:test"], "dst": ["hello-test:*"] }
  ]
}
```

To verify the connection works run:

```shell
heroku run -- heroku-tailscale-test.sh
```

You should see curl respond with `<a href="https://hello.ts.net">Found</a>.`

## Configuration

The following settings are available for configuration via environment variables:

- `TAILSCALE_ACCEPT_DNS` - Accept DNS configuration from the admin console. Defaults
  to accepting DNS settings.
- `TAILSCALE_ACCEPT_ROUTES` - Accept subnet routes that other nodes advertise. Defaults
  to accepting subnet routes.
- `TAILSCALE_ADVERTISE_EXIT_NODES` - Offer to be an exit node for outbound internet traffic
  from the Tailscale network. Defaults to not advertising.
- `TAILSCALE_ADVERTISE_TAGS` - Give tagged permissions to this device. You must be listed in
  \"TagOwners\" to be able to apply tags. **Required when using OAuth clients.** Defaults to none
  for traditional auth keys.
- `TAILSCALE_AUTH_KEY` - Provide authentication credentials to automatically authenticate the node.
  **This must be set.** Can be either:
  - **OAuth client secret** (recommended, starts with `tskey-client-`): Never expires. Requires
    `TAILSCALE_ADVERTISE_TAGS` to be set. Automatically configured with `ephemeral=true` and
    `preauthorized=true` for Heroku's dyno lifecycle.
  - **Traditional auth key** (starts with `tskey-auth-`): Expires every 90 days[^1].
- `TAILSCALE_HOSTNAME` - Provide a hostname to use for the device instead of the one provided
  by the OS. Note that this will change the machine name used in MagicDNS. Defaults to the
  hostname of the application (a guid). If you have [Heroku Labs runtime-dyno-metadata](https://devcenter.heroku.com/articles/dyno-metadata)
  enabled, it defaults to `[commit]-[dyno]-[appname]`.
- `TAILSCALE_SHIELDS_UP"` - Block incoming connections from other devices on your Tailscale
  network. Useful for personal devices that only make outgoing connections. Defaults to off.
- `TAILSCALED_VERBOSE` - Controls verbosity for the tailscaled command. Defaults to 0.

The following settings are for the compile process for the buildpack. If you change these, you must
trigger a new build to see the change. Simply changing the environment variables in Heroku will not
cause a rebuild. These are all optional and will default to the latest values.

- `TAILSCALE_VERSION` - The Tailscale package version.

[^1]:
    You want reusable auth keys here because it will be used across all of your dynos
    in the application.

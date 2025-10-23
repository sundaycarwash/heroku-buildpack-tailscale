#!/usr/bin/env bash

. utils.sh

function tailscaled() {
  echo ">>> mocked tailscaled -verbose ${TAILSCALED_VERBOSE:-0} call <<<"
}

export -f tailscaled


function tailscale() {
  # Sleep to allow tailscaled to finish processing in the
  # background and avoid flapping tests.
  sleep 0.01

  # Extract parameters from the command line
  local auth_key=""
  local hostname=""
  local accept_dns=""
  local accept_routes=""
  local advertise_exit_node=""
  local shields_up=""
  local advertise_tags=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --authkey=*) auth_key="${1#*=}" ;;
      --hostname=*) hostname="${1#*=}" ;;
      --accept-dns=*) accept_dns="${1#*=}" ;;
      --accept-routes=*) accept_routes="${1#*=}" ;;
      --advertise-exit-node=*) advertise_exit_node="${1#*=}" ;;
      --shields-up=*) shields_up="${1#*=}" ;;
      --advertise-tags=*) advertise_tags="${1#*=}" ;;
    esac
    shift
  done

  echo ">>> mocked tailscale call
--authkey=${auth_key}
--hostname=${hostname}
--accept-dns=${accept_dns}
--accept-routes=${accept_routes}
--advertise-exit-node=${advertise_exit_node}
--shields-up=${shields_up}${advertise_tags:+
--advertise-tags=${advertise_tags}}
<<<"
}

export -f tailscale


# Test 1: Basic sanity test with traditional auth key
run_test sanity heroku-tailscale-start.sh

# Test 2: Traditional auth key with all env vars
TAILSCALED_VERBOSE=1 \
  TAILSCALE_AUTH_KEY="tskey-auth-test" \
  TAILSCALE_HOSTNAME="test-host" \
  TAILSCALE_ACCEPT_DNS="false" \
  TAILSCALE_ACCEPT_ROUTES="false" \
  TAILSCALE_ADVERTISE_EXIT_NODE="true" \
  TAILSCALE_SHIELDS_UP="true" \
  run_test envs heroku-tailscale-start.sh

# Test 3: Traditional auth key with hostname generation
TAILSCALED_VERBOSE=1 \
  TAILSCALE_AUTH_KEY="tskey-auth-test" \
  HEROKU_APP_NAME="heroku-app" \
  DYNO="another_web.1" \
  HEROKU_SLUG_COMMIT="hunter20123456789"\
  TAILSCALE_ACCEPT_DNS="false" \
  TAILSCALE_ACCEPT_ROUTES="false" \
  TAILSCALE_ADVERTISE_EXIT_NODE="true" \
  TAILSCALE_SHIELDS_UP="true" \
  run_test hostname heroku-tailscale-start.sh

# Test 4: OAuth client with tags (should succeed)
TAILSCALED_VERBOSE=1 \
  TAILSCALE_AUTH_KEY="tskey-client-oauth-test" \
  TAILSCALE_ADVERTISE_TAGS="tag:heroku" \
  TAILSCALE_HOSTNAME="oauth-test" \
  TAILSCALE_ACCEPT_DNS="false" \
  TAILSCALE_ACCEPT_ROUTES="false" \
  TAILSCALE_ADVERTISE_EXIT_NODE="false" \
  TAILSCALE_SHIELDS_UP="false" \
  run_test oauth-with-tags heroku-tailscale-start.sh
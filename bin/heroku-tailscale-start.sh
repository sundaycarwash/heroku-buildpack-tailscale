#!/usr/bin/env bash

set -e

function log() {
  echo "-----> $*"
}

function indent() {
  sed -e 's/^/       /'
}

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  log "Skipping Tailscale"

else
  log "Starting Tailscale"

  # Detect if using OAuth client secret (starts with tskey-client-)
  if [[ "$TAILSCALE_AUTH_KEY" == tskey-client-* ]]; then
    log "Detected OAuth client secret"

    # OAuth clients require tags to be set
    if [ -z "$TAILSCALE_ADVERTISE_TAGS" ]; then
      log "ERROR: TAILSCALE_ADVERTISE_TAGS must be set when using OAuth client authentication"
      log "OAuth clients require tags. Set TAILSCALE_ADVERTISE_TAGS to match the tags configured in your OAuth client."
      exit 1
    fi

    # Append OAuth parameters for Heroku dyno environment
    # ephemeral=true: Auto-remove nodes when dynos stop (keeps node list clean)
    # preauthorized=true: Skip manual approval (required for automation)
    auth_key="${TAILSCALE_AUTH_KEY}?ephemeral=true&preauthorized=true"
    log "Using OAuth client with ephemeral=true and preauthorized=true"
  else
    log "Using traditional auth key"
    auth_key="${TAILSCALE_AUTH_KEY}"
  fi

  # Only use the first 8 characters of the commit sha.
  # Swap the . and _ in the dyno with a - since tailscale doesn't
  # allow for periods.
  DYNO=${DYNO//./-}
  DYNO=${DYNO//_/-}

  if [ -z "$TAILSCALE_HOSTNAME" ]; then
    if [ -z "$HEROKU_APP_NAME" ]; then
      tailscale_hostname=$(hostname)
    else
      tailscale_hostname=${HEROKU_SLUG_COMMIT:0:8}"-$DYNO-$HEROKU_APP_NAME"
    fi
  else
    tailscale_hostname="$TAILSCALE_HOSTNAME-$HEROKU_RELEASE_VERSION-$DYNO"
  fi
  log "Using Tailscale hostname=$tailscale_hostname"

  # Build the advertise-tags parameter if set
  if [ -n "$TAILSCALE_ADVERTISE_TAGS" ]; then
    advertise_tags="--advertise-tags=${TAILSCALE_ADVERTISE_TAGS}"
  else
    advertise_tags=""
  fi

  tailscaled -verbose ${TAILSCALED_VERBOSE:-0} --tun=userspace-networking --socks5-server=localhost:1055 &

  # Retry configuration
  max_retries=6  # 6 attempts * 5 seconds = 30 seconds max wait time
  retry_count=0

  while true; do
    # Try to start Tailscale
    # On success, tailscale up returns 0 and we break out of the loop
    # On failure, we capture the output for error detection
    set +e  # Temporarily disable exit on error
    tailscale up \
      --authkey=${auth_key} \
      --hostname="$tailscale_hostname" \
      --accept-dns=${TAILSCALE_ACCEPT_DNS:-true} \
      --accept-routes=${TAILSCALE_ACCEPT_ROUTES:-true} \
      --advertise-exit-node=${TAILSCALE_ADVERTISE_EXIT_NODE:-false} \
      --shields-up=${TAILSCALE_SHIELDS_UP:-false} \
      ${advertise_tags} 2>&1 | tee /tmp/tailscale-up-output.log
    exit_code=$?
    set -e  # Re-enable exit on error

    if [ $exit_code -eq 0 ]; then
      # Success!
      break
    fi

    # Failed - check for permanent authentication errors
    if grep -qi "invalid key" /tmp/tailscale-up-output.log 2>/dev/null; then
      log "ERROR: Authentication failed - invalid or expired auth key"
      log "The auth key may have expired (traditional keys expire after 90 days) or been revoked."
      log "Please generate a new auth key or OAuth client secret and update TAILSCALE_AUTH_KEY."
      exit 1
    fi

    # Increment retry counter
    retry_count=$((retry_count + 1))

    # Check if we've exceeded max retries
    if [ $retry_count -ge $max_retries ]; then
      log "ERROR: Tailscale failed to start after $max_retries attempts ($(($max_retries * 5)) seconds)"
      log "Last error output:"
      cat /tmp/tailscale-up-output.log 2>/dev/null | indent || true
      exit 1
    fi

    # Wait before retrying
    log "Waiting for 5s for Tailscale to start (attempt $retry_count/$max_retries)"
    sleep 5
  done

  log "Tailscale started"
fi

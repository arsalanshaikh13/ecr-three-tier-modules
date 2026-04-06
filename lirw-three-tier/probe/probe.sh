#!/usr/bin/env sh
set -eu

log() {
  printf '[probe] %s\n' "$1"
}

check_url() {
  NAME="$1"
  URL="$2"

  log "Checking ${NAME}: ${URL}"

  BODY_FILE="$(mktemp)"
  HTTP_CODE="$(curl -sS -L -o "$BODY_FILE" -w "%{http_code}" "$URL" || true)"

  log "${NAME} returned HTTP ${HTTP_CODE}"

  if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    log "${NAME} failed. Response body follows:"
    cat "$BODY_FILE"
    rm -f "$BODY_FILE"
    # Fail only the current probe attempt so the outer retry loop can decide whether
    # the service is still warming up or has actually exhausted the retry window.
    return 1
  fi

  log "${NAME} succeeded. Response body follows:"
  cat "$BODY_FILE"
  rm -f "$BODY_FILE"
  return 0
}

# These environment variables should be injected by the ECS task definition so the
# same probe image can be reused across dev and prod.
: "${FRONTEND_URL:?FRONTEND_URL must be set}"
: "${BACKEND_URL:?BACKEND_URL must be set}"

# Grace period and retry controls keep the probe from failing too early while a
# freshly deployed revision is still pulling images, booting, or registering in the target group.
INITIAL_DELAY_SECONDS="${INITIAL_DELAY_SECONDS:-60}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-10}"
SLEEP_SECONDS="${SLEEP_SECONDS:-30}"

log "Starting smoke probe"
log "Initial delay: ${INITIAL_DELAY_SECONDS}s | Max attempts: ${MAX_ATTEMPTS} | Sleep between attempts: ${SLEEP_SECONDS}s"

# Give the newly deployed service a short warm-up window before the first deep check.
sleep "$INITIAL_DELAY_SECONDS"

run_probe_sequence() {
  # Frontend is the public entrypoint, so this validates the user-facing path.
  check_url "frontend" "${FRONTEND_URL}" || return 1

  # Readiness should verify backend -> DB connectivity rather than just process liveness.
  check_url "backend readiness" "${BACKEND_URL}/readyz" || return 1

  # This is the deeper smoke test: it forces a real backend path that should query the DB.
  # If this fails while /readyz succeeds, the backend process is alive but the real data path is broken.
  check_url "authors api" "${BACKEND_URL}/api/authors" || return 1

  return 0
}

ATTEMPT=1
while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
  log "Probe attempt ${ATTEMPT}/${MAX_ATTEMPTS}"

  if run_probe_sequence; then
    log "All smoke probes passed"
    exit 0
  fi

  if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
    # Retry rather than failing immediately so temporary warm-up errors do not trigger false rollbacks.
    log "Probe attempt ${ATTEMPT} failed. Waiting ${SLEEP_SECONDS}s before retry."
    sleep "$SLEEP_SECONDS"
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

log "Probe failed after ${MAX_ATTEMPTS} attempts"
exit 1

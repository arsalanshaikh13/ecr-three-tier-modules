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
    exit 1
  fi

  log "${NAME} succeeded. Response body follows:"
  cat "$BODY_FILE"
  rm -f "$BODY_FILE"
}

# These environment variables should be injected by the ECS task definition so the
# same probe image can be reused across dev and prod.
: "${FRONTEND_URL:?FRONTEND_URL must be set}"
: "${BACKEND_URL:?BACKEND_URL must be set}"

log "Starting smoke probe"

# Frontend is the public entrypoint, so this validates the user-facing path.
check_url "frontend" "${FRONTEND_URL}"

# Readiness should verify backend -> DB connectivity rather than just process liveness.
check_url "backend readiness" "${BACKEND_URL}/readyz"

# This is the deeper smoke test: it forces a real backend path that should query the DB.
# If this fails while /readyz succeeds, the backend process is alive but the real data path is broken.
check_url "authors api" "${BACKEND_URL}/api/authors"

log "All smoke probes passed"

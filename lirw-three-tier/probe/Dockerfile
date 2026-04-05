FROM alpine:3.20

# curl is enough for lightweight HTTP smoke tests and keeps the probe image small.
RUN apk add --no-cache curl

WORKDIR /app

COPY probe.sh /app/probe.sh

RUN chmod +x /app/probe.sh

# The ECS task definition will inject FRONTEND_URL and BACKEND_URL per environment.
CMD ["/app/probe.sh"]

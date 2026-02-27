ARG BUILD_FROM=ghcr.io/home-assistant/base:3.19
FROM $BUILD_FROM

RUN apk add --no-cache python3

COPY run.sh /run.sh
COPY subscriber.py /subscriber.py
RUN chmod +x /run.sh

LABEL \
  io.hass.name="Music Assistant Provider Subscriber" \
  io.hass.description="Subscribe third-party GitHub provider repos and auto-update to /share/music_assistant/custom_providers." \
  io.hass.type="addon" \
  io.hass.version="0.1.0"

ENTRYPOINT ["/run.sh"]

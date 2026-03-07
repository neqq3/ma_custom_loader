ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache python3 ca-certificates git

COPY run.sh /run.sh
COPY subscriber.py /subscriber.py
RUN chmod +x /run.sh

LABEL \
  io.hass.name="Music Assistant Provider Subscriber" \
  io.hass.description="Subscribe third-party GitHub provider repos and auto-update to /share/music_assistant/custom_providers." \
  io.hass.type="addon" \
  io.hass.version="0.2.0"

ENTRYPOINT ["/run.sh"]



ARG BUILD_FROM=ghcr.io/music-assistant/server:2.7.10
FROM $BUILD_FROM

# Copy the startup script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Label the image
LABEL \
  io.hass.name="Music Assistant (Customizable) (BETA)" \
  io.hass.description="BETA channel for Music Assistant custom loader features." \
  io.hass.type="addon" \
  io.hass.version="2.7.10-beta.3"

# Set the entrypoint to our script
ENTRYPOINT ["/run.sh"]

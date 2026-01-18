ARG BUILD_FROM=ghcr.io/music-assistant/server:stable
FROM $BUILD_FROM

# Copy the startup script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Label the image
LABEL \
  io.hass.name="Music Assistant (Customizable)" \
  io.hass.description="Official Music Assistant with support for loading custom plugins from /share." \
  io.hass.type="addon" \
  io.hass.version="2.0.0"

# Set the entrypoint to our script
ENTRYPOINT ["/run.sh"]

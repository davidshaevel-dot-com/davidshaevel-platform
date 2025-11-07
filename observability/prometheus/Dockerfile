# Prometheus Dockerfile for DavidShaevel.com Platform
# Custom Prometheus image with pre-loaded configuration

# Use official Prometheus base image
FROM prom/prometheus:v2.48.1

# Add metadata labels
LABEL maintainer="David Shaevel <david@davidshaevel.com>"
LABEL description="Prometheus metrics collector for DavidShaevel.com platform"
LABEL version="1.0.0"

# Copy custom Prometheus configuration
COPY prometheus.yml /etc/prometheus/prometheus.yml

# Expose Prometheus port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/-/healthy || exit 1

# Run Prometheus with custom configuration
# Data will be stored in /prometheus (mounted from EFS)
CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
      "--storage.tsdb.path=/prometheus", \
      "--storage.tsdb.retention.time=15d", \
      "--web.console.libraries=/usr/share/prometheus/console_libraries", \
      "--web.console.templates=/usr/share/prometheus/consoles", \
      "--web.enable-lifecycle" ]

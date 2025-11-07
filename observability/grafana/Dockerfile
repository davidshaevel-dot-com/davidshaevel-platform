# Grafana Dockerfile for DavidShaevel.com Platform
# Grafana image with pre-configured dashboards and provisioning

# Use official Grafana base image
FROM grafana/grafana:10.2.3

# Add metadata labels
LABEL maintainer="David Shaevel <david@davidshaevel.com>"
LABEL description="Grafana dashboards for DavidShaevel.com platform observability"
LABEL version="1.0.0"

# Copy provisioning configuration with proper ownership
# Using --chown flag reduces image layers compared to separate RUN chown command
COPY --chown=grafana:grafana provisioning/datasources/ /etc/grafana/provisioning/datasources/
COPY --chown=grafana:grafana provisioning/dashboards/ /etc/grafana/provisioning/dashboards/
COPY --chown=grafana:grafana provisioning/dashboard-definitions/ /etc/grafana/provisioning/dashboard-definitions/

# Ensure running as grafana user for security
USER grafana

# Expose Grafana port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Grafana will use default entrypoint
# Data will be stored in /var/lib/grafana (mounted from EFS)

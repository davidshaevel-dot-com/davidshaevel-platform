# Prometheus Configuration for DavidShaevel.com Platform
# This configuration defines how Prometheus scrapes metrics from the platform services
#
# TEMPLATE VARIABLES (populated by Terraform):
#   - environment: Target environment (dev, staging, prod)
#   - service_prefix: Cloud Map service name prefix (e.g., dev-davidshaevel)

global:
  scrape_interval: 15s      # Scrape metrics every 15 seconds
  evaluation_interval: 15s  # Evaluate alerting rules every 15 seconds
  external_labels:
    environment: '${environment}'
    platform: 'davidshaevel'

# Scrape configuration for all services
scrape_configs:
  # Backend API metrics
  - job_name: 'backend'
    metrics_path: '/api/metrics'
    dns_sd_configs:
      - names:
          - '${service_prefix}-backend.davidshaevel.local'
        type: 'SRV'
    relabel_configs:
      - source_labels: [job]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'nodejs_.*|backend_.*'
        action: keep

  # Frontend application metrics
  - job_name: 'frontend'
    metrics_path: '/metrics'
    dns_sd_configs:
      - names:
          - '${service_prefix}-frontend.davidshaevel.local'
        type: 'SRV'
    relabel_configs:
      - source_labels: [job]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'nodejs_.*|frontend_.*'
        action: keep

  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    relabel_configs:
      - source_labels: [job]
        target_label: service

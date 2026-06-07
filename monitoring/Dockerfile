# Prometheus image with LKS 2026 configuration baked in
# Deployed to ECR us-west-2 and run in lks-monitoring-vpc (Oregon)
FROM prom/prometheus:latest

# Copy our scrape config and alert rules into the image
# This means the config is versioned in Git and deployed via CI/CD
COPY prometheus/prometheus.yml /etc/prometheus/prometheus.yml
COPY prometheus/rules/          /etc/prometheus/rules/

# Prometheus listens on 9090
EXPOSE 9090

# Default entrypoint from base image starts Prometheus with the config above
CMD [ \
  "--config.file=/etc/prometheus/prometheus.yml", \
  "--storage.tsdb.retention.time=7d", \
  "--web.enable-lifecycle" \
]

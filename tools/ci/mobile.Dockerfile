# SOT: FLUTTER_VERSION comes from apps/mobile/pubspec.yaml `environment.flutter`
# via docker-compose.ci.yml build.args.
# Do NOT hardcode the version here — it must track the SOT file.
ARG FLUTTER_VERSION=3.41.9
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION}

# Dart SDK is bundled with the Flutter image — do NOT pin Dart separately.
# flutter test runs on the Dart VM (headless-safe; no device required).
#
# Node + npm are required so `npm run mobile:*` root scripts can be called
# (the scripts themselves shell out to flutter/dart; npm is just the runner).
# We install the LTS node via NodeSource rather than apt's stale package.
ARG NODE_VERSION=22
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash", "-c", "echo 'mobile-gates: use docker compose run, not docker compose up'"]

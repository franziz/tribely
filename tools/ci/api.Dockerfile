# SOT: NODE_VERSION comes from .nvmrc via docker-compose.ci.yml build.args.
# Do NOT hardcode the version here — it must track the SOT file.
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm

WORKDIR /workspace

# node_modules is mounted as a named volume from compose to avoid osxfs thrash.
# The volume is populated by `npm ci` inside the container.

CMD ["bash", "-c", "echo 'api-gates: use docker compose run, not docker compose up'"]

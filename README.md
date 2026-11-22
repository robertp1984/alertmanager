# alertmanager

Prometheus AlertManager with support for configuration templates.

A Docker image of [Prometheus Alertmanager](https://github.com/prometheus/alertmanager) built on
`debian:trixie-slim` and published to Docker Hub as
[`robertp22/alertmanager`](https://hub.docker.com/r/robertp22/alertmanager).

On startup the entrypoint renders every `*.tpl` file in `/etc/alertmanager` with `envsubst`
(e.g. `alertmanager.yml.tpl` → `alertmanager.yml`), replacing `${VAR}` placeholders with
environment variables. This lets you keep secrets such as Slack webhook URLs or API keys out of the
config file. Alertmanager is then started with:

```
--config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager
```

## Image tags

| Tag       | Description                                   |
|-----------|-----------------------------------------------|
| `latest`  | Latest build from the `main` branch           |
| `0.35.0`  | Alertmanager version (from `ARG VERSION` in `alertmanager/Dockerfile`) |

## Usage

### Run with the default config

```sh
docker run -d --name alertmanager -p 9093:9093 robertp22/alertmanager:0.35.0
```

The AlertManager UI is available at standard URL http://localhost:9093.

### Run with a config template

1. Create `alertmanager.yml.tpl` with placeholders for environment variables:

   ```yaml
   route:
     receiver: slack

   receivers:
     - name: slack
       slack_configs:
         - api_url: ${SLACK_WEBHOOK_URL}
           channel: '#alerts'
   ```

2. Mount it into `/etc/alertmanager/` and pass the variables:

   ```sh
   docker run -d --name alertmanager -p 9093:9093 \
     -v "$(pwd)/alertmanager.yml.tpl:/etc/alertmanager/alertmanager.yml.tpl:ro" \
     -e SLACK_WEBHOOK_URL=https://hooks.slack.com/services/SECRET-URL \
     robertp22/alertmanager:0.35.0
   ```

   The container logs `Converted file: /etc/alertmanager/alertmanager.yml.tpl` and starts with the
   rendered `alertmanager.yml`.

> Mount individual files, not the whole `/etc/alertmanager` directory. The container runs as
> `nobody` and must be able to write the rendered files there.

### Run with a plain config

```sh
docker run -d --name alertmanager -p 9093:9093 \
  -v "$(pwd)/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro" \
  robertp22/alertmanager:0.35.0
```

## Build locally

With Docker Compose:

```sh
docker compose build
```

Or with plain Docker:

```sh
docker build --build-arg VERSION=0.35.0 -t robertp22/alertmanager:0.35.0 ./alertmanager
```

## Upgrading Alertmanager

1. Change `ARG VERSION` in `alertmanager/Dockerfile`.
2. Update the tag and `VERSION` arg in `compose.yaml` (for local testing only).
3. Push to `main`. CI builds and publishes the new version tag.

## CI/CD

The GitHub Actions workflow  runs on every push to `main` and:
- reads the version from `alertmanager/Dockerfile`,
- builds the image and pushes `latest` and `<version>` tags to Docker Hub,

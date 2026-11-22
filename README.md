# alertmanager

Prometheus AlertManager with support for configuration templates.

A Docker image of [Prometheus Alertmanager](https://github.com/prometheus/alertmanager) built on
`debian:trixie-slim` and published to Docker Hub as
[`robertp22/alertmanager`](https://hub.docker.com/r/robertp22/alertmanager).

On startup the entrypoint copies the template directory `/etc/alertmanager.tpl` recursively to
`/etc/alertmanager`:

- `*.tpl` files are rendered with `envsubst` (e.g. `alertmanager.yml.tpl` → `alertmanager.yml`),
  replacing `${VAR}` placeholders with environment variables and secrets from the optional secrets
  file (`/secrets`),
- all other files (e.g. notification templates `*.tmpl`) are copied unchanged.

This lets you keep secrets such as Slack webhook URLs or API keys out of the config files.
Alertmanager is then started with:

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

### Run with config templates and secrets

1. Create a template directory, e.g. `config/`, with `alertmanager.yml.tpl` using placeholders:

   ```yaml
   route:
     receiver: slack

   receivers:
     - name: slack
       slack_configs:
         - api_url: ${SLACK_WEBHOOK_URL}
           channel: '#alerts'
   ```

   Subdirectories and other files (e.g. `templates/slack.tmpl`) are copied as they are.

2. Create a secrets file, e.g. `secrets`, **outside** the template directory:

   ```
   # Slack
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/SECRET-URL
   ```

3. Mount both and run:

   ```sh
   docker run -d --name alertmanager -p 9093:9093 \
     -v "$(pwd)/config:/etc/alertmanager.tpl:ro" \
     -v "$(pwd)/secrets:/secrets:ro" \
     robertp22/alertmanager:0.35.0
   ```

   The container logs `Loading secret from file with key=SLACK_WEBHOOK_URL` and
   `Rendered: alertmanager.yml.tpl -> alertmanager.yml`, then starts with the rendered config.


Instead of a secrets file you can pass variables with `-e`, e.g.
`-e SLACK_WEBHOOK_URL=https://hooks.slack.com/services/SECRET-URL`.

> Keep the secrets file out of the template directory, otherwise it is copied to
> `/etc/alertmanager` like any other file.

| Variable       | Default                 | Description                      |
|----------------|-------------------------|----------------------------------|
| `TPL_DIR`      | `/etc/alertmanager.tpl` | Template directory               |
| `CONF_DIR`     | `/etc/alertmanager`     | Rendered configuration directory |
| `SECRETS_FILE` | `/secrets`              | Secrets file                     |

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

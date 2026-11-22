#!/usr/bin/env sh
set -eu

TPL_DIR="${TPL_DIR:-/etc/alertmanager.tpl}"
CONF_DIR="${CONF_DIR:-/etc/alertmanager}"
SECRETS_FILE="${SECRETS_FILE:-/secrets}"

# Load secrets KEY=VALUE from file to environment
load_secrets() {
    if [ ! -s "${SECRETS_FILE}" ]; then
        echo "No secrets file or empty: ${SECRETS_FILE}"
        return 0
    fi

    while IFS= read -r line || [ -n "${line}" ]; do
        # Convert CRLF to LF
        line=$(printf '%s' "${line}" | tr -d '\r')
        # Skip empty lines or comment lines
        case "${line}" in
            ''|'#'*) continue ;;
        esac

        # Extract and validate key
        key="${line%%=*}"
        case "${key}" in
            "${line}"|''|[0-9]*|*[!A-Za-z0-9_]*)
                echo "Skipping invalid line in ${SECRETS_FILE}" >&2
                continue
                ;;
        esac

        # Export the secret to environment
        export "${line}"
        echo "Loading secret from file with key=${key}"
    done < "${SECRETS_FILE}"
}

# Copy TPL_DIR to CONF_DIR recursively; render *.tpl files with envsubst.
render_templates() {
    if [ ! -d "${TPL_DIR}" ]; then
        echo "No template directory: ${TPL_DIR}, skipping"
        return 0
    fi
    find "${TPL_DIR}" -type f ! -path "${SECRETS_FILE}" | while IFS= read -r src; do
        rel=${src#"${TPL_DIR}"/}
        dst="${CONF_DIR}/${rel}"
        mkdir -p "$(dirname "${dst}")"
        case "${src}" in
            *.tpl)
                envsubst < "${src}" > "${dst%.tpl}"
                echo "Rendered: ${rel} -> ${rel%.tpl}"
                ;;
            *)
                cp "${src}" "${dst}"
                echo "Copied: ${rel}"
                ;;
        esac
    done
}

# Load in separate shell so that the environment loaded from SECRETS_FILE does not leak outside
(
    load_secrets
    render_templates
)

# Run AlertManager
exec /bin/alertmanager --config.file="${CONF_DIR}/alertmanager.yml" --storage.path=/alertmanager  "$@"


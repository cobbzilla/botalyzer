#!/bin/sh

DOMAIN="${1:?no domain provided}"

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/botalyzer.env"
if [ ! -f "${ENV_FILE}" ] ; then
  echo 1>&2 "No ${ENV_FILE} found"
  exit 1
fi

. "${ENV_FILE}"

SERVICE_GET_URL="${2:-${SERVICE_GET_URL:?no GET request URL provided and no SERVICE_GET_URL env var defined}}"
SERVICE_POST_URL="${3:-${SERVICE_POST_URL:?no POST request URL provided and no SERVICE_POST_URL env var defined}}"
SERVICE_POST_DATA="${4:-${SERVICE_POST_DATA:?no POST data provided and no SERVICE_POST_DATA env var defined}}"

SERVICE_PROTO="$(echo "${SERVICE_GET_URL}" | awk -F '://' '{print $1}')"
SERVICE_HOSTNAME="$(echo "${SERVICE_GET_URL}" | awk -F '://' '{print $2}' | awk -F '/' '{print $1}')"
SERVICE_ORIGIN="${SERVICE_PROTO}://${SERVICE_HOSTNAME}"

COOKIE_JAR="$(mktemp "/tmp/$(basename "${0}").cookies.XXXXXXX")"

curl "${SERVICE_GET_URL}" --silent --compressed \
  --cookie-jar "${COOKIE_JAR}" \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:102.0) Gecko/20100101 Firefox/102.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate, br' \
  -H 'DNT: 1' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: none' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Sec-GPC: 1' > /dev/null

COOKIE_NAME="$(tail -1 "${COOKIE_JAR}" | awk '{print $6}')"
COOKIE_VALUE="$(tail -1 "${COOKIE_JAR}" | awk '{print $7}')"

if [ -z "${COOKIE_VALUE}" ] ; then
  echo 1>&2 "No cookie found"
  exit 1
fi

POST_DATA="$(echo "${SERVICE_POST_DATA}" | sed -e "s/@@COOKIE@@/${COOKIE_VALUE}/g" | sed -e "s/@@DOMAIN@@/${DOMAIN}/g")"

curl "${SERVICE_POST_URL}" -v --compressed -X POST \
  --cookie-jar "${COOKIE_JAR}" \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:102.0) Gecko/20100101 Firefox/102.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate, br' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H "Origin: ${SERVICE_ORIGIN}" \
  -H 'DNT: 1' \
  -H 'Connection: keep-alive' \
  -H "Referer: ${SERVICE_GET_URL}" \
  -H "Cookie: ${COOKIE_NAME}=${COOKIE_VALUE}" \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Sec-GPC: 1' --data-raw "${POST_DATA}" \
| tee /tmp/dns-post-out.txt | grep -oi "[A-Z.]*${DOMAIN}" | grep -v "^.${DOMAIN}" | sort | uniq

rm -f "${COOKIE_JAR}"

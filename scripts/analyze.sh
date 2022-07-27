#!/bin/sh
#
# Usage:
#
#   analyze.sh <domain> [cache-dir]
#
#    domain    : domain name to analyze
#    cache-dir : optional cache directory to use. default is under /tmp
#
# This script does 3 things:
#  * Enumerate subdomains for the given domain
#  * For each subdomain, try to get a robots.txt file for it
#  * Run the analyze.py script to create a JSON summary of the robots.txt files
#

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

DOMAIN=${1:?no domain provided}
SUBDOMAIN_CACHE="${2:-/tmp/"$(basename "${0}").cache"}"
mkdir -p "${SUBDOMAIN_CACHE}"

fetch_curl () {
  URL="${1:?no URL provided}"
  OUTFILE="${2:?no output file provided}"
  curl "${URL}" --silent --insecure --compressed \
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
    -H 'Sec-GPC: 1' > "${OUTFILE}"
  echo $?
}

fetch_robots () {
  SUBDOMAIN="${1:?no subdomain provided}"
  OUTFILE="${DOMAIN_RESULTS_DIR}/${SUBDOMAIN}/robots.txt"
  mkdir -p "$(dirname "${OUTFILE}")"

  echo 1>&2 "Fetching robots.txt for ${SUBDOMAIN} over https"
  CURL_EXIT=$(fetch_curl "https://${SUBDOMAIN}/robots.txt" "${OUTFILE}")
  echo 1>&2 "Fetching robots.txt for ${SUBDOMAIN} over https: result was ${CURL_EXIT}"
  if [ ${CURL_EXIT} -ne 0 ] ; then
    echo 1>&2 "Fetching robots.txt for ${SUBDOMAIN} over plain old http"
    CURL_EXIT=$(fetch_curl "http://${SUBDOMAIN}/robots.txt" "${OUTFILE}")
    if [ ${CURL_EXIT} -ne 0 ] ; then
      echo 1>&2 "Error fetching robots.txt for ${SUBDOMAIN}"
    fi
  fi
}

# Enumerate subdomains
SUBDOMAIN_LIST="${SUBDOMAIN_CACHE}/${DOMAIN}.subdomain_list"
if [ ! -f "${SUBDOMAIN_LIST}" ] || [ ! -s "${SUBDOMAIN_LIST}" ] ; then
  "${SCRIPT_DIR}/enumerate.sh" "${DOMAIN}" > "${SUBDOMAIN_LIST}"
fi

# Fetch robots.txt for each subdomain
DOMAIN_RESULTS_DIR="${SUBDOMAIN_CACHE}/${DOMAIN}.robots"
while read -r subdomain ; do
  if [ -n "${subdomain}" ] ; then
    fetch_robots "${subdomain}"
  fi
done < "${SUBDOMAIN_LIST}"

# Perform analysis and generate JSON summary
"${SCRIPT_DIR}/analyze.py" "${DOMAIN_RESULTS_DIR}"

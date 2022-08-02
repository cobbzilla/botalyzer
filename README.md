Robots Analyzer
===============

Given a domain name, this tool will:
 * Discover subdomains
 * Look for a robots.txt file on each subdomain
 * Generate some analytics on the contents of the robots.txt files

# Setup

 * In the `scripts` directory, copy the `botalyzer.example.env` to `botalyzer.env`
 * Edit this file with the settings for your preferred DNS service

# Command Line Usage

    ./scripts/analyze.sh <domain>

# Node Express App

First build the docker image:

    npm run docker-build

Then run the docker container:

    npm run docker-run

To generate the JSON summary for a domain, request the URL `http://127.0.0.1:3000/example.com`

For example:

    curl http://127.0.0.1:3000/example.com


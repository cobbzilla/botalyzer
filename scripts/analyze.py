#!/usr/bin/env python3

__author__ = "Jonathan Cobb"
__copyright__ = "Copyright 2022, Jonathan Cobb"
__credits__ = ["Jonathan Cobb"]
__license__ = "Apache"
__version__ = "1.0.1"
__maintainer__ = "Jonathan Cobb"
__email__ = "jonathan@kyuss.org"
__status__ = "Development"

import base64
import json
import os
import sys

ANALYZER_USAGE = """
    Usage: analyze.py <directory>
    
    Within directory, each subdirectory must be the name of a subdomain.
    Within each subdomain subdirectory should be a robots.txt file for that domain
    
    This script is usually called by analyze.sh, which has already created the
    expected directory structure by discovering subdomains and populating various
    robots.txt files in subdirectories. 
"""

ROBOTS_TXT = 'robots.txt'
PREFIX_USERAGENT = 'User-agent:'
PREFIX_DISALLOW = 'Disallow:'
WILDCARD_USER_AGENT = '*'


class RobotsTxt:
    def __init__(self, robots_txt_file):
        self.subdomain = os.path.basename(os.path.dirname(robots_txt_file))
        self.paths = {}
        with open(robots_txt_file, 'r') as file:
            self.base64 = base64.b64encode(file.read().encode('UTF-8')).decode('UTF-8')

        user_agent = None
        with open(robots_txt_file) as robots_txt:
            for line in robots_txt.readlines():
                if RobotsTxt.is_user_agent(line):
                    user_agent = RobotsTxt.extract_user_agent(line)
                    self.paths[user_agent] = []
                elif RobotsTxt.is_disallow(line):
                    if user_agent is None:
                        print("Warning: found Disallow line before any User-agent: "+line, file=sys.stderr)
                    else:
                        self.paths[user_agent].append(RobotsTxt.extract_disallow(line))
                elif len(line.strip()):
                    print("skipping non-matching line: "+line, file=sys.stderr)

    @staticmethod
    def line_match(line, match):
        return line.strip().lower().startswith(match.lower())

    @staticmethod
    def is_user_agent(line):
        return RobotsTxt.line_match(line, PREFIX_USERAGENT)

    @staticmethod
    def is_disallow(line):
        return RobotsTxt.line_match(line, PREFIX_DISALLOW)

    @staticmethod
    def extract_value(line, prefix):
        return line.strip()[len(prefix):].strip()

    @staticmethod
    def extract_user_agent(line):
        return RobotsTxt.extract_value(line, PREFIX_USERAGENT)

    @staticmethod
    def extract_disallow(line):
        return RobotsTxt.extract_value(line, PREFIX_DISALLOW)

    def __str__(self):
        print("subdomain: "+self.subdomain)
        print("clauses: \n" + str(self.paths))


class RobotsSummary:
    def __init__(self, robots):
        # list of all subdomains discovered
        self.subdomains = []

        # list of all subdomains with robots.txt, and their robots.txt file, base64-encoded
        self.subdomains_with_robots = {}

        # list of subdomains that block all bots
        self.fully_blocked_subdomains = []

        # dictionary of bot->list of domains
        self.fully_blocked_bots = {}

        # dictionary of bot->list of domains
        self.partially_blocked_bots = {}

        # dictionary of path->list of domains
        self.fully_blocked_paths = {}

        for robots_txt in robots:
            subdomain = robots_txt.subdomain
            self.subdomains.append(subdomain)
            is_valid_robots_file = False
            for user_agent, paths in robots_txt.paths.items():
                is_valid_robots_file = True
                if user_agent == WILDCARD_USER_AGENT:
                    if len(paths) == 1 and paths[0] == '/':
                        self.fully_blocked_subdomains.append(subdomain)
                    else:
                        for path in paths:
                            if path not in self.fully_blocked_paths:
                                self.fully_blocked_paths[path] = []
                            self.fully_blocked_paths[path].append(subdomain)

                elif len(paths) == 1 and paths[0] == '/':
                    if user_agent not in self.fully_blocked_bots:
                        self.fully_blocked_bots[user_agent] = []
                    self.fully_blocked_bots[user_agent].append(subdomain)

                else:
                    if user_agent not in self.partially_blocked_bots:
                        self.partially_blocked_bots[user_agent] = []
                    self.partially_blocked_bots[user_agent].append(subdomain)
            if is_valid_robots_file:
                self.subdomains_with_robots[subdomain] = robots_txt.base64


def main():
    if len(sys.argv) != 2:
        print(ANALYZER_USAGE)
        sys.exit(1)

    domain_dir = sys.argv[1]
    robots = []
    subdomains = os.listdir(domain_dir)
    for subdomain in subdomains:
        files = os.listdir(domain_dir + '/' + subdomain)
        if len(files) == 1 and files[0] == ROBOTS_TXT:
            robots.append(RobotsTxt(domain_dir + '/' + subdomain + '/' + ROBOTS_TXT))

    summary = RobotsSummary(robots)
    print(json.dumps(summary.__dict__, indent=2))


if __name__ == "__main__":
    main()

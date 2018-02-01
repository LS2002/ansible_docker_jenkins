#!/usr/bin/env python
"""script to measure time used to login"""

import sys, os, socket, time
import requests
import argparse
import subprocess
import logging
import urllib2
import mechanize
from BeautifulSoup import BeautifulSoup
import ssl
import json
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()

parser = argparse.ArgumentParser()
parser.add_argument('-t', '--type', help='ui test type')
parser.add_argument('-p', '--path', help='result log path')
parser.add_argument('-d', '--debug', type=bool, default=False, help='Debug Flag')


def globally_disable_ssl_verification():
    """
    http://legacy.python.org/dev/peps/pep-0476/
    """
    try:
        _create_unverified_https_context = ssl._create_unverified_context
    except AttributeError:
        # Legacy Python that doesn't verify HTTPS certificates by default
        pass
    else:
        # Handle target environment that doesn't support HTTPS verification
        ssl._create_default_https_context = _create_unverified_https_context

globally_disable_ssl_verification()


def run_test(test_type, result_path):

    hostname = socket.gethostname()
    result = ""

    if test_type == "login":
        result = test_login(file_name)

    finish_test(hostname, test_type, result)


def test_login(file_name):
    start_time = time.time()
    while True:
        if os.path.exists(file_name):
            user_id_str = open(file_name).readline()
            if True:
                break

    action = "create"
    resp = requests.get('http://{{ mytest_server_ip }}:{{ mytest_server_port }}/test?target=%s&action=%s&hostname=%s' % (target, action, hostname))
    logging.debug("action=%s resp=%s %s" % (action, resp.status_code, resp.content))
    start_time = requests.get('http://{{ mytest_server_ip }}:{{ mytest_server_port }}/timestamp?target=%s&action=%s' % (target, action)).content
    
    return int((time.time() - start_time) * 1000)


def get_network_count(port):
    return int(run_command("netstat|grep %s|grep ESTABLISHED|wc -l" % port))


def finish_test(hostname, test_type, result, uuid):
    resp = requests.post('http://{{ mytest_server_ip }}:{{ mytest_server_port }}/report',
                         headers={'content-type': 'application/json'},
                         data=json.dumps({'erver_status': '{{ erver_status }}',
                                          'test_type': test_type,
                                          'hostname': hostname,
                                          'result': result
                                          }))
    logging.debug("Finish Test: %s %s %s %s" % (hostname, resp.status_code, resp.reason, result))


def run_command(cmd):
    out, err = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True).communicate()
    return out.strip('\n').strip('\r')


def main():
    args = parser.parse_args()
    run_test(args.type, args.path)


if __name__ == "__main__":
    main()

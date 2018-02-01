#!/usr/bin/env python

import logging
import mechanize
import urllib2
from BeautifulSoup import BeautifulSoup
import json
import argparse
import ssl
import sys
import requests.packages.urllib3
reload(sys)
sys.setdefaultencoding('utf8')
requests.packages.urllib3.disable_warnings()

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--platform', help='OS platform')
parser.add_argument('-p', '--function', help='utility function')
parser.add_argument('-d', '--debug', type=bool, default=False, help='Debug Flag')

logger = logging.getLogger(__name__)


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


def latest_version():
    browser, headers, endpoint = get_browser()

    try:
        url = endpoint + '/version.json'
        request = urllib2.Request(url, None, headers)
        response = browser.open(request)
        version = json.loads(response.get_data())['manifest']['version']
    except ValueError:
        url = endpoint + '/api/version.json'
        request = urllib2.Request(url, None, headers)
        response = browser.open(request)
        version = json.loads(response.get_data())['manifest']['version']

    return version


def get_browser():
    endpoint = 'https://{{ ui_server_name }}.mycompany.com'
    headers = {'X-CSRF-Token': '', 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}
    browser = mechanize.Browser()
    browser.add_client_certificate(endpoint,
                                   cert_file='{{ mytest_dir }}/certs/domain.crt',
                                   key_file='{{ mytest_dir }}/certs/domain.key')
    browser.set_handle_robots(False)
    browser.set_handle_redirect(True)
    try:
        browser.open('%s/login' % endpoint)
        browser.select_form(nr=0)
        browser['user[email]'] = "{{ user_name }}"
        browser['user[password]'] = "{{ user_password }}"
        browser.submit()
        request = urllib2.Request('%s/' % endpoint, None, headers)
        result = browser.open(request)
        csrf_token = BeautifulSoup(result.get_data()).findAll(attrs={'name': 'csrf-token'})[0]['content']
        headers['X-CSRF-Token'] = csrf_token
    except Exception as e:
        logging.error(e)
    return browser, headers, endpoint


def main():
    args = parser.parse_args()

    level = logging.INFO
    if args.debug:
      level = logging.DEBUG
    
    logging.basicConfig(filename='{{ mytest_dir }}/server/server.log',
                        format='%(asctime)s:%(levelname)s:%(message)s',
                        level=level)

    if args.function == "latest_version":
      print latest_version()


if __name__ == "__main__":
    main()

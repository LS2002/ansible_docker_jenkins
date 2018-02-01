import logging
import time
import argparse
import os
import subprocess

from flask import Flask, request
from flask import jsonify

parser = argparse.ArgumentParser()
parser.add_argument('-p', '--path', help='result path')
parser.add_argument('-d', '--debug', type=bool, default=False, help='Debug Flag')

logger = logging.getLogger(__name__)

time_since_first_post = 0
action_counter = 0
is_ready = False


def start_server(result_path):
    """Sets up the server for testing"""
    app = Flask(__name__)

    @app.route('/timestamp', methods=['GET'])
    def obtain_timestamp():
        action = request.args.get('action', type=str)
        target = request.args.get('target', type=str)
        while True:
            if os.path.exists('{{ mytest_dir }}/flag_%s_%s' % (target, action)):
                with open('{{ mytest_dir }}/flag_%s_%s' % (target, action)) as f:
                    line = f.readline()
                break
        return line

    @app.route('/logging', methods=['GET'])
    def obtain_log():
        log = request.args.get('log', type=str)
        hostname = request.args.get('hostname', type=str)
        logging.debug("%s %s" % (hostname, log))

    @app.route('/test', methods=['GET'])
    def change_target():
        global action_counter, is_ready

        action = request.args.get('action', type=str)
        target = request.args.get('target', type=str)
        hostname = request.args.get('hostname', type=str)

        if request.method == 'GET':
            action_counter += 1

            if action_counter >= int({{ factor }} *{{ mytest_amount }}):
                if not os.path.exists('{{ mytest_dir }}/flag_%s_%s' % (target, action)) and not is_ready:
                    is_ready = True
                    if target == "target1":
                        cmd = "ssh -t user@{{ ui_server_ip }} ssh -o StrictHostKeyChecking=no %" % action
                    if target == "target2":
                        cmd = "python {{ mytest_dir }}/server/config_utils.py -o create -t {{ container_hostname }}"
                    logging.debug("%s %s cmd = %s" % (hostname, action, cmd))
                    start_time = time.time()
                    out = run_command(cmd)
                    open('{{ mytest_dir }}/flag_%s_%s' % (target, action), 'w').write(str(start_time))
                    logging.debug("%s %s out = %s" % (hostname, action, out))
        return "SUCCESS"

    @app.route('/report', methods=['GET', 'POST'])
    def save_result():
        global time_since_first_post

        if request.method == 'POST':
            logging.debug('Received POST for test execution')
            data = request.get_json(force=True, silent=False, cache=True)

            with open("%s_%s_%s.txt" % (result_path, data['appserver_status'], data['test_type']), 'a+') as f:
                if time_since_first_post == 0:
                    time_since_first_post = time.time()
                    if 'login' in data['test_type'] or 'upgrade' in data['test_type']:
                        f.write('hostname,post_time,test_time,uuid\n')

                f.write('%s,%s,%s,%s\n' %
                        (data['hostname'],
                         int((time.time()-time_since_first_post)*1000),
                         data['result'],
                         data['uuid']
                         ))

            return jsonify({'saved': True})

        elif request.method == 'GET':
            logger.info('Received GET for test results')
            data = request.get_json(force=True, silent=False, cache=True)
            return jsonify({'results': 'success'})

    logging.debug("start server completed - listening on {{ server_ip }}:{{ server_port }}")
    if "{{ debug }}" == "--debug=True":
        debug_state = True
    else:
        debug_state = False
    app.run(host="{{ server_ip }}", port={{ server_port }}, debug=debug_state, threaded=True)


def run_command(cmd):
    out, err = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True).communicate()
    return out.strip('\n').strip('\r')


def main():
    args = parser.parse_args()
    level = logging.INFO
    if args.debug:
        level = logging.DEBUG

    logging.basicConfig(filename='{{ mytest_dir }}/server/server.log',
                        format='%(asctime)s:%(levelname)s:%(message)s',
                        level=level)

    start_server("%s/mytest_result_%s" % (args.path, time.strftime('%Y-%m-%d-%H-%M-%S', time.localtime())))


if __name__ == '__main__':
    main()

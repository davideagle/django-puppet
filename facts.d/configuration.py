#!/usr/bin/env python
from __future__ import print_function

from re         import match
from os         import environ
from six        import iteritems
from subprocess import Popen
from subprocess import PIPE

interpreter   = 'python'
configuration = {
    'xanadou_path'       : '/var/test_app',
    'xanadou_source'     : 'https://github.com/Chedi/test_app.git',
    'xanadou_app_name'   : 'test_app',
    'xanadou_python_3'   : 'true',
    'xanadou_extra_info' : 'e30K',
    'xanadou_server_name': 'www.test-app.dev',
}

for key, default in iteritems(configuration):
    print("{}={}".format(key, environ.get(key.upper(), default)))


if environ.get('xanadou_python_3'.upper(), 'true') == 'true':
    interpreter = 'python3'

process  = Popen([interpreter, '--version'], stdout=PIPE,  stderr=PIPE)
out, err = process.communicate()

python_version_match = match(r'^Python ((\d+\.)*\d+)$', err + out)
if python_version_match:
    print('xanadou_python={}'        .format(python_version_match.group(1)[0]))
    print('xanadou_python_version={}'.format(python_version_match.group(1)))

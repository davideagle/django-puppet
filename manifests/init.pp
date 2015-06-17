# Class: django
#
# This module install the production full stack django with nginx,
# postgresql, redis and supervisor
#
# Parameters:
#
# Actions:
#
# Requires:
#   nginx
#    - jfryman-nginx module >= 0.2.6
#
#   python
#    - stankevich-python module >= 1.8.0
#
#   openssl
#    - camptocamp-openssl module >= 1.3.8
#
#   vcsrepo
#    - puppetlabs-vcsrepo module >= 1.2.0
#
#   supervisord
#    - ajcrowe/supervisord module >= 0.5.2
#
#   firewall
#    - puppetlabs-firewall module >= 1.4.0
#
#   postgresql
#    - puppetlabs-postgresql module >= 4.0.0
#
# Sample Usage:
#
# The module require the following settings:
#    - path       : path to install django application
#    - source     : git repository for the source code
#    - app_name   : the name of the django application
#    - python_3   : true if you want to enable python 3
#    - extra_info : django extra config json object encoded in base64
#    - server_name: the nginx vhost servername
#
# class { 'django':
#   path        => $::xanadou_path,
#   source      => $::xanadou_source,
#   app_name    => $::xanadou_app_name,
#   python_3    => $::xanadou_python_3,
#   extra_info  => $::xanadou_extra_info,
#   server_name => $::xanadou_server_name,
# }

class django (
  $path       ,
  $source     ,
  $app_name   ,
  $python_3   ,
  $extra_info ,
  $server_name,
) {
  $collect_static                = './manage.py collectstatic --noinput'
  $virtualenv_path               = "${path}/virtualenv"
  $restart_gunicorn              = "supervisorctl restart ${app_name}_gunicorn"
  $gunicorn_upstream_name        = $app_name
  $update_nginx_ownership        = "chown -R nginx.nginx ${path} && chmod -R g+rw ${path} && find ${path} -type d| xargs chmod g+x"
  $django_virtualenv_environment = {
    'PATH'                => "${path}/virtualenv/bin:/bin:/sbin:/usr/bin:/usr/sbin",
    'XANADOU_PATH'        => $path       ,
    'XANADOU_SOURCE'      => $source     ,
    'XANADOU_APP_NAME'    => $app_name   ,
    'XANADOU_PYTHON_3'    => $python_3   ,
    'XANADOU_EXTRA_INFO'  => $extra_info ,
    'XANADOU_SERVER_NAME' => $server_name,
  }

  stage {'first' : before  => Stage['second']}
  stage {'second': before  => Stage['main'  ]}
  stage {'last'  : require => Stage['main'  ]}

  class { 'django::environment_setup'       : stage => first  }
  class { 'django::application_install'     : stage => second }
  class { 'django::nginx_configuration'     : stage => main   }
  class { 'django::postgresql_configuration': stage => main   }
  class { 'django::supervisor_configuration': stage => main   }
  class { 'django::application_bootstraping': stage => last   }
}

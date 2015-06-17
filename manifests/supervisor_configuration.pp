# class django::supervisor_configuration
#
# Setuping the supervisor tasks:
#  - gunicorn_workers:
#    for the gunicorn script
#
#  - django_watchdog_gunicorn_reloader:
#    reloading the gunicorn on *.py and *.html change
#
#  - django_watchdog_static_reloader:
#    static file if anything changes in the django application
#    assets folder

class django::supervisor_configuration {
  $path                          = $django::path
  $app_name                      = $django::app_name
  $logs_path                     = "${path}/logs"
  $directory                     = "${path}/${app_name}"
  $collect_static                = $django::collect_static
  $virtualenv_path               = $django::virtualenv_path
  $restart_gunicorn              = $django::restart_gunicorn
  $update_nginx_ownership        = $django::update_nginx_ownership
  $django_virtualenv_environment = $django::django_virtualenv_environment


  supervisord::program { 'gunicorn_workers':
    user           => 'root',
    command        => "${directory}/gunicorn.sh",
    directory      => $directory,
    autostart      => true,
    autorestart    => true,
    environment    => $django_virtualenv_environment,
    stdout_logfile => "${logs_path}/gunicorn_workers.log",
    stderr_logfile => "${logs_path}/gunicorn_workers.error",
  }

  supervisord::program { 'django_watchdog_gunicorn_reloader':
    user           => 'root',
    command        => "${virtualenv_path}/bin/watchmedo shell-command --patterns='*.py;*.html' --recursive --command='${restart_gunicorn} && ${update_nginx_ownership}'",
    directory      => $path,
    autostart      => true,
    autorestart    => true,
    environment    => $django_virtualenv_environment,
    stdout_logfile => "${logs_path}/django_watchdog_gunicorn_reloader.log",
    stderr_logfile => "${logs_path}/django_watchdog_gunicorn_reloader.error",
  }

  supervisord::program { 'django_watchdog_static_collector':
    user           => 'root',
    command        => "${virtualenv_path}/bin/watchmedo shell-command --patterns='*' --recursive --command='${collect_static} && ${update_nginx_ownership}'",
    directory      => "${directory}/assets",
    autostart      => true,
    autorestart    => true,
    environment    => $django_virtualenv_environment,
    stdout_logfile => "${logs_path}/django_watchdog_static_collector.log",
    stderr_logfile => "${logs_path}/django_watchdog_static_collector.error",
  }
}

# Class: django::application_bootstraping
#
# The actions performed in order:
#   1 - Create the application database
#   2 - Execute the django data migration
#   3 - Collect the static resource
#   4 - Update the ownership of the files and folders
#
class django::application_bootstraping {
  $path            = $django::path
  $app_name        = $django::app_name
  $virtualenv_path = $django::virtualenv_path

  postgresql::server::database { 'application_database':
    owner  => 'postgres',
    dbname => $app_name,
  } ->
    exec { 'database_migrations':
      path    => "${virtualenv_path}/bin:/bin",
      command => "${path}/${app_name}/manage.py migrate",
    } ->
      exec { 'collect_static':
        path    => "${virtualenv_path}/bin:/bin",
        command => "${path}/${app_name}/manage.py collectstatic --noinput",
      } ->
        exec { 'change_owner':
          path    => '/usr/bin/:/bin/',
          command => $django::update_nginx_ownership,
        }
}

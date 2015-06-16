class django (
  $path,       # Destination path
  $source,     # Application git repository
  $app_name,   # Application name
  $server_name,# Server name used in nginx
) {

  $virtualenv_path        = "${path}/virtualenv"
  $collect_static         = "./manage.py collectstatic --noinput"
  $restart_gunicorn       = "supervisorctl restart ${app_name}_gunicorn"
  $gunicorn_upstream_name = "${app_name}"
  $update_nginx_ownership = "chown -R nginx.nginx ${path} && chmod -R g+rw ${path} && find ${path} -type d -exec chmod g+x {}\;"

  stage {'last'  : require => Stage['main'  ]}
  stage {'third' : before  => Stage['main'  ]}
  stage {'second': before  => Stage['third' ]}
  stage {'first' : before  => Stage['second']}

  class environment_setup {
    package {'git'  : ensure => "installed"}
    package {'redis': ensure => "installed"}

    exec { "disable_selinux":
      path    => "/usr/sbin/:/bin/",
      command => "setenforce 0 && sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config"
    }

    exec { 'create_application_path_tree':
      command => "/usr/bin/mkdir -p ${path}"
    }

    exec { 'enable_redis_on_startup':
      command => "/usr/bin/systemctl enable redis && /usr/sbin/systemctl start redis"
    }

    class { 'python' :
      dev        => true,
      version    => $xanadou_python_version,
      virtualenv => true,
    }

    class {'nginx'      : require => Exec['disable_selinux']}
    class {'supervisord': require => Exec['disable_selinux']}
    class {'postgresql::globals':
      bindir               => '/usr/bin',
      datadir              => '/var/lib/pgsql/data',
      version              => '9.4',
      encoding             => 'UTF-8',
      service_name         => 'postgresql',
      devel_package_name   => 'postgresql-devel',
      client_package_name  => 'postgresql',
      server_package_name  => 'postgresql-server',
      pg_hba_conf_defaults => false,
      } ->
      class {'postgresql::server': listen_addresses => '127.0.0.1'}
  }

  class application_install {
    vcsrepo { $app_name:
      path     => $path,
      ensure   => latest,
      source   => $source,
      provider => 'git',
      revision => 'master',
      identity => $identity,
    }

    exec { "virtualenv_dependencies":
      require => Vcsrepo[$path],
      command => "$path/virtualenv_dependencies.sh",
    }

    python::virtualenv { $app_name:
      ensure       => present,
      require      => Exec['virtualenv_dependencies'],
      venv_dir     => "${virtualenv_path}",
      requirements => "${path}/requirements.txt",
    }

    ssl_pkey { "${path}/ssl/server.key":
      ensure  => present,
      require => Vcsrepo[$path],
    }

    openssl::certificate::x509 { 'server':
      unit         => 'Devel',
      days         => 100,
      email        => 'root@localhost.localdomain',
      owner        => 'nginx',
      group        => 'nginx',
      force        => false,
      state        => 'Unknown',
      ensure       => present,
      country      => 'TN',
      require      => Vcsrepo[$path],
      locality     => 'Unknown',
      base_dir     =>  "${path}/ssl/",
      commonname   => $fqdn,
      organization => 'Developpers',
    }
  }

  class nginx_configuration {
    nginx::resource::upstream { "${gunicorn_upstream_name}":
      members => ["unix://${path}/run/gunicorn.sock",],
    }

    nginx::resource::vhost { "${server_name}":
      www_root             => $path,
      server_name          => $servername,
      error_log            => "${path}/logs/nginx_error.log",
      access_log           => "${path}/logs/nginx_access.log",
      location_cfg_append  => {
        'rewrite' => '^ https://$server_name$request_uri? permanent' },
    }

    nginx::resource::vhost { "${server_name} ${app_name}":
      ssl                  => true,
      proxy                => "https://${gunicorn_upstream_name}",
      ensure               => present,
      ssl_key              => "${path}/ssl/server.key",
      ssl_cert             => "${path}/ssl/server.crt",
      ssl_port             => 443,
      error_log            => "${path}/logs/nginx_error.log",
      access_log           => "${path}/logs/nginx_access.log",
      listen_port          => 443,
      index_files          => ['index.html',],
      location_cfg_append  => undef,
      use_default_location => false,
    }

    nginx::resource::location { "/":
      ssl              => true,
      vhost            => "${server_name} ${app_name}",
      proxy            => "http://${gunicorn_upstream_name}",
      ensure           => present,
      ssl_only         => true,
      proxy_set_header => [
                           'Host $host',
                           'X-Real-IP $remote_addr',
                           'X-Forwarded-Proto https',
                           'X-Forwarded-For $proxy_add_x_forwarded_for']
    }

    nginx::resource::location { "/static/":
      ssl                 => true,
      vhost               => "${server_name} ${app_name}",
      ensure              => present,
      ssl_only            => true,
      location_alias      => "${path}/static/",
      location_cfg_append => {
        access_log    => 'on',
        log_not_found => 'on',
      }
    }

    nginx::resource::location { "/media/":
      ssl                 => true,
      vhost               => "${server_name} ${app_name}",
      ensure              => present,
      ssl_only            => true,
      location_alias      => "${path}/media/",
      location_cfg_append => {
        access_log    => 'on',
        log_not_found => 'on',
      }
    }
  }

  class postgresql_configuration {
    postgresql::server::pg_hba_rule { 'trust local postgres':
      type        => 'host',
      user        => 'postgres',
      order       => 1,
      address     => '127.0.0.1/32',
      database    => 'all',
      auth_method => 'trust',
      description => "allow access from localhost without password for the postgres user",
    }

    postgresql::server::pg_hba_rule { 'trust 127.0.0.1 postgres':
      type        => 'local',
      user        => 'postgres',
      order       => 2,
      database    => 'all',
      auth_method => 'trust',
      description => "allow local access without password for the postgres user",
    }

    postgresql::server::pg_hba_rule { 'trust ::1/128 postgres':
      type        => 'host',
      user        => 'postgres',
      order       => 3,
      address     => '::1/128',
      database    => 'all',
      auth_method => 'trust',
      description => "allow access from local ipv6 without password for the postgres user",
    }
  }

  class application_bootstraping {
    postgresql::server::database { 'application_database':
      owner  => 'postgres',
      dbname => $app_name,
    }

    exec { "database_migrations":
      path    => "${virtualenv_path}/bin:/bin",
      command => "${path}/${app_name}/manage.py migrate",
      require => Postgresql::Server::Database['application_database']
    }

    exec { "collect_static":
      path    => "${virtualenv_path}/bin:/bin",
      command => "${path}/${app_name}/manage.py collectstatic --noinput",
    }

    exec { "change_owner":
      path    => "/usr/bin/:/bin/",
      command => $update_nginx_ownership,
      require => Exec['collect_static'],
    }
  }

  class supervisor_configuration {
    $gunicorn_environment = {
      'PATH'                => "${path}/virtualenv/bin:/bin:/sbin:/usr/bin:/usr/sbin",
      'XANADOU_PATH'        => "${xanadou_path       }",
      'XANADOU_SOURCE'      => "${xanadou_source     }",
      'XANADOU_APP_NAME'    => "${xanadou_app_name   }",
      'XANADOU_PYTHON_3'    => "${xanadou_python_3   }",
      'XANADOU_EXTRA_INFO'  => "${xanadou_extra_info }",
      'XANADOU_SERVER_NAME' => "${xanadou_server_name}",
    }

    class configuration(
      $command                            ,
      $exec_user   = 'root'               ,
      $autostart   = true                 ,
      $directory   = "${path}/${app_name}",
      $environment = $gunicorn_environment,
      $autorestart = true                 ,
    ){
      supervisord::program { "${name}":
        user           => $exec_user,
        command        => $command,
        directory      => $directory
        autostart      => true,
        autorestart    => true,
        environment    => $environment,
        stdout_logfile => "${path}/logs/${name}.log",
        stderr_logfile => "${path}/logs/${name}.error",
      }
    }

    django::supervisor_configuration::configuration { "${app_name}_gunicorn":
      command   => "${path}/${app_name}/gunicorn.sh",
      exec_user => 'nginx'
    }

    django::supervisor_configuration::configuration { "${app_name}_gunicorn_reload":
      command => 'watchmedo shell-command --patterns="*.py;*.html" --recursive --command="${restart_gunicorn} && ${update_nginx_ownership}"'
    }

    django::supervisor_configuration::configuration { "${app_name}_collect_static":
      command   => 'watchmedo shell-command --patterns="*" --recursive --command="${collect_static} && ${update_nginx_ownership}"',
      directory => "${path}/${app_name}/assets"
    }
  }

  class { 'django::environment_setup'       : stage => first  }
  class { 'django::application_install'     : stage => second }
  class { 'django::nginx_configuration'     : stage => third  }
  class { 'django::postgresql_configuration': stage => third  }
  class { 'django::application_bootstraping': stage => main   }
  class { 'django::supervisor_configuration': stage => last   }

  django::environment_setup        { $app_name: }
  django::application_install      { $app_name: }
  django::nginx_configuration      { $app_name: }
  django::postgresql_configuration { $app_name: }
  django::application_bootstraping { $app_name: }
  django::supervisor_configuration { $app_name: }
}

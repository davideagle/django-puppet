# Class: django::application_bootstraping
#
# Configure the ngix web server with rewriting of the http to https
# on a vhost with the $django::servername name
#
# The vhost acts in proxy mode to the gunicorn workers via the socket
# in the run folder of the django installation path

class django::nginx_configuration {
  $path                   = $django::path
  $server_name            = $django::server_name
  $gunicorn_upstream_name = $django::gunicorn_upstream_name

  class {'nginx': }

  nginx::resource::upstream { $gunicorn_upstream_name:
    members => ["unix://${path}/run/gunicorn.sock",],
  }

  nginx::resource::vhost { "${server_name}_80":
    www_root            => $path,
    error_log           => "${path}/logs/nginx_error.log",
    access_log          => "${path}/logs/nginx_access.log",
    server_name         => [$servername],
    location_cfg_append => {
      'rewrite' => '^ https://$server_name$request_uri? permanent' },
  }

  nginx::resource::vhost { "${server_name}_443":
    ssl                  => true,
    proxy                => "https://${gunicorn_upstream_name}",
    ssl_key              => "${path}/ssl/server.key",
    ssl_cert             => "${path}/ssl/server.crt",
    ssl_port             => 443,
    error_log            => "${path}/logs/nginx_error.log",
    access_log           => "${path}/logs/nginx_access.log",
    server_name          => [$server_name],
    listen_port          => 443,
    index_files          => ['index.html',],
    location_cfg_append  => undef,
    use_default_location => false,
  }

  nginx::resource::location { '/':
    ssl              => true,
    vhost            => "${server_name}_443",
    proxy            => "http://${gunicorn_upstream_name}",
    ssl_only         => true,
    proxy_set_header => [
      'Host $host',
      'X-Real-IP $remote_addr',
      'X-Forwarded-Proto https',
      'X-Forwarded-For $proxy_add_x_forwarded_for']
  }

  nginx::resource::location { '/static/':
    ssl                 => true,
    vhost               => "${server_name}_443",
    ssl_only            => true,
    location_alias      => "${path}/static/",
    location_cfg_append => {
      access_log    => 'on',
      log_not_found => 'on',
    }
  }

  nginx::resource::location { '/media/':
    ssl                 => true,
    vhost               => "${server_name}_443",
    ssl_only            => true,
    location_alias      => "${path}/media/",
    location_cfg_append => {
      access_log    => 'on',
      log_not_found => 'on',
    }
  }
}

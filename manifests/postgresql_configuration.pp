# class django::postgresql_configuration
#
# Setuping the postgresql server on localhost with
# full trusted access for the postgres user

class django::postgresql_configuration {
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

  postgresql::server::pg_hba_rule { 'trust local postgres':
    type        => 'host',
    user        => 'postgres',
    order       => 1,
    address     => '127.0.0.1/32',
    database    => 'all',
    auth_method => 'trust',
    description => 'allow access from localhost without password for the postgres user',
  }

  postgresql::server::pg_hba_rule { 'trust 127.0.0.1 postgres':
    type        => 'local',
    user        => 'postgres',
    order       => 2,
    database    => 'all',
    auth_method => 'trust',
    description => 'allow local access without password for the postgres user',
  }

  postgresql::server::pg_hba_rule { 'trust ::1/128 postgres':
    type        => 'host',
    user        => 'postgres',
    order       => 3,
    address     => '::1/128',
    database    => 'all',
    auth_method => 'trust',
    description => 'allow access from local ipv6 without password for the postgres user',
  }
}

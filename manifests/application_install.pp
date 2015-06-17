# class django::application_install
#
# This class get the django application source code for a
# git repository, then deploy the virtual environment.
#
# The django application must be compliant a specific layout with
# a virtual_dependencies.sh script to install the packages before installing
# the virtualenv
#
# The application installation step will also generate the ssl certificates
# used by the nginx server

class django::application_install {
  $path            = $django::path
  $source          = $django::source
  $virtualenv_path = $django::virtualenv_path

  vcsrepo { $path:
    ensure   => latest,
    path     => $path,
    source   => $source,
    provider => 'git',
    revision => 'master',
  }

  exec { 'virtualenv_dependencies':
    require => Vcsrepo[$path],
    command => "${path}/virtualenv_dependencies.sh",
  }

  python::virtualenv { 'virtualenv':
    ensure       => present,
    require      => Exec['virtualenv_dependencies'],
    venv_dir     => $virtualenv_path,
    requirements => "${path}/requirements.txt",
  }

  ssl_pkey { "${path}/ssl/server.key":
    ensure  => present,
    require => Vcsrepo[$path],
  }

  openssl::certificate::x509 { 'server':
    ensure       => present,
    unit         => 'Devel',
    days         => 100,
    email        => 'root@localhost.localdomain',
    owner        => 'root',
    group        => 'root',
    force        => false,
    state        => 'Unknown',
    country      => 'TN',
    require      => Vcsrepo[$path],
    locality     => 'Unknown',
    base_dir     =>  "${path}/ssl/",
    commonname   => $::fqdn,
    organization => 'Developpers',
  }
}

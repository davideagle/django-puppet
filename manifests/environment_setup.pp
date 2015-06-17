# class django::environment_setup
#
# Initial step of the environment setup, will install the
# git, redis ,openssl and python (no really but, the dev packages)
# packages then will disable the selinux and start the redis server

class django::environment_setup {
  $path           = $django::path
  $python_version = $django::xanadou_python

  package {'git'    : ensure => 'installed'}
  package {'redis'  : ensure => 'installed'}
  package {'openssl': ensure => 'installed'}

  exec { 'disable_selinux':
    path    => '/usr/sbin/:/bin/',
    command => 'setenforce 0 && sed -i "s/^SELINUX=.*/SELINUX=disabled/g" /etc/selinux/config'
  }

  exec { 'create_application_path_tree':
    command => "/usr/bin/mkdir -p ${path}"
  }

  exec { 'enable_redis_on_startup':
    require => Package['redis'],
    command => '/usr/bin/systemctl enable redis && /usr/bin/systemctl start redis'
  }

  class { 'python' :
    dev        => true,
    version    => $python_version,
    virtualenv => true,
  }
}

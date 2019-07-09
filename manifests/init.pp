# == Class: homebrew
#
# Install HomeBrew  for Mac OS/X (http://brew.sh/) as a Puppet package provider
#
# Do not forget to download the command line tools for XCode from Apple
# and store them on a local repository.
# Caveat: You need an Apple ID to do that!
#
# === Parameters
#
# Document parameters here.
#
# [*xcode_cli_source*]
#   Contains the URL where this module can find the XCode CLI package.
#   Default: undef
#
# [*xcode_cli_version*]
#   Contains the version of the desired Xcode CLI package.
#   Default: undef
#
# [*user*]
#   Tells which user will own the Homebrew installation.
#   It is highly encouraged to choose a user different than the default.
#   Default: root
#
# [*group*]
#   Tells which group will own the Homebrew installation.
#   You should add users to this group later on
#   if you want them to be allowed to install brews.
#   Defaults: brew
#
# [*update_every*]
#   Tells how often a brew update should be run.
#   if 'default', it will be run every day at 02:07, local time.
#   if 'never', it will never run...
#   otherwise, MM:HH:dd:mm:wd is expected. Where:
#     - MM is the minute
#     - HH is the hour
#     - dd is the day of the month
#     - mm is the month
#     - wd is the week day
#   See https://docs.puppetlabs.com/references/latest/type.html#cron and
#   man crontab for a full explanation of time representations.
#   Note we do not support multi-values at the moment ([2, 4], e.g.).
#   Default: 'default'
#
# [*install_package*]
#   Tells if packages should be installed by searching the hiera database.
#   Default: true
#
# === Examples
#
#  include homebrew
#
#  To install for a given user:
#
#  class { 'homebrew':
#    user  => gildas,
#    group => brew,
#  }
#
#  class { 'homebrew':
#    user         => gildas,
#    group        => brew,
#    update_every => '01:*/6'
#  }
#
# === Authors
#
# Author Name <gildas@breizh.org>
#
# === Copyright
#
# Copyright 2014, Gildas CHERRUEL.
#
class homebrew (
  $xcode_cli_source  = undef,
  $xcode_cli_version = undef,
  $user              = root,
  $group             = brew,
  $update_every      = 'default',
  $install_packages  = true
)
{

  if ($::operatingsystem != 'Darwin')
  {
    err('This Module works on Mac OS/X only!')
    fail("Unsupported OS: ${::operatingsystem}")
  }
  if (versioncmp($::macosx_productversion_major, '10.7') < 0)
  {
    err('This Module works on Mac OS/X Lion or more recent only!')
    fail("Unsupported OS version: ${::macosx_productversion_major}")
  }

  if ($xcode_cli_source) {
    $xcode_cli_install = url_parse($xcode_cli_source, 'filename')

    if ($::has_compiler != true or ($xcode_cli_version and $::xcodeversion != $xcode_cli_version))
    {
      package {$xcode_cli_install:
        ensure   => present,
        provider => pkgdmg,
        source   => $xcode_cli_source,
      }
      -> exec {'accept-xcode':
        cwd         => '/tmp',
        command     => '/usr/bin/xcodebuild -license accept',
        refreshonly => true,
      }

    }
  }

  $homebrew_directories = [
    '/usr/local/bin',
    '/usr/local/Caskroom',
    '/usr/local/Cellar',
    '/usr/local/etc',
    '/usr/local/Homebrew',
    '/usr/local/include',
    '/usr/local/Frameworks',
    '/usr/local/lib',
    '/usr/local/manpages',
    '/usr/local/opt',
    '/usr/local/lib/pkgconfig',
    '/usr/local/Library',
    '/usr/local/sbin',
    '/usr/local/share',
    '/usr/local/share/doc',
    '/usr/local/var',
    '/usr/local/var/log',
    '/usr/local/var/homebrew',
  ]
  file { $homebrew_directories:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0775',
    require => Package[$xcode_cli_install],
  }
  -> exec {'install-homebrew':
    cwd       => '/usr/local',
    command   => "/usr/bin/curl -skSfL https://github.com/Homebrew/brew/tarball/master | /usr/bin/tar xz -m --strip 1 -C /usr/local/Homebrew",
    creates   => '/usr/local/Homebrew/bin/brew',
    user      => $user,
  }
  -> file { '/usr/local/bin/brew':
    ensure  => 'link',
    force   => true,
    owner   => $user,
    group   => $group,
    target  => '/usr/local/Homebrew/bin/brew',
    require => Exec['install-homebrew'],
  }
  group {$group:
    ensure => present,
    name   => $group,
  }

  if (! defined(File['/etc/profile.d']))
  {
    file {'/etc/profile.d':
      ensure => directory
    }
  }

  file {'/etc/profile.d/homebrew.sh':
    owner   => root,
    group   => wheel,
    mode    => '0775',
    source  => "puppet:///modules/${module_name}/homebrew.sh",
    require => File['/etc/profile.d'],
  }

  if ($::has_compiler != true and $xcode_cli_source)
  {
    Package[$xcode_cli_install] -> Exec['install-homebrew']
  }
  cron {'cron-update-brew':
    ensure      => $cron_ensure,
    command     => '/usr/local/bin/brew update 2>&1 >> /Library/Logs/Homebrew/cron-update-brew.log',
    environment => ['HOMEBREW_CACHE=/Library/Caches/Homebrew', 'HOMEBREW_LOGS=/Library/Logs/Homebrew/'],
    user        => root,
    minute      => 0,
    hour        => 23,
    require     => Exec['install-homebrew'],
  }

}

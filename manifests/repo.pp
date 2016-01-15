# = Define a git repository as a resource
#
# == Parameters:
#
# $source::     The URI to the source of the repository
#
# $path::       The path where the repository should be cloned to, fully qualified paths are recommended, and the $owner needs write permissions.
#
# $branch::     The branch to be checked out
#
# $git_tag::    The tag to be checked out
#
# $owner::      The user who should own the repository
#
# $update::     If this is true, puppet will revert local changes and pull remote changes when it runs.
#
# $checkout::   If this is true, puppet will ensure that an existing repository is still checked out to $branch. If false, an existing repository will be left alone.
#
# $bare::       If this is true, git will create a bare repository
#
# $umask::	Override the umask used when running the git commands

define git::repo(
  $path,
  $source   = false,
  $branch   = undef,
  $git_tag  = undef,
  $owner    = 'root',
  $group    = 'root',
  $update   = false,
  $checkout = true,
  $bare     = false,
  $umask    = undef,
){

  require git
  require git::params

  validate_bool($bare, $update, $checkout)

  if $branch {
    $real_branch = $branch
  } else {
    $real_branch = 'master'
  }

  if $source {
    $init_cmd = "${git::params::bin} clone -b ${real_branch} ${source} ${path} --recursive"
  } else {
    if $bare {
      $init_cmd = "${git::params::bin} init --bare ${path}"
    } else {
      $init_cmd = "${git::params::bin} init ${path}"
    }
  }

  $creates = $bare ? {
    true    => "${path}/objects",
    default => "${path}/.git",
  }


  if ! defined(File[$path]){
    file{$path:
      ensure  => directory,
      owner => $owner,
      recurse => true,
    }
  }

  exec {"git_repo_${name}":
    command   => $init_cmd,
    user      => $owner,
    creates   => $creates,
    require   => Package[$git::params::package],
    timeout   => 600,
    umask     => $umask,
  }

  if $update {
    exec {"git_${name}_pull":
      user      => $owner,
      cwd       => $path,
      command   => "${git::params::bin} reset --hard HEAD && ${git::params::bin} pull origin ${branch}",
      require   => Exec["git_repo_${name}"],
      umask     => $umask,
    }
  }

  # I think tagging works, but it's possible setting a tag and a branch will just fight.
  # It should change branches too...
  if $checkout {
    if $git_tag {
      exec {"git_${name}_co_tag":
        user      => $owner,
        cwd       => $path,
        command   => "${git::params::bin} checkout ${git_tag}",
        unless    => "${git::params::bin} describe --tag|/bin/grep -P '${git_tag}'",
        require   => Exec["git_repo_${name}"],
        umask     => $umask,
      }
    } elsif ! $bare {
      exec {"git_${name}_co_branch":
        user      => $owner,
        cwd       => $path,
        command   => "${git::params::bin} checkout ${branch}",
        unless    => "${git::params::bin} branch|/bin/grep -P '\\* ${branch}'",
        require   => Exec["git_repo_${name}"],
        umask     => $umask,
      }
    }
  }
}

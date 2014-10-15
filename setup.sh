#!/usr/bin/env bash

shopt -s extglob
set -o errtrace
set +o noclobber

#export VERBOSE=1
#export DEBUG=1
export NOOP=

whoami=$(whoami)

function log() # {{{
{
  printf "%b\n" "$*";
} # }}}

function debug() # {{{
{
  [[ ${DEBUG:-0} -eq 0 ]] || printf "[debug] $#: $*";
} # }}}

function verbose() # {{{
{
  [[ ${VERBOSE:-0} -eq 0 ]] || printf "$*\n";
} # }}}

function error() # {{{
{
  echo >&2 "$@"
} # }}}

function has_application() # {{{
{
  command -v "$@" > /dev/null 2>&1
} # }}}

function parse_args() # {{{
{
  flags=()

  while (( $# > 0 ))
  do
    arg="$1"
    shift
    case "$arg" in
      (--trace)
        set -o trace
	TRACE=1
	flags+=( "$arg" )
	;;
      (--noop)
        export NOOP=:
        ;;
      (--debug)
        export DEBUG=1
        flags+=( "$arg" )
        ;;
      (--quiet)
        export VERBOSE=0
        flags+=( "$arg" )
        ;;
      (--verbose)
        export VERBOSE=1
        flags+=( "$arg" )
        ;;
    esac
  done
} # }}}

# Main {{{
parse_args "$@"

case "$(uname -m)" in
  *64) ;;
  *)
    error 'This operating system is not a 64 bit platform'
    error 'Docker currently support only 64 bit platforms'
    exit 1
    ;;
esac

[[ ! -z "$NOOP" ]] && echo "Running in dry mode (no command will be executed)"

# Loads the distro information
debug "Loading distribution information..."
source /etc/os-release
[[ -r /etc/lsb-release ]] && source /etc/lsb-release
debug "Done\n"
echo "Running on $NAME release $VERSION"

if has_application docker || has_application lxc-docker ; then
  echo "Docker is already installed on this system"
else
  echo "You need to be a sudoer and will have to enter your password once during this script."
  if [ "$ID" == "centos" ]; then
    if [ "$VERSION_ID" == "7" ]; then
      #if [ ! $(rpm -qa | grep docker) ]; then
      echo "Updating the operating system (can take a while)"
      $NOOP sudo yum --assumeyes --quiet update
      echo "Installing Docker"
      $NOOP sudo yum --assumeyes --quiet install docker

      if [ "$(systemctl is-enabled docker)" != 'enabled' ]; then
        echo "Enabling Docker service"
        $NOOP sudo systemctl enable docker
      fi

      if [ "$(systemctl is-active docker)" != 'active' ]; then
        echo "Starting Docker"
        $NOOP sudo systemctl start docker
      fi
    else
      echo "We are very sorry, but we cannot complete the automatic installation as this version of $NAME is not yet supported."
      exit 1
    fi
  elif [ "$ID" == 'ubuntu' ]; then
    if [ "$VERSION_ID" == '14.04' ]; then
      #if [ ! $(dpkg --show --showformat='${Status}' docker.io) [; then
      echo "Updating the operating system (can take a while)"
      $NOOP sudo apt-get --assume-yes --quiet update
      echo "Installing Docker"
      $NOOP sudo apt-get --assume-yes --quiet install docker.io
      $NOOP sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker

      echo "Enabling Docker service"
      $NOOP sudo update-rc.d docker.io defaults

      if [ -z "$(service docker.io status | grep running)" ]; then
        echo "Starting Docker"
        $NOOP sudo service docker.io start
      fi
    else
      echo "We are very sorry, but we cannot complete the automatic installation as this version of $NAME is not yet supported."
      exit 1
    fi
  else 
    echo "We are very sorry, but we cannot complete the automatic installation as this operating system is not yet supported."
    exit 1
  fi
fi

if [ -z $(grep "docker:.*:${whoami}" /etc/group) ]; then
  echo "Adding user ${whoami} to group docker"
  $NOOP sudo usermod -aG docker ${whoami}
  echo "You need to logout and log back in and execute this script again"
  exit 0
fi

SLEEP=:
if [ ! "$(docker images | grep centos7)" ]; then
  echo "Pulling container images for CentOS"
  $NOOP docker pull centos
  SLEEP=
else
  echo "Container images for CentOS are already pulled"
fi

if [ ! "$(docker images | grep 'gildas/puppetserver')" ]; then
  if [ "$(docker search 'gildas/puppetserver'| grep 'gildas/puppetserver')" ]; then
    echo "Pulling container images for Puppet Server from github.com/gildas"
    # We need to sleep a little as we cannot issues docker pull/push too close to each other
    # Or, we get some HTTP Error 504.
    $SLEEP sleep 2
    $NOOP docker pull gildas/puppetserver:production
  else
    echo "Fetching definition for container puppetserver"
    if [ -d .git ] ; then
      git pull
    else
      $NOOP curl -sSL https://github.com/gildas/docker-puppetserver/raw/master/Dockerfile --output Dockerfile
    fi

    echo "Building container puppetbase"
    $NOOP docker build -t="gildas/puppetserver" .

    echo "Publishing container puppetserver"
    $NOOP docker push gildas/puppetserver
  fi
else
  echo "Container images for puppet are already pulled"
fi
echo "Configuring the container"
$NOOP docker run gildas/puppetserver curl -sSL http://tinyurl.com/setup-linux-server -o /tmp/setup.sh && bash /tmp/setup.sh
# }}}

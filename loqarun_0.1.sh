#!/usr/bin/env bash

#########################
## BOOTSTRAP AND UTILS ##
#########################
source "$( cd "${BASH_SOURCE[0]%/*}" && pwd )/lib/oo-bootstrap.sh"
import util/namedParameters util/class
# import util/log
# import util/exception
# import util/tryCatch

####################
## MAIN PROCEDURE ##
####################
function main() {
  # check for dependency in /usr/bin/, and exit (with message how to install it)
  # if it does not exist
  dependency wget
  dependency column bsdmainutils

  # save current location for future use
  string wdir
  $var:wdir = "$(pwd)"

  # create a scratch directory and delete it on EXIT
  $var:LibreOffice scratch = $(mktemp -d -t loqarun.XXXXXXXXXX)
  trap "rmdirrf $($var:LibreOffice scratch) 1" EXIT

  # create some variables for options
  string _installation_dir
  string _optsfile
  boolean _install
  boolean _kill_all
  boolean _list_versions
  boolean _maintain_profile
  boolean _newest
  boolean _oldest
  string _langpack
  boolean _quiet
  boolean _reset_profile
  string _server
  string _dailyserver
  string _prefix
  boolean _daily
  array _soffice
  array _versions
  string _version

  # set default options
  $var:_prefix = libreoffice-
  $var:_server = http://vm186.documentfoundation.org
  $var:_server = http://downloadarchive.documentfoundation.org
  $var:_dailyserver = http://dev-builds.libreoffice.org/daily/
  $var:_installation_dir = "/opt/"
  $var:_optsfile = "$HOME/.loqarunopts"

  case ${1} in
    -f | --optsfile )
      $var:_optsfile = ${2}
      shift 2
      ;;
  esac
  if [[ ! -z "$($var:_optsfile)" && -f "$($var:_optsfile)" ]]; then
    message "Loading options from $($var:_optsfile)..."
    options $(cat "$($var:_optsfile)")
  fi

  # get options
  options "${@}"

  # do everything which needs to be done
  $var:LibreOffice
}

#############################
## SOME 'NORMAL' FUNCTIONS ##
#############################
usage() {
  string usage
  string options
  $var:usage = "Usage: ${BASH_SOURCE[0]} [OPTION...] [VERSION/DIR...]
Runs the given version of LibreOffice from /opt.
If not available it will be downloaded and installed.
The profile directory will also be configured."
  $var:options = "
  -d, --installation-dir=PATH;use different installation directory than
  ;  current working dir ($($var:_installation_dir))
  -f, --optsfile=FILE;read options from other file than default
  ;  $($var:_optsfile) (needs to be the FIRST argument)
  -h, -u, --help, --usage;show message
  -i, --install;reinstall if already installed
  -k, --kill-all;kill all libreoffice instances
  -l, --list-versions;list available versions and exit
  -m, --maintain-profile;retains the profile of this version of
  ;  LibreOffice (default when already installed)
  -n, --newest, VERSION+;install the highest version from the list of
  ;  available versions
  -o, --oldest, VERSION-  ;install the lowest version from the list of
  ;  available versions
  -p, --langpack=LANG;install a language pack
  -q, --quiet;show no output
  -r, --reset-profile;deletes the profile of this version of
  ;  LibreOffice (default when installing)
  -s, --server=URL;use other download server than default
  ;  $($var:_server)
  -t, --this-dir;use the current directory as --installation-dir
  -x, --prefix=STRING;use other prefix for installation than default
  ;  $($var:_prefix)
  -y, --daily;install a LibreOffice Daily version
  -- OPTIONS;pass on options to soffice"
  echo "$($var:usage)"
  echo
  $var:options | column -ts ';'
}

options() {
  while [[ ${#} -gt 0 ]]; do
    case ${1} in
      --*=* )
        options "${1%=*}" "${1#*=}" "${@:2}"
        break
        ;;
      */ )
        options "${1%/}" "${@:2}"
        break
        ;;
      -d | --installation-dir )
        $var:_installation_dir = "${2}/"
        shift 2
        ;;
      -h | --help | -u | --usage )
        usage
        exit
        ;;
      -i | --install )
        $var:_install = true
        shift
        ;;
      -k | --kill-all )
        $var:_kill_all = true
        shift
        ;;
      -l | --list-versions )
        $var:_list_versions = true
        shift
        ;;
      -m | --maintain-profile )
        $var:_maintain_profile = true
        $var:_reset_profile = || true
        shift
        ;;
      -n | --newest )
        $var:_newest = true
        $var:_oldest = || true
        shift
        ;;
      -o | --oldest )
        $var:_oldest = true
        $var:_newest = || true
        shift
        ;;
      -p | --langpack )
        $var:_langpack = "_langpack_${2}"
        shift 2
        ;;
      -q | --quiet )
        $var:_quiet = true
        shift
        ;;
      -r | --reset-profile )
        $var:_reset_profile = true
        $var:_maintain_profile = || true
        shift
        ;;
      -s | --server )
        $var:_server = ${2}
        shift 2
        ;;
      -t | --this-dir )
        options "--installation-dir" "$(pwd)"
        shift
        ;;
      -x | --prefix )
        $var:_prefix = "${2}"
        shift 2
        ;;
      -y | --daily )
        $var:_daily = true
        shift
        ;;
      -- ) # Stop option processing
        shift
        $var:_soffice push "${@}"
        break
        ;;
      -? | --* )
        errorMessage "invalid option or argument -- '${1}'"
        exit
        ;;
      -??* )
        options $(sed 's/^-//; s/./-& /g' <<<${1}) "${@:2}"
        break
        ;;
      * )
        if [[ -z "${1/*$($var:_prefix)*}" ]]; then
          $var:_installation_dir = "${1%$($var:_prefix)*}"
          $var:_versions push "${1#*$($var:_prefix)}"
        else
          $var:_versions push "${1}"
        fi
        shift
        ;;
    esac
  done
}

message() {
  [...rest] message
  [[ $($var:_quiet toString) ]] || { echo -e "${message[@]}"; }
}

errorMessage() {
  [...rest] errorMessage
  message "Error: ${errorMessage[@]}\nTry '${BASH_SOURCE[0]} --help' for more" \
  "information." >&2
}

dependency() {
  @required [string] progName
  [string] packageName
  if [[ ! -x /usr/bin/$($var:progName) ]]; then
    echo -e "Dependency '$($var:progName)' is currently not installed. You" \
    "can install it by typing\n\"sudo apt install" \
    "${packageName:-$($var:progName)}\"" >&2
    exit
  fi
}

rmdirrf() {
  @required [string] directory
  [string] yn
  if [[ -d "$($var:directory)" ]] && ( (( "${yn:-0}" )) || \
  (( "$(confirm "Do you want to recursively delete '$($var:directory)'?")" )) )
  then
    rmdir --ignore-fail-on-non-empty $($var:directory) || true
    if [[ -d "$($var:directory)" ]]; then
      if ! rm -rf "$($var:directory)"; then
        string rmA="$($var:directory)"
        message "Running 'set -x; sudo rmdir \"$($var:rmA)\";" \
        "set +x'..."
        set -x
        sudo rmdir "${rmA}"
        set +x
      fi
    fi 
  fi
}

confirm() {
  # call with a prompt string or use a default
  string response
  read -r -p "${1:-Are you sure? [y/N]} " response
  case $($var:response) in
    [yY][eE][sS]|[yY])
      @return:value 1
      ;;
    *)
      @return
      ;;
  esac
}

######################
## CREATE THE CLASS ##
######################
class:LibreOffice() {
  public string installDir
  public string versionDir
  public string scratch
  public string filename
  public string unpackedFilename
  public string langpack
  public string versionslist
  public string selectedversions
  public string chooseversion

  # the __getter__ function (function is run if class is invoked without args)
  LibreOffice.__getter__() {
    # close all LibreOffice instances if --kill-all is selected
    if [[ $($var:_kill_all toString) ]]; then
      pkill soffice || true
    fi

    # populate $(this versionslist) from $($var:_server)
    if [[ $($var:_daily toString) ]]; then
      this versionslist = \
      "$(this wgetsed http://dev-builds.libreoffice.org/daily \
      | sed 's/libreoffice-//g' | tail -n 3)"
    else
      this versionslist = "$(this wgetsed $($var:_server)/libreoffice/old)"
    fi

    # print a message if no version is specified
    if [[ -z "$($var:_versions get 0)" && ! $($var:_oldest toString) \
    && ! $($var:_newest toString) && ! $($var:_list_versions toString) ]]
    then
      if [[ ! $($var:_kill_all toString) ]]; then
        errorMessage "No version specified"
      fi

    # list all available versions
    # (--list-versions is selected without much else)
    elif [[ -z "$($var:_versions get 0)" \
    && ! $($var:_oldest toString) && ! $($var:_newest toString) ]]
    then
      this selectedversions = "$(this versionslist)"
      this listversions

    # start procedure to prepare execution or installation of LibreOffice
    else
      if [[ -z "$($var:_versions get 0)" && $($var:_oldest toString) ]]; then
        $var:_versions set 0 "-"
      elif [[ -z "$($var:_versions get 0)" && $($var:_newest toString) ]]; then
        $var:_versions set 0 "+"
      fi

      # run (and install if needed) every specified LibreOffice version
      for ((x=0; x<=(($($var:_versions length)-1)); x++)); do

        # message for next executions of for loop (next LibreOffice version)
        if ! (($x==0)); then
          message -----------
        fi

        # select a version from the available versions in versionslist
        $var:_version = "$($var:_versions get $x)"
        string pm="${_version:${#_version}-1}"
        if [[ "$pm" = "-" || "$pm" = "+" ]]; then
          $var:_version = "${_version:0:${#_version}-1}"
        fi
        this selectedversions = \
        "$(echo -e "$(this versionslist)" | grep "^$($var:_version)" || true)"
        if [[ "$pm" = "-" ]] || [[ "$pm" != "+" && $($var:_oldest toString) ]]
        then
          this selectedversions = \
          "$(echo "$(this selectedversions)" | head -n 1)"
        elif [[ "$pm" = "+" || $($var:_newest toString) ]]; then
          this selectedversions = \
          "$(echo "$(this selectedversions)" | tail -n 1)"
        fi

        # print the version to be installed (or print a list if it is ambiguous)
        if [[ ! -z "$(this selectedversions)" ]]; then
          this listversions
          $var:_version = "$(this selectedversions | cut -d " " -f 1)"
        fi

        # clear the libreoffice profile ~/.config/$(this versionDir) if
        # --reset-profile is selected
        this versionDir = $($var:_prefix)$($var:_version)
        if [[ $($var:_reset_profile toString) ]]; then
          rmdirrf "$HOME/.config/$(this versionDir)"
        fi

        # run it if the version is already installed!
        if [[ ! $($var:_list_versions toString) && ! $($var:_install toString) \
        && -d "$($var:_installation_dir)$(this versionDir)" ]]
        then
          message "Running $(this versionDir)..."
          this run

        # if internet; then resume installation; else errorMessage; fi
        elif nc -z 8.8.8.8 53 &>/dev/null; then

        # if the version is not installed and not available on the server
        if [[ -z "$(this selectedversions)" ]]; then
          errorMessage "Version $($var:_version)* does not exist!"

        # if there are more versions to choose from (chooseversion is set by
        # this listversions) or if --list-versions is selected, don't install
        elif [[ ! -z $(this chooseversion) || $($var:_list_versions toString) ]]
        then
          this chooseversion =

          # else start installation
          else
if [[ $($var:_daily toString) ]]; then
  string urlpref
  string sixfour
  if [[ ! "$($var:_version)" -eq 'master' ]]; then
    $var:urlpref = 'libreoffice-'
  fi
  if [[ -z "${arch/*64}" ]]; then
    $var:sixfour = "/Linux-rpm_deb-x86_64@70-TDF/current"
  else
    $var:sixfour = "/Linux-rpm_deb-x86@71-TDF/current"
  fi
  $var:_server = \
  "$($var:_dailyserver)$($var:urlpref)$($var:_version)$($var:sixfour)"
else
  string arch
  $var:arch = "${HOSTTYPE/i?/x}"
  $var:_server = \
  "$($var:_server)/libreoffice/old/$($var:_version)/deb/$($var:arch)"
fi

# remove previous installation
rmdirrf "$($var:_installation_dir)$(this versionDir)"

# clear the libreoffice profile ~/.config/$(this versionDir) if
# --reset-profile is selected
if [[ ! $($var:_maintain_profile toString) ]]; then
  rmdirrf "$HOME/.config/$(this versionDir)"
fi

# install in /tmp/ (will move it later to /opt/) if it's still "/opt/"
if [[ "$($var:_installation_dir)" = "/opt/" ]]; then
  this installDir = "/tmp/"
else
  this installDir = "$($var:_installation_dir)"
fi

# start the real work
this setfilename
message "Downloading $(this filename)..."
this download
message "Unpacking to $(this unpackedFilename)..."
this unpack
message "Installing in $(this installDir)$(this versionDir)..."
this install
if [[ ! -z "$($var:_langpack)" ]]; then
  message "Installing the languagepack..."
  this langpack = "$($var:_langpack)"
  this setfilename
  this download
  this unpack
  this install
fi

# move it from "/tmp/"
if [[ "$(this installDir)" = "/tmp/" ]] && \
(( "$(confirm \
  "Do you want to move '$(this versionDir)' from /tmp/ to /opt/?")" \
)); then
  string mvA="/tmp/$(this versionDir)/"
  string mvB="$($var:_installation_dir)$(this versionDir)/"
  message "Running 'set -x; sudo mv \"$($var:mvA)\"" \
  "\"$($var:mvB)\"; set +x'..."
  set -x
  sudo mv "${mvA}" "${mvB}"
  set +x
fi

# run selected version of LO and exit
message "Running $(this versionDir)..."
this run
          fi
        else
          errorMessage "No network, and no installation of $($var:_version)"
        fi
      done
    fi
  }

  # other class functions
  LibreOffice.wgetsed() {
    @required [string] server
    @return:value "$(wget -O - -q "$($var:server)" | sed '
      s/&nbsp;/ /g
      s/<\!DOCTYPE.*//
      s/http:\/\/www.w3.org.*>//
      s/<address>.*<\/address>//
      s/ - //
      s/<[^<>]*>/ /g
      s/^[^/]*$//
      s/^[^-]*$//
      s/\///g
      s/^  *//g
      s/  *$//g
      s/  */ /g
    ')"
  }

  LibreOffice.listversions() {
    message "version upload-date -time\n$(this selectedversions)" | column -t
    if [[ "$(this selectedversions | wc -l)" -eq "1" \
    && ! $($var:_list_versions toString) ]]; then
      message "Running (and if not installed, installing) above version..."
    elif [[ ! $($var:_list_versions toString)  ]]; then
      message ""
      message "Which version do you want? Use option --newest or --oldest to" \
      "automatically"
      message "select the newest or the oldest version."
      this chooseversion = true
    fi
  }

  LibreOffice.setfilename() {
    string versioninfilename="$($var:_version)"
    string arch="${HOSTTYPE/i?/x}"
    string archinfilename="$($var:arch | sed 's/_/-/')"
    string langpack="$(this langpack)"
    string filename
    if [[ -z "$($var:versioninfilename | sed 's/.*\..*//')" ]]; then
      for i in {1..4}; do
        v[$i]="$($var:_version | cut -d "." -f $i)"
      done
      if [[ ${v[1]} -eq 3 ]]; then
        if [[ ${v[2]} -lt 6 ]]; then
          $var:versioninfilename = "${v[1]}.${v[2]}.${v[3]}"
          if [[ ${v[2]} -gt 3 ]]; then
            $var:versioninfilename = "$($var:versioninfilename)rc${v[4]}"
          fi
        fi
        $var:filename = "LibO_VARS_install-deb_en-US.tar.gz"
      else
        $var:filename = "LibreOffice_VARS_deb.tar.gz"
      fi
      $var:filename = "$($var:filename \
      | sed "s/VARS/$($var:versioninfilename)_Linux_$($var:archinfilename)/")"
    else
      $var:filename = "$(wget -O - -q "$($var:_server)" \
      | sed 's/>[^<>]*</\n/g' | grep deb.tar.gz | sed 's/a href=//g
      s/\"//g' | head -n 1)"
    fi
    this filename = "$($var:filename \
    | sed "s/.tar.gz/$($var:langpack).tar.gz/")"
  }

  LibreOffice.download() {
    cd $(this scratch)
    if [[ $($var:_quiet toString) ]]; then
      wget -q "$($var:_server)/$(this filename)" \
      || { errorMessage "File not found on server!" \
      "\n$($var:_server)/$(this filename)"; }
    else
      wget -q --show-progress "$($var:_server)/$(this filename)" \
      || { errorMessage "File not found on server:" \
      "\n$($var:_server)/$(this filename)"; }
    fi
  }

  LibreOffice.unpack() {
    cd "$(this scratch)"
    if [[ -f "$(this filename)" ]]; then
      this unpackedFilename = "$(this filename).unpacked"
      mkdir "$(this unpackedFilename)"
      tar -xzf "$(this filename)" -C "$(this unpackedFilename)"
    else
      errorMessage "Nothing to unpack!"
    fi
  }

  LibreOffice.install() {
    cd $(this scratch)
    if [[ -d "$(this scratch)/$(this unpackedFilename)" ]]; then
      cd "$($var:wdir)"
      mkdir "$(this installDir)$(this versionDir)/"
      cd "$(this installDir)$(this versionDir)/"
      for deb in $(this scratch)/$(this unpackedFilename)/*/DEBS/*.deb; do
        dpkg-deb -x ${deb} .
      done
      sed -i "s/\(libreoffice.*\)\//$(this versionDir)\//" \
      opt/libreoffice*/program/bootstraprc
    else
      errorMessage "Nothing to install!"
    fi
  }

  LibreOffice.run() {
    array sofficeOptions="$($var:_soffice)"
    string versionDir="$(this versionDir)"
    eval "$($var:_installation_dir)$($var:versionDir \
    | sed 's/ /\\ /g')/opt/libreoffice*/program/soffice \
    ${sofficeOptions[@]// /\\ }" &>/dev/null &
  }
}

# required to initialize the class (doesn't work inside a function)
Type::Initialize LibreOffice
LibreOffice LibreOffice

########################
## LETS START THE FUN ##
########################
main "${@}"

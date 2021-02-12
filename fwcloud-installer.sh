#!/bin/bash

################################################################
printCopyright() {
  echo -e "\e[34m#################################################################################"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#  Copyright 2020 SOLTECSIS SOLUCIONES TECNOLOGICAS, SLU                        #"
  echo -e "\e[34m#    https://soltecsis.com                                                      #"
  echo -e "\e[34m#    info@soltecsis.com                                                         #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#  This file is part of FWCloud (https://fwcloud.net).                          #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#  FWCloud is free software: you can redistribute it and/or modify              #"
  echo -e "\e[34m#  it under the terms of the GNU Affero General Public License as published by  #"
  echo -e "\e[34m#  the Free Software Foundation, either version 3 of the License, or            #"
  echo -e "\e[34m#  (at your option) any later version.                                          #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#  FWCloud is distributed in the hope that it will be useful,                   #"
  echo -e "\e[34m#  but WITHOUT ANY WARRANTY; without even the implied warranty of               #"
  echo -e "\e[34m#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #"
  echo -e "\e[34m#  GNU General Public License for more details.                                 #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#  You should have received a copy of the GNU General Public License            #"
  echo -e "\e[34m#  along with FWCloud.  If not, see <https://www.gnu.org/licenses/>.            #"
  echo -e "\e[34m#                                                                               #"
  echo -e "\e[34m#################################################################################"
  echo -e "\e[0m"
}
################################################################

################################################################
upgradeToNewDirectorySchema() {
  if [ ! -d "$REPODIR" ]; then mkdir "$REPODIR"; fi
  
  echo -n "Upgrading fwcloud-api ... "
  systemctl stop fwcloud-api
  mv /opt/fwcloud-api /opt/fwcloud/api
  cd /opt/fwcloud/api
  git pull
  git checkout main
  sed -i 's|/opt/fwcloud-|/opt/fwcloud/|g' "${ENVFILE}"
  npm run update
  # The update scripts starts the service. Wait a little for complet the start of it.
  sleep 5
  updateSystemd api
  systemctl start fwcloud-api
  echo "DONE"

  echo -n "Upgrading fwcloud-ui ... "
  mv /opt/fwcloud-ui /opt/fwcloud/ui
  cd /opt/fwcloud/ui
  git pull
  git checkout main
  npm run update
  echo "DONE"

  FWC_UI_ACTION="U"
  FWC_API_ACTION="U"
}
################################################################

################################################################
passGen() {
  PASSGEN=`cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w ${1} | head -n 1`
}
################################################################

################################################################
setGlobalVars() {
  FWC_API_PORT="3131"
  FWC_UPDATER_PORT="3132"
  FWC_WEBSRV_PORT="3030"
  REPODIR="/opt/fwcloud"

  if [ -d "$REPODIR/websrv" ]; then FWC_WEBSRV_ACTION="U"; else FWC_WEBSRV_ACTION="I"; fi
  if [ -d "$REPODIR/ui" ]; then FWC_UI_ACTION="U"; else FWC_UI_ACTION="I"; fi
  if [ -d "$REPODIR/api" ]; then FWC_API_ACTION="U"; else FWC_API_ACTION="I"; fi
  if [ -d "$REPODIR/updater" ]; then FWC_UPDATER_ACTION="U"; else FWC_UPDATER_ACTION="I"; fi

  PKGM_CMD="apt install -y"
  NODE_SETUP="setup_14.x"
  NODE_SRC="https://deb.nodesource.com/${NODE_SETUP}"
  MYSQL_PKG="mysql-server"
  MARIADB_PKG="mariadb-server"
  ENVFILE=".env"

  case $DIST in
    'Ubuntu') 
      ;;

    'Debian') 
      MYSQL_PKG="default-mysql-server"
      ;;

    'RedHat'|'CentOS') 
      PKGM_CMD="yum install -y"
      NODE_SRC="https://rpm.nodesource.com/${NODE_SETUP}"
      ;;

    'Fedora') 
      PKGM_CMD="yum install -y"
      NODE_SRC="https://rpm.nodesource.com/${NODE_SETUP}"
      MYSQL_PKG="community-mysql-server"
      ;;

    'OpenSUSE') 
      PKGM_CMD="zypper install -y"
      NODE_SRC=""
      MYSQL_PKG="mysql-server"
      MARIADB_PKG="mariadb"
      ;;

    'FreeBSD') 
      PKGM_CMD="pkg install -y"
      NODE_SRC=""
      VER=`pkg search mysql | grep -i "(server)" | awk -F"-" '{print $1}' | awk -F"mysql" '{print $2}' | sort -n -r | head -n 1`
      MYSQL_PKG="mysql${VER}-server"
      VER=`pkg search mariadb | grep -i "(server)" | awk -F"-" '{print $1}' | awk -F"mariadb" '{print $2}' | sort -n -r | head -n 1`
      MARIADB_PKG="mariadb${VER}-server"
      ;;
  esac
}
################################################################

################################################################
promptInput() {
  # $1=Text message.
  # $2=Accepted values.
  # $3=Default value.


  if [ "$DIST" = "FreeBSD" ]; then
    read -p "$1" OPT
  else
    read -s -n1 -p "$1" OPT
  fi

  while [ 1 ]; do
    # If the user has pressed the enter key then return the default value.
    if [ -z "$OPT" ]; then
      OPT="$3"
      echo
      return
    fi

    # Check that the pressed key is in the list.
    for I in $2; do
      if [ "$OPT" = "$I" ]; then
        echo
        return
      fi
    done

    read -s -n1 OPT
  done
}
################################################################

################################################################
promptProxyURL() {
  # $1=Text message.
  url_regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

  while [ 1 ]; do
    echo -e "- Enter \e[35m${1}\e[39m proxy URL:"
    read -e -p "" -i "$PROXY_URL" PROXY_URL
    if [[ $PROXY_URL =~ $url_regex ]]; then 
      echo -n "Checking proxy ... "
      RES=`curl -s -o /dev/null -w "%{http_code}" --max-time 20 -x "$PROXY_URL" -L "${1}://google.com"`
      if [ "$RES" = "200" ]; then
        echo "OK"
        break
      else
        echo -e "\e[31mERROR\e[39m"
      fi
    else
      echo -e "\e[31mERROR\e[39m: Invalid URL."
      PROXY_URL=""
    fi
  done
}
################################################################

################################################################
pkgInstalled() {
  # $1=pkg name.

  FOUND=""
  if [ $DIST = "Debian" -o $DIST = "Ubuntu" ]; then
    FOUND=`dpkg -s $1 2>/dev/null | grep "^Status: install ok installed"`
  elif [ $DIST = "RedHat" -o $DIST = "CentOS" -o $DIST = "Fedora" ]; then
    rpm -q $1 >/dev/null 2>&1
    if [ "$?" = 0 ]; then
      FOUND="1"
    fi
  elif [ $DIST = "OpenSUSE" ]; then
    zypper search -i $1 >/dev/null 2>&1
    if [ "$?" = 0 ]; then
      FOUND="1"
    fi
  elif [ $DIST = "FreeBSD" ]; then
    pkg info $1 >/dev/null 2>&1
    if [ "$?" = 0 ]; then
      FOUND="1"
    fi
  fi

  if [ "$FOUND" ]; then
    return 1
  else
    return 0
  fi
}
################################################################

################################################################
pkgInstall() {
  # $1=Display name.
  # $2=pkg name.

  echo -n -e "\e[96mPACKAGE: \e[39m${1} ... "
  pkgInstalled "$2"
  if [ "$?" = "0" ]; then
    echo -e "\e[1m\e[33mNOT FOUND. \e[39mInstalling ... \e[0m"
    $PKGM_CMD $2
    echo "DONE"
  else
    echo "FOUND"
  fi
  echo
}
################################################################

################################################################
runSql() {
  # $1=SQL.
  # $2=Ignore error.
  
  RESULT=`echo "$1" | $MYSQL_CMD 2>&1`
  if [ "$?" != "0" -a -z "$2" ]; then
    echo -e "\e[31mERROR:\e[39m: Executing SQL: $1"
    echo "$RESULT"
    exit 1
  fi
}
################################################################

################################################################
generateOpensslConfig() {
  cat > openssl.cnf << EOF
[ req ]
distinguished_name = req_distinguished_name
attributes = req_attributes
prompt = no

[ req_distinguished_name ]
O=SOLTECSIS - FWCloud.net
CN=${1}

[ req_attributes ]

[ cert_ext ]
subjectKeyIdentifier=hash
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth,serverAuth
EOF
}
################################################################

################################################################
buildTlsCertificate() {
  echo "Generating GPG keys pair for fwcloud-${1} ... "

  mkdir "${REPODIR}/${1}/config/tls"
  chown fwcloud:fwcloud "${REPODIR}/${1}/config/tls"
  cd "${REPODIR}/${1}/config/tls"

  passGen 32
  CN="fwcloud-${1}-${PASSGEN}"
  generateOpensslConfig "$CN"

  # Private key.
  openssl genrsa -out fwcloud-${1}.key 2048

  # CSR.
  openssl req -config ./openssl.cnf -new -key fwcloud-${1}.key -nodes -out fwcloud-${1}.csr

  # Certificate.
  # WARNING: If we indicate more than 825 days for the certificate expiration date
  # we will not be able to access from Google Chrome web browser.
  openssl x509 -extfile ./openssl.cnf -extensions cert_ext -req \
    -days 825 \
    -signkey fwcloud-${1}.key -in fwcloud-${1}.csr -out fwcloud-${1}.crt
   
  rm openssl.cnf
  rm "fwcloud-${1}.csr"

  chown fwcloud:fwcloud "fwcloud-${1}.key" "fwcloud-${1}.crt"
  echo "DONE"
  echo
}
################################################################

################################################################
tcpPortCheck() {
  echo -n "TCP port ${1} for fwcloud-${2} ... "
  OUT=`lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep "\:${1}"`
  if [ "$OUT" ]; then
    echo -e "\e[31mIN USE!\e[39m"
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | head -n 1
    echo "$OUT"
    exit 1
  fi
  echo "OK"
}
################################################################

################################################################
npmInstall() {
  echo -e "\e[96m${1}\e[39m"
  cd "$REPODIR/$1"
  NPM_INSTALL_CMD="cd \"$REPODIR/$1\" && OPENCOLLECTIVE_HIDE=1 npm install --loglevel=error"
  if [ "$http_proxy" ]; then
    NPM_INSTALL_CMD="export http_proxy && export https_proxy && npm config set proxy $http_proxy && npm config set https-proxy $https_proxy && $NPM_INSTALL_CMD"
  fi
  su - fwcloud -c "$NPM_INSTALL_CMD"
  if [ "$?" != 0 ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
}
################################################################

################################################################
runBuild() {
  echo -n "Compiling $1 (please wait) ... "
  su - fwcloud -c "cd \"$REPODIR/$1\"; npm run build" >/dev/null
  if [ "$?" != 0 ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
  echo "DONE"
}
################################################################

################################################################
updateSystemd() {
  SYSTEMD_FILE="/etc/systemd/system/fwcloud-${1}.service"
  cp "${REPODIR}/${1}/config/sys/fwcloud-${1}.service" "${SYSTEMD_FILE}"

  if [ "$http_proxy" ]; then
    sed -i 's|\[Service\]|\[Service\]\nEnvironment="no_proxy=localhost,127.0.0.*"\nEnvironment="http_proxy='"${http_proxy}"'"\nEnvironment="https_proxy='"${https_proxy}"'"|g' "${SYSTEMD_FILE}"
  fi

  systemctl daemon-reload
}
################################################################

################################################################
startEnableService() {
  echo -n "Starting $1 service ... "
  systemctl start "$1"
  echo "DONE"

  echo -n "Enabling $1 service at boot ... "
  systemctl enable "$1" >/dev/null 2>&1
  echo "DONE"
}
################################################################

################################################################
enableStartFWCloudService() {
  updateSystemd $1

  echo -n "Enabling fwcloud-$1 at boot ... "
  systemctl enable fwcloud-$1 >/dev/null 2>&1
  echo "DONE"
  echo -n "Starting "
  systemctl start fwcloud-$1
  N=0
  while [ 1 ]; do
    sleep 1
    echo -n "."
    OUT=`lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep "\:${2}"`
    if [ "$OUT" ]; then
      echo " DONE"
      break
    fi
    N=`expr $N + 1`
    if [ $N -gt 45 ]; then
      echo "ERROR"
      break
    fi
  done
}
################################################################

################################################################
gitCloneOrUpdate() {
  echo
  cd "$REPODIR"

  if [ -d "$REPODIR/$1" ]; then
    echo "Updating fwcloud-$1 ..."
    cd "$1"
    NEEDS_UP_TO_DATE=`git pull --dry-run 2<&1`
    if [ ! "$NEEDS_UP_TO_DATE" ]; then
      echo "Don't needs update, it is already up to date."
      return
    fi

    git pull
    if [ "$?" != "0" ]; then
      exit 1
    fi

    if [ "$1" = "websrv" -o "$1" = "api" -o "$1" = "updater" ]; then
      # Update systemd file.
      updateSystemd $1
    fi

    EXISTS_UPDATE_SCRIPT=`grep "\"update\":" package.json`
    if [ "$EXISTS_UPDATE_SCRIPT" ]; then
      npm run update
      if [ "$?" != "0" ]; then
        exit 1
      fi
      updateSystemd $1
      systemctl start "fwcloud-$1"
    else
      if [ "$1" = "ui" ]; then
        return
      fi

      systemctl stop "fwcloud-$1"
      
      npm install && npm run build
      if [ "$?" != "0" ]; then
        exit 1
      fi

      if [ "$1" = "api" ]; then
        node fwcli migration:run
      fi
      
      systemctl start "fwcloud-$1"
    fi
  else
    echo "Installing fwcloud-$1 ..."
    git clone -b main --single-branch "https://github.com/soltecsis/fwcloud-${1}.git" "$1"
    if [ "$?" != "0" ]; then
      exit 1
    fi

    # Init fwcloud-ui submodules.
    if [ "$1" = "ui" ]; then    
      git submodule update --init --recursive
    fi
  fi
}
################################################################


clear
printCopyright


echo -e "\e[32m\e[1m(*) Linux distribution.\e[21m\e[0m"
which hostnamectl >/dev/null 2>&1
if [ "$?" = "0" ]; then
  OS=`hostnamectl | grep "^  Operating System: " | awk -F": " '{print $2}'`
else
  OS=`uname -a`
fi
case $OS in
  'Ubuntu '*) DIST="Ubuntu";;
  'Debian '*) DIST="Debian";;
  'Red Hat Enterprise '*) DIST="RedHat";;
  'CentOS '*) DIST="CentOS";;
  'Fedora '*) DIST="Fedora";;
  'openSUSE '*) DIST="OpenSUSE";;
  'FreeBSD '*) DIST="FreeBSD";;
  *) DIST="";;
esac
setGlobalVars

if [ $DIST ]; then
  echo -e "Detected supported Linux distribution: \e[35m${OS}\e[39m"
else
  echo -e "Your Linux distribution (\e[35m${OS}\e[39m) is not supported."
  promptInput "Do you want to continue? [y/N] " "y n" "n"
  if [ "$OPT" = "n" ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
fi
echo 


echo
echo "This shell script will install/update FWCloud on your system."
echo "Projects fwcloud-websrv, fwcloud-ui, fwcloud-api and fwcloud-updater will be installed."
promptInput "Do you want to continue? [Y/n] " "y n" "y"
if [ "$OPT" = "n" ]; then
  echo -e "\e[31mInstallation canceled!\e[39m"
  exit 1
fi
echo


# Check if we are the root user or a user with sudo privileges.
# If not, error.
if [ "$EUID" != "0" ]; then
  echo -e "\e[31mERROR:\e[39m Please run this script as root or using the sudo command."
  exit 1
fi


# Proxy support.
echo -e "\e[32m\e[1m(*) HTTP/HTTPS proxy.\e[21m\e[0m"
echo "As part of the install procedure we will download system packages and NodeJS modules."
echo "If this system requires a HTTP/HTTPS proxy you have to specify its URL."
if [ "$http_proxy" -o "$https_proxy" ]; then
  echo
  echo "Detected proxy setup:"
  if [ "$http_proxy" ]; then echo "http_proxy=${http_proxy}"; fi
  if [ "$https_proxy" ]; then echo "https_proxy=${https_proxy}"; fi
else
  promptInput "Are you behind an HTTP/HTTPS proxy? [y/N] " "y n" "n"
  if [ "$OPT" = "y" ]; then
    echo
    echo "The proxy information should be given in the standard format: http://[[user][:pass]@]host[:port]"
    promptProxyURL "http"
    export http_proxy="$PROXY_URL"
    
    promptProxyURL "https"
    export https_proxy="$PROXY_URL"
  fi
fi
echo 


# Detect old directory structure installation.
if [ -d "/opt/fwcloud-api" -a -d "/opt/fwcloud-ui" ]; then
  echo -e "\e[32m\e[1m(*) Old directory schema detected.\e[21m\e[0m"
  echo "Old schema:"
  echo "  /opt/fwcloud-api"
  echo "  /opt/fwcloud-ui"
  echo
  echo "New schema:"
  echo "  /opt/fwcloud/websrv"
  echo "  /opt/fwcloud/ui"
  echo "  /opt/fwcloud/api"
  echo "  /opt/fwcloud/updater"
  echo
  promptInput "Do you want upgrade to the new schema ? [Y/n] " "y n" "y"
  if [ "$OPT" = "n" ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
  echo
  echo -e "\e[35mWARNING\e[39m: Please, make sure that you have a backup of your FWCloud installation."
  echo "If you are using virtual machines you can make an snapshot before the upgrade."
  promptInput "Continue ? [Y/n] " "y n" "y"
  if [ "$OPT" = "n" ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
  upgradeToNewDirectorySchema
  echo
fi


# Install required packages.
echo -e "\e[32m\e[1m(*) Searching for required packages.\e[21m\e[0m"
pkgInstall "lsof" "lsof"
pkgInstall "git" "git"
pkgInstall "curl" "curl"
pkgInstall "OpenSSL" "openssl"
pkgInstall "OpenVPN" "openvpn"
pkgInstall "osslsigncode" "osslsigncode"
if [ "$DIST" != "OpenSUSE" -a "$DIST" != "FreeBSD" ]; then
  echo -n "Setting up Node.js repository ... "
  OUT=`curl -sL ${NODE_SRC} | bash -  2>&1 >/dev/null`
  if [ "$?" != "0" ]; then
    echo
    echo "$OUT"
    echo -e "\e[31mERROR!\e[39m"
    exit 1
  fi
  echo "DONE"
fi
if [ "$DIST" = "FreeBSD" ]; then
  pkgInstall "Node.js" "node"
  pkgInstall "Node-npm" "npm"
else
  pkgInstall "Node.js" "nodejs"
fi


# Select database engine.
echo -e "\e[32m\e[1m(*) Database engine.\e[21m\e[0m"
echo "FWCloud needs a MariaDB or MySQL database engine."
# Check first if we already have one of the installed.
pkgInstalled "$MARIADB_PKG"
if [ "$?" = "1" ]; then
  DBENGINE="MariaDB"
  echo "MariaDB ... FOUND"
else
  pkgInstalled "$MYSQL_PKG"
  if [ "$?" = "1" ]; then
    DBENGINE="MySQL"
    echo "MySQL ... FOUND"
  else
    DBENGINE="MariaDB"
    pkgInstall "MariaDB" "$MARIADB_PKG"
    startEnableService "mariadb"
  fi
fi

if [ "$DIST" = "FeeBSD" ]; then
  sysrc mysql_enable=YES
  service mysql-server start
fi
echo


# Check if TPC ports used for fwcloud-api and fwcloud-updater are in use.
if [ "$FWC_WEBSRV_ACTION" = "I" -o  "$FWC_API_ACTION" = "I" -o "$FWC_UPDATER_ACTION" = "I" ]; then
  echo -e "\e[32m\e[1m(*) Checking FWCloud TCP ports.\e[21m\e[0m"
  if [ "$FWC_WEBSRV_ACTION" = "I" ]; then tcpPortCheck "$FWC_WEBSRV_PORT" "websrv"; fi
  if [ "$FWC_API_ACTION" = "I" ]; then tcpPortCheck "$FWC_API_PORT" "api"; fi 
  if [ "$FWC_UPDATER_ACTION" = "I" ]; then tcpPortCheck "$FWC_UPDATER_PORT" "updater"; fi
  echo
fi


# Cloning or updating GitHub repositories.
echo -e "\e[32m\e[1m(*) Installing/updating from GitHub repositories.\e[21m\e[0m"
echo "We are going to install/update the next FWCloud projects:"
if [ "$FWC_WEBSRV_ACTION" = "I" ]; then ACT_STR="[\e[35mINSTALL\e[39m]"; else ACT_STR="[\e[35mUPDATE\e[39m] "; fi
echo -e "\e[96mfwcloud-websrv\e[39m   ${ACT_STR}  (https://github.com/soltecsis/fwcloud-websrv.git)"
if [ "$FWC_UI_ACTION" = "I" ]; then ACT_STR="[\e[35mINSTALL\e[39m]"; else ACT_STR="[\e[35mUPDATE\e[39m] "; fi
echo -e "\e[96mfwcloud-ui\e[39m       ${ACT_STR}  (https://github.com/soltecsis/fwcloud-ui.git)"
if [ "$FWC_API_ACTION" = "I" ]; then ACT_STR="[\e[35mINSTALL\e[39m]"; else ACT_STR="[\e[35mUPDATE\e[39m] "; fi
echo -e "\e[96mfwcloud-api\e[39m      ${ACT_STR}  (https://github.com/soltecsis/fwcloud-api.git)"
if [ "$FWC_UPDATER_ACTION" = "I" ]; then ACT_STR="[\e[35mINSTALL\e[39m]"; else ACT_STR="[\e[35mUPDATE\e[39m] "; fi
echo -e "\e[96mfwcloud-updater\e[39m  ${ACT_STR}  (https://github.com/soltecsis/fwcloud-updater.git)"
echo "These repositories will be installed/updated into the directory: ${REPODIR}"
promptInput "Is it right? [Y/n] " "y n" "y"
if [ "$OPT" = "n" ]; then
  echo -e "\e[31mInstallation canceled!\e[39m"
  exit 1
fi

if [ ! -d "$REPODIR" ]; then mkdir "$REPODIR"; fi
if [ ! -d "$REPODIR" ]; then
  echo -e "\e[31mERROR:\e[39m Creating directory: $REPODIR"
  exit 1
fi

gitCloneOrUpdate "websrv"
gitCloneOrUpdate "ui"
gitCloneOrUpdate "api"
gitCloneOrUpdate "updater"


echo
echo -e "\e[32m\e[1m(*) Setting up permissions.\e[21m\e[0m"
echo "Creating fwcloud user/group and setting up permissions."
if [ "$DIST" = "FreeBSD" ]; then
  PW="pw"
else
  PW=""
fi
$PW groupadd fwcloud 2>/dev/null
$PW useradd fwcloud -g fwcloud -m -c "SOLTECSIS - FWCloud.net" -s `which bash` 2>/dev/null
if [ "$http_proxy" ]; then
  BASHRC_FILE="/home/fwcloud/.bashrc"
  echo >> "$BASHRC_FILE"
  echo "export http_proxy=\"$http_proxy\"" >> "$BASHRC_FILE"
  echo "export https_proxy=\"$https_proxy\"" >> "$BASHRC_FILE"
fi
chown -R fwcloud:fwcloud "${REPODIR}/websrv/"
chown -R fwcloud:fwcloud "${REPODIR}/ui/"
chown -R fwcloud:fwcloud "${REPODIR}/api/"
chown -R fwcloud:fwcloud "${REPODIR}/updater/"


if [ "$FWC_WEBSRV_ACTION" = "I" -o "$FWC_API_ACTION" = "I" -o "$FWC_UPDATER_ACTION" = "I" ]; then
  echo
  echo -e "\e[32m\e[1m(*) Installing required Node.js modules.\e[21m\e[0m"
  if [ "$FWC_WEBSRV_ACTION" = "I" ]; then npmInstall "websrv"; fi; echo
  if [ "$FWC_API_ACTION" = "I" ]; then npmInstall "api"; fi; echo
  if [ "$FWC_UPDATER_ACTION" = "I" ]; then npmInstall "updater"; fi
  echo "DONE"
fi


if [ "$FWC_WEBSRV_ACTION" = "I" -o "$FWC_API_ACTION" = "I" -o "$FWC_UPDATER_ACTION" = "I" ]; then
  echo
  echo -e "\e[32m\e[1m(*) TypeScript code compilation.\e[21m\e[0m"
  if [ "$FWC_WEBSRV_ACTION" = "I" ]; then runBuild "websrv"; fi
  if [ "$FWC_API_ACTION" = "I" ]; then runBuild "api"; fi
  if [ "$FWC_UPDATER_ACTION" = "I" ]; then runBuild "updater"; fi
fi


if [ "$FWC_API_ACTION" = "I" ]; then
  # Create fwcloud database.
  # Fisrt check if we need the database engine root password.
  echo
  echo -e "\e[32m\e[1m(*) FWCloud database.\e[21m\e[0m"
  echo "Next we are going to create the fwcloud database."
  MYSQL_CMD="`which mysql` -u root"
  OUT=`echo "show databases" | $MYSQL_CMD 2>&1`
  if [ "$?" != 0 ]; then # We have had an error accesing the database server.
    # Analyze the error.
    if echo "$OUT" | grep -q "Access denied"; then
      while [ 1 ]; do
        echo "The database engine root password is needed."
        read -s -p "Password: " DBPASS
        echo
        OUT=`echo "show databases" | $MYSQL_CMD -p"${DBPASS}" 2>&1`
        if [ "$?" = 0 ]; then
          break
        else 
          echo "$OUT"
          echo
        fi
      done
      MYSQL_CMD="${MYSQL_CMD} -p\"${DBPASS}\" 2>&1"
    else
      echo -e "\e[31mERROR:\e[39m Connecting to database engine."
      echo "$OUT"
      exit 1
    fi
  fi

  # Support for MySQL 8.
  IDENTIFIED_BY="identified by"
  if [ "$DBENGINE" = "MySQL" ]; then
    IS_MARIADB=`echo "show variables like 'version'" | ${MYSQL_CMD} -N | grep -i mariadb`
    # Get MySQL major version number.
    MYSQL_VERSION_MAJOR_NUMBER=`echo "show variables like 'version'" | ${MYSQL_CMD} -N | awk '{print $2}' | awk -F"." '{print $1}'`
    if [ -z "$IS_MARIADB" -a $MYSQL_VERSION_MAJOR_NUMBER -ge 8 ]; then
      IDENTIFIED_BY="identified with mysql_native_password by"
    fi 
  fi

  # Define database data.
  DBHOST="localhost"
  DBNAME="fwcloud"
  DBUSER="fwcdbusr"
  passGen 16
  DBPASS="$PASSGEN"
  echo "The next data will be used for it."
  echo -e "      \e[1mHost:\e[0m $DBHOST"
  echo -e "  \e[1mDatabase:\e[0m $DBNAME"
  echo -e "      \e[1mUser:\e[0m $DBUSER"
  echo -e "  \e[1mPassword:\e[0m $DBPASS"
  promptInput "Is it right? [Y/n] " "y n" "y"
  if [ "$OPT" = "n" ]; then
    while [ 1 ]; do
      echo
      echo "Enter new database data:"
      read -p "      Host: " DBHOST
      read -p "  Database: " DBNAME
      read -p "      User: " DBUSER
      read -p "  Password: " DBPASS

      echo
      echo "These are the new database access data:"
      echo -e "      \e[1mHost:\e[0m $DBHOST"
      echo -e "  \e[1mDatabase:\e[0m $DBNAME"
      echo -e "      \e[1mUser:\e[0m $DBUSER"
      echo -e "  \e[1mPassword:\e[0m $DBPASS"
      promptInput "Is it right? [Y/n] " "y n" "y"
      if [ "$OPT" = "y" ]; then
        break
      fi
    done
  fi

  # Now check if the fwcloud database already exists.
  OUT=`echo "show databases" | $MYSQL_CMD 2>&1 | grep "^${DBNAME}$"`
  if [ "$OUT" ]; then
    echo -e "\e[31mWARNING:\e[39m Database '$DBNAME' already exists."
    echo "If you continue the existing database will be destroyed."
    promptInput "Do you want to continue? [y/N] " "y n" "n"
    if [ "$OPT" = "n" ]; then
      echo -e "\e[31mInstallation canceled!\e[39m"
      exit 1
    fi
    runSql "drop database $DBNAME"
    runSql "drop user '${DBUSER}'@'${DBHOST}'" "I"
  fi
  runSql "create database $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci"
  runSql "create user '${DBUSER}'@'${DBHOST}' ${IDENTIFIED_BY} '${DBPASS}'"
  runSql "grant all privileges on ${DBNAME}.* to '${DBUSER}'@'${DBHOST}'"
  runSql "flush privileges"


  # Generate the .env file for fwcloud-api.
  echo
  echo -e "\e[32m\e[1m(*) Generating .env file for fwcloud-api.\e[21m\e[0m"
  cd "${REPODIR}/api"
  cp -pr "${ENVFILE}.example" "${ENVFILE}"
  sed -i "s/NODE_ENV=dev/NODE_ENV=prod/g" "${ENVFILE}"
  passGen 64
  sed -i "s/SESSION_SECRET=/SESSION_SECRET=\"$PASSGEN\"/g" "${ENVFILE}"
  passGen 64
  sed -i "s/CRYPT_SECRET=/CRYPT_SECRET=\"$PASSGEN\"/g" "${ENVFILE}"
  sed -i "s/TYPEORM_HOST=localhost/TYPEORM_HOST=\"${DBHOST}\"/g" "${ENVFILE}"
  sed -i "s/TYPEORM_DATABASE=fwcloud/TYPEORM_DATABASE=\"${DBNAME}\"/g" "${ENVFILE}"
  sed -i "s/TYPEORM_USERNAME=/TYPEORM_USERNAME=\"${DBUSER}\"/g" "${ENVFILE}"
  sed -i "s/TYPEORM_PASSWORD=/TYPEORM_PASSWORD=\"${DBPASS}\"/g" "${ENVFILE}"
  echo "DONE"


  echo
  echo -e "\e[32m\e[1m(*) Creating database schema and initial data.\e[21m\e[0m"
  cd "${REPODIR}/api"
  echo -n "Database schema ... "
  su - fwcloud -c "cd \"$REPODIR/api\"; node fwcli migration:run" >/dev/null
  if [ "$?" != 0 ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
  echo "DONE"
  echo -n "Initial data ... "
  su - fwcloud -c "cd \"$REPODIR/api\"; node fwcli migration:data" >/dev/null
  if [ "$?" != 0 ]; then
    echo -e "\e[31mInstallation canceled!\e[39m"
    exit 1
  fi
  echo "DONE"
fi


if [ "$FWC_WEBSRV_ACTION" = "I" -o "$FWC_API_ACTION" = "I" -o "$FWC_UPDATER_ACTION" = "I" ]; then
  # TLS setup.
  echo
  echo -e "\e[32m\e[1m(*) Secure communications.\e[21m\e[0m"
  echo "Although it is possible to use communication without encryption, both at the user interface"
  echo "and the API level, it is something that should only be done in a development environment."
  echo "In a production environment it is highly advisable to use encrypted communications" 
  echo "both at the level of access to the user interface and in accessing the API."
  promptInput "Do you want to use secure communications? [Y/n] " "y n" "y"
  if [ "$OPT" = "y" ]; then
    HTTP_PROTOCOL="https://"
    if [ "$FWC_WEBSRV_ACTION" = "I" ]; then buildTlsCertificate "websrv"; fi
    if [ "$FWC_API_ACTION" = "I" ]; then buildTlsCertificate "api"; fi
    if [ "$FWC_UPDATER_ACTION" = "I" ]; then buildTlsCertificate "updater"; fi
  else
    HTTP_PROTOCOL="http://"
    echo >> "${ENVFILE}"
    echo >> "${ENVFILE}"
    if [ "$FWC_WEBSRV_ACTION" = "I" ]; then
      cd "${REPODIR}/websrv/"
      echo "HTTPS_ENABLED=false" >> "${ENVFILE}"
      echo "FWC_API_URL=\"http://localhost:${FWC_API_PORT}\"" >> "${ENVFILE}"
    fi
    if [ "$FWC_API_ACTION" = "I" ]; then
      cd "${REPODIR}/api/"
      echo "APISRV_HTTPS=false" >> "${ENVFILE}"
      echo "SESSION_FORCE_HTTPS=false" >> "${ENVFILE}"
      echo "FWC_UPDATER_URL=\"http://localhost:${FWC_UPDATER_PORT}\"" >> "${ENVFILE}"
    fi
    if [ "$FWC_UPDATER_ACTION" = "I" ]; then
      cd "${REPODIR}/updater/"
      echo "HTTPS_ENABLED=false" >> "${ENVFILE}"
    fi
  fi
fi

if [ "$FWC_API_ACTION" = "I" ]; then
  # CORS.
  echo 
  echo -e "\e[32m\e[1m(*) CORS (Cross-Origin Resource Sharing) whitelist setup.\e[21m\e[0m"
  echo "It is important that you include in this list the URL that you will use for access fwcloud-ui."
  IPL=`ip a |grep "    inet " | awk -F"    inet " '{print $2}' | awk -F"/" '{print $1}' | grep -v "^127.0.0.1$"`
  CORSWL=""
  cd "${REPODIR}/api/"
  for IP in $IPL; do
    if [ ! -z "$CORSWL" ]; then
      CORSWL="$CORSWL, "
    fi
    CORSWL="${CORSWL}${HTTP_PROTOCOL}${IP}:3030"
  done
  while [ 1 ]; do
    echo -e "CORS white list: \e[1m${CORSWL}\e[0m"

    promptInput "Is it right? [Y/n] " "y n" "y"
    if [ "$OPT" = "y" ]; then
      break
    fi

    echo "Enter the new CORS white list (coma separated items):"
    read -e -p "" -i "$CORSWL" CORSWL
  done
  sed -i "s|CORS_WHITELIST=\"http://localhost\"|CORS_WHITELIST=\"${CORSWL}\"|g" "${ENVFILE}"
fi

if [ "$FWC_WEBSRV_ACTION" = "I" -o "$FWC_API_ACTION" = "I" -o "$FWC_UPDATER_ACTION" = "I" ]; then
  echo
  echo -e "\e[32m\e[1m(*) Enabling and starting services.\e[21m\e[0m"
  if [ "$FWC_WEBSRV_ACTION" = "I" ]; then enableStartFWCloudService "websrv" "$FWC_WEBSRV_PORT"; fi
  if [ "$FWC_API_ACTION" = "I" ]; then enableStartFWCloudService "api" "$FWC_API_PORT"; fi
  if [ "$FWC_UPDATER_ACTION" = "I" ]; then enableStartFWCloudService "updater" "$FWC_UPDATER_PORT"; fi
fi

echo
echo -e "\e[32m\e[1m--- PROCESS COMPLETED ----\e[21m\e[0m"
echo "Your FWCloud system is ready!"
echo

if [ "$FWC_API_ACTION" = "I" ]; then
  echo -e "Access it using one of the CORS white list URLs: \e[96m$CORSWL\e[0m"
  echo
  echo "These are the default login credentials:"
  echo -e "  Customer code: \e[96m1\e[0m"
  echo -e "       Username: \e[96mfwcadmin\e[0m"
  echo -e "       Password: \e[96mfwcadmin\e[0m"
  echo
fi

pkgInstalled "firewalld"
if [ "$?" = "1" ]; then
  echo -e "\e[31mWARNING:\e[0m Package firewalld is installed."
  echo "You will have to allow access to TCP port 3030 in your firewalld policy."
  echo
fi

echo "If you need help please contact us:"
echo -e "\e[93minfo@fwcloud.net\e[0m"
echo -e "\e[93mhttps://fwcloud.net\e[0m"
echo -e "\e[32m\e[1m--------------------------\e[21m\e[0m"
echo

exit 0

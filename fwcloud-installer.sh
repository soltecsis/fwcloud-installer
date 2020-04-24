#!/bin/bash

# Default variables values.
FWCLOUD_API_PORT="3131"
FWCLOUD_WEB_PORT="3030"
REPODIR="/opt"

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
promptInput() {
  # $1=Text message.
  # $2=Accepted values.
  # $3=Default value.

  read -s -n1 -p "$1" OPT

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
pkgInstall() {
  # $1=Display name.
  # $2=pkg name.

  echo -n -e "\e[96mPACKAGE: \e[39m${1} ... "
  OUT=`dpkg -s $2 2>/dev/null | grep "^Status: install ok installed"`
  if [ -z "$OUT" ]; then
    echo -e "\e[1m\e[33mNOT FOUND. \e[39mInstalling ... \e[0m"
    apt install $2
    echo "DONE."
  else
    echo "FOUND."
  fi
  echo
}
################################################################

################################################################
runSql() {
  # $1=SQL.
  
  RESULT=`echo "$1" | $MYSQL_CMD 2>&1`
  if [ "$?" != "0" ]; then
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
  echo "Generating GPG keys pair for ${1} ... "

  CN="${1}-`pwgen 32 1 -s`"
  generateOpensslConfig "$CN"

  # Private key.
  openssl genrsa -out ${1}.key 2048

  # CSR.
  openssl req -config ./openssl.cnf -new -key ${1}.key -nodes -out ${1}.csr

  # Certificate.
  # WARNING: If we indicate more than 825 days for the certificate expiration date
  # we will not be able to access from Google Chrome web browser.
  openssl x509 -extfile ./openssl.cnf -extensions cert_ext -req \
    -days 825 \
    -signkey ${1}.key -in ${1}.csr -out ${1}.crt
   
  rm openssl.cnf
  rm "${1}.csr"

  chown fwcloud:fwcloud "${1}.key" "${1}.crt"
  echo "DONE."
}
################################################################


clear
printCopyright

echo
echo "This shell script will install FWCloud on your system."
echo "Projects fwcloud-api and fwcloud-ui will be installed from GitHub."
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


echo -e "\e[32m\e[1m(*) Linux distribution.\e[21m\e[0m"
DIST=`cat /etc/issue | head -n 1 | awk '{print $1}'`
case $DIST in
  Ubuntu|Debian) 
    echo "Ok, you are running ${DIST}, a supported Linux distribution."
    ;;
  *)
    echo "Your Linux distribution (${DIST}) is not supported."
    promptInput "Do you want to continue? [y/N] " "y n" "n"
    if [ "$OPT" = "n" ]; then
      echo -e "\e[31mInstallation canceled!\e[39m"
      exit 1
    fi
    ;;
esac
echo 


# Install required packages.
echo -e "\e[32m\e[1m(*) Searching for required packages.\e[21m\e[0m"
pkgInstall "lsof" "lsof"
pkgInstall "pwgen" "pwgen"
pkgInstall "git" "git"
pkgInstall "build-essential" "build-essential"
pkgInstall "curl" "curl"
pkgInstall "net-tools" "net-tools"
pkgInstall "OpenSSL" "openssl"
pkgInstall "OpenVPN" "openvpn"
echo -n "Setting up Node.js repository ... "
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - >/dev/null 2>&1
echo "DONE."
pkgInstall "Node.js" "nodejs"


# Select database engine.
echo -e "\e[32m\e[1m(*) Database engine.\e[21m\e[0m"
echo "FWCloud needs a MariaDB or MySQL database engine."
# Check first if we already have one of the installed.
if [ "$DIST" = "Debian" ]; then
  MARIADB_PKG="mariadb-server"
  MYSQL_PKG="default-mysql-server"
else
  MARIADB_PKG="mariadb-server"
  MYSQL_PKG="mysql-server"
fi
dpkg -s $MARIADB_PKG >/dev/null 2>&1
if [ "$?" = "0" ]; then
  echo "MariaDB ... FOUND."
else
  dpkg -s $MYSQL_PKG >/dev/null 2>&1
  if [ "$?" = "0" ]; then
    echo "MySQL ... FOUND."
  else
    echo "Please select the database engine to install:"
    echo "  (1) MySQL"
    echo "  (2) MariaDB"
    promptInput "(1/2)? [1] " "1 2" "1"
    echo
    if [ "$OPT" = "1" ]; then
      pkgInstall "MySQL" "$MYSQL_PKG"
    else
      pkgInstall "MariaDB" "$MARIADB_PKG"
    fi
  fi
fi
echo


# Check if TPC ports used for fwcloud-api are in use.
echo -e "\e[32m\e[1m(*) Cheking FWCloud TCP ports.\e[21m\e[0m"
echo -n "TCP port ${FWCLOUD_API_PORT} for fwcloud-api ... "
OUT=`lsof -nP -iTCP -sTCP:LISTEN | grep "\:${FWCLOUD_API_PORT}"`
if [ "$OUT" ]; then
  echo -e "\e[31mIN USE!\e[39m"
  lsof -nP -iTCP -sTCP:LISTEN | head -n 1
  echo "$OUT"
  exit 1
fi
echo "OK."

echo -n "TCP port ${FWCLOUD_WEB_PORT} for fwcloud-ui ... "
OUT=`lsof -nP -iTCP -sTCP:LISTEN | grep "\:${FWCLOUD_WEB_PORT}"`
if [ "$OUT" ]; then
  echo -e "\e[31mIN USE!\e[39m"
  lsof -nP -iTCP -sTCP:LISTEN | head -n 1
  echo "$OUT"
  exit 1
fi
echo "OK."
echo


# Cloning GitHub repositories.
echo -e "\e[32m\e[1m(*) Cloning GitHub repositories.\e[21m\e[0m"
echo "Now we are going to clone the fwcloud-api and fwcloud-ui GitHub repositories."
echo "These repositories will be cloned into the directory: ${REPODIR}"
promptInput "Is it right? [Y/n] " "y n" "y"
if [ "$OPT" = "n" ]; then
  read -p "New directory: " REPODIR
fi

if [ ! -d "$REPODIR" ]; then
  echo -e "\e[31mERROR:\e[39m Directory don't exists: ${REPODIR}"
  exit 1
fi

echo
cd "$REPODIR"
git clone https://github.com/soltecsis/fwcloud-api.git
if [ "$?" != "0" ]; then
  exit 1
fi

echo
cd "$REPODIR"
git clone https://github.com/soltecsis/fwcloud-ui.git
if [ "$?" != "0" ]; then
  exit 1
fi

echo
echo -e "\e[32m\e[1m(*) Setting up permissions.\e[21m\e[0m"
echo "Creating fwcloud user/group and setting up permissions."
groupadd fwcloud 2>/dev/null
useradd fwcloud -g fwcloud -m -c "SOLTECSIS - FWCloud.net" -s /bin/bash 2>/dev/null
chown -R fwcloud:fwcloud "${REPODIR}/fwcloud-api/"
chown -R fwcloud:fwcloud "${REPODIR}/fwcloud-ui/"


echo
echo -e "\e[32m\e[1m(*) Branch select.\e[21m\e[0m"
#promptInput "Select git branch (master/develop) ? [M/d] " "m d" "m"
#if [ "$OPT" = "m" ]; then
#  BRANCH="master"
#else
#  BRANCH="develop"
#fi
echo "At this moment only the develop branch is available."
BRANCH="develop"
echo "Selecting branch for the fwcloud-api project ... "
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; git checkout $BRANCH"
echo "DONE."
echo


echo
echo -e "\e[32m\e[1m(*) Installing required Node.js modules.\e[21m\e[0m"
cd "$REPODIR/fwcloud-api"
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm install"


echo
echo -e "\e[32m\e[1m(*) TypeScript code compilation.\e[21m\e[0m"
echo -n "Compiling ... "
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm run build" >/dev/null
if [ "$?" != 0 ]; then
  echo -e "\e[31mInstallation canceled!\e[39m"
  exit 1
fi
echo "DONE."


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

# Define database data.
DBHOST="localhost"
DBNAME="fwcloud"
DBUSER="fwcdbusr"
DBPASS=`pwgen 16 1`
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
  runSql "drop user '${DBUSER}'@'${DBHOST}'"
fi
runSql "create database $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci"
runSql "create user '${DBUSER}'@'${DBHOST}' identified by '${DBPASS}'"
runSql "grant all privileges on ${DBNAME}.* to '${DBUSER}'@'${DBHOST}'"
runSql "flush privileges"
echo


# Generate the .env file for fwcloud-api.
echo -e "\e[32m\e[1m(*) Generating .env file for fwcloud-api.\e[21m\e[0m"
ENVFILE="${REPODIR}/fwcloud-api/.env"
cp -pr "${ENVFILE}.example" "${ENVFILE}"
sed -i "s/NODE_ENV=dev/NODE_ENV=prod/g" "${ENVFILE}"
sed -i "s/SESSION_SECRET=/SESSION_SECRET=\"`pwgen 64 1 -s`\"/g" "${ENVFILE}"
sed -i "s/CRYPT_SECRET=/CRYPT_SECRET=\"`pwgen 64 1 -s`\"/g" "${ENVFILE}"
sed -i "s/TYPEORM_HOST=localhost/TYPEORM_HOST=\"${DBHOST}\"/g" "${ENVFILE}"
sed -i "s/TYPEORM_DATABASE=fwcloud/TYPEORM_DATABASE=\"${DBNAME}\"/g" "${ENVFILE}"
sed -i "s/TYPEORM_USERNAME=/TYPEORM_USERNAME=\"${DBUSER}\"/g" "${ENVFILE}"
sed -i "s/TYPEORM_PASSWORD=/TYPEORM_PASSWORD=\"${DBPASS}\"/g" "${ENVFILE}"
if [ "$REPODIR" != "/opt" ]; then
  echo >> "${ENVFILE}"
  echo "WEBSRV_DOCROOT=\"${REPODIR}/fwcloud-ui/dist\"" >> "${ENVFILE}"
fi
echo "DONE."
echo


echo -e "\e[32m\e[1m(*) Creating database schema and initial data.\e[21m\e[0m"
cd "${REPODIR}/fwcloud-api"
echo -n "Database schema ... "
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm run fwcloud migration:run" >/dev/null
if [ "$?" != 0 ]; then
  echo -e "\e[31mInstallation canceled!\e[39m"
  exit 1
fi
echo "DONE."
echo -n "Initial data ... "
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm run fwcloud migration:data" >/dev/null
if [ "$?" != 0 ]; then
  echo -e "\e[31mInstallation canceled!\e[39m"
  exit 1
fi
echo "DONE."
echo


# TLS setup.
echo -e "\e[32m\e[1m(*) Secure communications.\e[21m\e[0m"
echo "Although it is possible to use communication without encryption, both at the user interface"
echo "and the API level, it is something that should only be done in a development environment."
echo "In a production environment it is highly advisable to use encrypted communications" 
echo "both at the level of access to the user interface and in accessing the API."
promptInput "Do you want to use secure communications? [Y/n] " "y n" "y"
if [ "$OPT" = "y" ]; then
  HTTP_PROTOCOL="https://"
  mkdir "${REPODIR}/fwcloud-api/config/tls"
  chown fwcloud:fwcloud "${REPODIR}/fwcloud-api/config/tls"
  cd "${REPODIR}/fwcloud-api/config/tls"
  buildTlsCertificate fwcloud-web
  echo
  buildTlsCertificate fwcloud-api
else
  HTTP_PROTOCOL="http://"
  echo >> "${ENVFILE}"
  echo >> "${ENVFILE}"
  echo "WEBSRV_HTTPS=false" >> "${ENVFILE}"
  echo "WEBSRV_API_URL=\"http://localhost:3000\"" >> "${ENVFILE}"
  echo "APISRV_HTTPS=false" >> "${ENVFILE}"
  echo "SESSION_FORCE_HTTPS=false" >> "${ENVFILE}"
fi
echo 


# CORS.
echo -e "\e[32m\e[1m(*) CORS (Cross-Origin Resource Sharing) whitelist setup.\e[21m\e[0m"
echo "It is important that you include in this list the URL that you will use for access fwcloud-ui."
IPL=`ip a |grep "    inet " | awk -F"    inet " '{print $2}' | awk -F"/" '{print $1}' | grep -v "^127.0.0.1$"`
CORSWL=""
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
echo


echo -e "\e[32m\e[1m(*) Enabling and starting fwcloud-api service.\e[21m\e[0m"
cp "${REPODIR}/fwcloud-api/config/sys/fwcloud-api.service" /etc/systemd/system/
sed -i "s|/opt/|${REPODIR}/|g" "/etc/systemd/system/fwcloud-api.service"
echo -n "Enabling at boot ... "
systemctl enable fwcloud-api >/dev/null 2>&1
echo "DONE"
echo -n "Starting "
systemctl start fwcloud-api
while [ 1 ]; do
  sleep 1
  echo -n "."
  OUT=`netstat -tan | grep " 0\.0\.0\.0\:${FWCLOUD_WEB_PORT} "`
  if [ "$OUT" ]; then
    break
  fi
done
echo " DONE"
echo

echo -e "\e[32m\e[1m--- PROCESS COMPLETED ----\e[21m\e[0m"
echo "Your FWCloud system is ready!"
echo
echo -e "Access it using one of the CORS white list URLs: \e[96m$CORSWL\e[0m"
echo
echo "Using the default login credentials:"
echo -e "  Customer code: \e[96m1\e[0m"
echo -e "       Username: \e[96mfwcadmin\e[0m"
echo -e "       Password: \e[96mfwcadmin\e[0m"
echo
echo "If you need help please contac us:"
echo -e "\e[93minfo@fwcloud.net\e[0m"
echo -e "\e[93mhttps://fwcloud.net\e[0m"
echo -e "\e[32m\e[1m--------------------------\e[21m\e[0m"
echo
exit 0

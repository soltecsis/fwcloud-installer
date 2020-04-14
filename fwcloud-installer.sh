#!/bin/bash

################################################################
printCopyright() {
  echo "#################################################################################"
  echo "#                                                                               #"
  echo "#  Copyright 2020 SOLTECSIS SOLUCIONES TECNOLOGICAS, SLU                        #"
  echo "#    https://soltecsis.com                                                      #"
  echo "#    info@soltecsis.com                                                         #"
  echo "#                                                                               #"
  echo "#                                                                               #"
  echo "#  This file is part of FWCloud (https://fwcloud.net).                          #"
  echo "#                                                                               #"
  echo "#  FWCloud is free software: you can redistribute it and/or modify              #"
  echo "#  it under the terms of the GNU Affero General Public License as published by  #"
  echo "#  the Free Software Foundation, either version 3 of the License, or            #"
  echo "#  (at your option) any later version.                                          #"
  echo "#                                                                               #"
  echo "#  FWCloud is distributed in the hope that it will be useful,                   #"
  echo "#  but WITHOUT ANY WARRANTY; without even the implied warranty of               #"
  echo "#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #"
  echo "#  GNU General Public License for more details.                                 #"
  echo "#                                                                               #"
  echo "#  You should have received a copy of the GNU General Public License            #"
  echo "#  along with FWCloud.  If not, see <https://www.gnu.org/licenses/>.            #"
  echo "#                                                                               #"
  echo "#################################################################################"
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

  echo -n "${1} ... "
  dpkg -s $2 >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    echo "NOT FOUND. Installing ..."
    apt install $2
    echo
  else
    echo "FOUND."
  fi
}
################################################################

################################################################
runSql() {
  # $1=SQL.
  
  RESULT=`echo "$1" | $MYSQL_CMD 2>&1`
  if [ "$?" != "0" ]; then
    echo "ERROR: Executing SQL: $1"
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
  echo "Done!"
}
################################################################


clear
printCopyright

echo
echo "This shell script will install FWCloud on your system."
echo "Projects fwcloud-api and fwcloud-ui will be installed from GitHub."
promptInput "Continue (y/n) [y] ? " "y n" "y"
if [ "$OPT" = "n" ]; then
  echo "Aborting!"
  exit 0
fi
echo


# Check if we are the root user or a user with sudo privileges.
# If not, error.
if [ "$EUID" != "0" ]; then
  echo "Please run as root or using the sudo command."
  exit 0
fi


# Install required packages.
echo "Searching for required packages."
pkgInstall "OpenVPN" "openvpn"
pkgInstall "pwgen" "pwgen"
pkgInstall "git" "git"
pkgInstall "build-essential" "build-essential"
pkgInstall "curl" "curl"
pkgInstall "OpenSSL" "openssl"
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - >/dev/null 2>&1
pkgInstall "Node.js" "nodejs"
echo


# Select database engine.
echo "FWCloud needs a MariaDB or MYSQL_CMD database engine."
# Check first if we already have one of the installed.
dpkg -s mariadb-server >/dev/null 2>&1
if [ "$?" = "0" ]; then
  echo "MariaDB ... FOUND."
else
  dpkg -s mysql-server >/dev/null 2>&1
  if [ "$?" = "0" ]; then
    echo "MySQL ... FOUND."
  else
    echo "Please select the database engine to install:"
    echo "  (1) MariaDB"
    echo "  (2) MySQL"
    promptInput "(1/2) [1] ? " "1 2" "1"
    if [ "$OPT" = "1" ]; then
      pkgInstall "MariaDB" "mariadb-server"
    else
      pkgInstall "MySQL" "mysql-server"
    fi
  fi
fi
echo


# Cloning GitHub repositories.
REPODIR="/opt"
echo "Now we are going to clone the fwcloud-api and fwcloud-ui GitHub repositories."
echo "This repositories will be cloned into the directory: ${REPODIR}"
promptInput "Do you want to change to another directory (y/n) [n] ? " "y n" "n"
if [ "$OPT" = "y" ]; then
  read -p "New directory: " REPODIR
fi

if [ ! -d "$REPODIR" ]; then
  echo "ERROR: Directory don't exists: ${REPODIR}"
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
echo "Creating user and group fwcloud and setting up permisions."
groupadd fwcloud 2>/dev/null
useradd fwcloud -g fwcloud -m -c "SOLTECSIS - FWCloud.net" -s /bin/bash 2>/dev/null
chown -R fwcloud:fwcloud "${REPODIR}/fwcloud-api/"
chown -R fwcloud:fwcloud "${REPODIR}/fwcloud-ui/"


echo
echo "Installing required Node.js modules."
cd "$REPODIR/fwcloud-api"
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm install"


# Create fwcloud database.
# Fisrt check if we need the database engine root password.
echo
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
    echo "ERROR: Connecting to database engine."
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
echo "      Host: $DBHOST"
echo "  Database: $DBNAME"
echo "      User: $DBUSER"
echo "  Password: $DBPASS"
promptInput "Do you want to change these data (y/n) [n] ? " "y n" "n"
if [ "$OPT" = "y" ]; then
  while [ 1 ]; do
    echo
    echo "Enter new database data:"
    read -p "      Host: " DBHOST
    read -p "  Database: " DBNAME
    read -p "      User: " DBUSER
    read -p "  Password: " DBPASS

    echo
    echo "These are the new database data:"
    echo "      Host: $DBHOST"
    echo "  Database: $DBNAME"
    echo "      User: $DBUSER"
    echo "  Password: $DBPASS"
    promptInput "Continue (y/n) [y] ? " "y n" "y"
    if [ "$OPT" = "y" ]; then
      break
    fi
  done
fi

# Now check if the fwcloud database already exists.
OUT=`echo "show databases" | $MYSQL_CMD 2>&1 | grep "^${DBNAME}$"`
if [ "$OUT" ]; then
  echo "WARNING: Database '$DBNAME' already exists."
  echo "If you continue the existing database will be destroyed."
  promptInput "Continue (y/n) [n] ? " "y n" "n"
  if [ "$OPT" = "n" ]; then
    echo "Aborting!"
    exit 1
  fi
  runSql "drop database $DBNAME"
  runSql "drop user '${DBUSER}'@'${DBHOST}'"
fi
runSql "create database $DBNAME"
runSql "create user '${DBUSER}'@'${DBHOST}' identified by '${DBPASS}'"
runSql "grant all privileges on ${DBNAME}.* to '${DBUSER}'@'${DBHOST}'"
runSql "flush privileges"
echo


# Generate the .env file for fwcloud-api.
echo "Generating the .env file for fwcloud-api."
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
echo


echo "Creating database schema and initial data."
cd "${REPODIR}/fwcloud-api"
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm run fwcloud migration:run"
su - fwcloud -c "cd \"$REPODIR/fwcloud-api\"; npm run fwcloud migration:data"
echo


# CORS.
echo ""


# TLS setup.
echo "Although it is possible to use communication without encryption, both at the user interface"
echo "and the API level, it is something that should only be done in a development environment."
echo "In a production environment it is highly advisable to use encrypted communications" 
echo "both at the level of access to the user interface and in accessing the API."
promptInput "Do you want to use secure communications (y/n) [y] ? " "y n" "y"
if [ "$OPT" = "y" ]; then
  mkdir "${REPODIR}/fwcloud-api/config/tls"
  chown fwcloud:fwcloud "${REPODIR}/fwcloud-api/config/tls"
  cd "${REPODIR}/fwcloud-api/config/tls"
  buildTlsCertificate fwcloud-web
  echo
  buildTlsCertificate fwcloud-api
else
  echo >> "${ENVFILE}"
  echo >> "${ENVFILE}"
  echo "WEBSRV_HTTPS=false" >> "${ENVFILE}"
  echo "WEBSRV_API_URL=\"http://localhost:3000\"" >> "${ENVFILE}"
  echo "APISRV_HTTPS=false" >> "${ENVFILE}"
  echo "SESSION_FORCE_HTTPS=false" >> "${ENVFILE}"
fi
echo 


echo "Enabling fwcloud-api service."
cp "${REPODIR}/fwcloud-api/config/sys/fwcloud-api.service" /etc/systemd/system/
systemctl enable fwcloud-api
systemctl start fwcloud-api
echo

exit 0


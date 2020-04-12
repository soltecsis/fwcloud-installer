#!/bin/bash

################################################################
print_copyright () {
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
prompt_input () {
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
pkg_install () {
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

clear
print_copyright

echo
echo "This shell script will install FWCloud on your system."
echo "Projects fwcloud-api and fwcloud-ui will be installed from Github."
prompt_input "Continue (y/n) [y] ? " "y n" "y"
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


# Default installation directory.
# If the directory already exists generate a warning message.


echo "Searching for required packages."
pkg_install "OpenVPN" "openvpn"
pkg_install "pwgen" "pwgen"
echo

# Select database engine.
echo "FWCloud needs a MariaDB or MySQL database engine."
# Check first if we already have one of the installed.
dpkg -s mariadb-server >/dev/null 2>&1
if [ "$?" = "0" ]; then
  echo "MariaDB ... FOUND."
else
  dpkg -s mysql-server >/dev/null 2>&1
  if [ "$?" = "0" ]; then
    echo "MySQL ... FOUND."
  else
    prompt_input "MariaDB or MySQL (mariadb/mysql) [mariadb] ? " "mariadb mysql" "mariadb"
    if [ "$OPT" = "mariadb" ]; then
      pkg_install "MariaDB" "mariadb"
    else
      pkg_install "MySQL" "mysql"
    fi
  fi
fi

exit 0


#sudo apt-get install -y pwgen
sudo apt-get install -y openvpn
cd /opt/
$ sudo git clone https://github.com/soltecsis/fwcloud-api.git

sudo apt install -y mysql-server

exit 0
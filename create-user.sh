#!/bin/bash
# Created by Marco Vilera.
set -e

# SOLICITAMOS INFORMACION DEL USUARIO
echo "Please enter the USERNAME and press [ENTER]: "
read USERNAME
echo "Please enter the PASSWORD and press [ENTER]: "
read -s PASSWORD
echo "Do you wish the new user have SSH access? answer [yes/no] then press [ENTER]: "
read SHELL_ALLOWED
echo "Do you wish the new user have FTP access? answer [yes/no] then press [ENTER]: "
read FTP


USERLIST=/userlist.file
FTP_ROOT=/home/$USERNAME/ftp
FTP_FILES_DIR=/home/$USERNAME/ftp/files
USERADD_PARAMETERS="-U $USERNAME --create-home"
FTPLIST=/ftp.list

# VERIFICAMOS SI EL USUARIO YA EXISTE
if ! id -u $USERNAME > /dev/null 2>&1; then

  # VERIFICAMOS SI DEBEMOS CREAR SHELL ACCESS O NO
  shopt -s nocasematch
  if [[ "$SHELL_ALLOWED" == "yes" ]]; then
    CHOOSEN_SHELL="/bin/bash"
  else
    CHOOSEN_SHELL="/sbin/nologin"
  fi
  shopt -u nocasematch

  USERADD_PARAMETERS="$USERADD_PARAMETERS --shell $CHOOSEN_SHELL"

  # CREAMOS USUARIO
  useradd $USERADD_PARAMETERS
  echo "$USERNAME:$PASSWORD" | chpasswd

  # CREAMOS DIRECTORIOS PARA EL CHROOT DE VSFTPD
  mkdir -p $FTP_FILES_DIR
  chown nobody:nogroup $FTP_ROOT
  chmod a-w $FTP_ROOT
  chown $USERNAME:$USERNAME $FTP_FILES_DIR

  # GENERAMOS LLAVES PUB/PRIV
  ssh-keygen -t rsa -q -N "" -f /keys/$USERNAME

  # CONCEDEMOS ACCESO POR MEDIO DE LLAVE PUBLICA
  mkdir -p /home/$USERNAME/.ssh
  touch /home/$USERNAME/.ssh/authorized_keys
  cat /keys/$USERNAME.pub >> /home/$USERNAME/.ssh/authorized_keys
  chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys
  chmod 600 /home/$USERNAME/.ssh/authorized_keys

  # AÑADIMOS AL USUARIO AL DENY LIST DEL FTP SI NO SE LE CONCEDE PERMISOS
  shopt -s nocasematch
  if [[ "$FTP" == "no" ]]; then
    grep -q -F "$USERNAME" $FTPLIST || echo "$USERNAME" >> $FTPLIST
  fi
  shopt -u nocasematch

  # AÑADIMOS EL USUARIO AL ARCHIVO LISTA CON LOS PARAMETROS DE CREACION
  if [ -f $USERLIST ]; then
    grep -q -F "$USERNAME:$PASSWORD" $USERLIST || echo "$USERNAME:$PASSWORD:$CHOOSEN_SHELL:$FTP" >> $USERLIST
  else
    echo "$USERNAME:$PASSWORD:$CHOOSEN_SHELL:$FTP" >> $USERLIST
  fi

  echo "User created succesfully."
else
  echo "User already exists."
fi

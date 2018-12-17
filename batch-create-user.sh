#!/bin/bash
# Created by Marco Vilera.
set -e

USERLIST=/userlist.file
FTP_ROOT=/home/$USERNAME/ftp
FTP_FILES_DIR=/home/$USERNAME/ftp/files

while IFS=: read USERNAME PASSWORD CHOOSEN_SHELL FTP; do
	# CREAMOS USUARIO Y PASSWORD SI NO EXISTE
  if ! id -u $USERNAME > /dev/null 2>&1; then
    useradd --home /home/$USERNAME --shell $CHOOSEN_SHELL -U $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
  fi
done < "$USERLIST"
unset IFS

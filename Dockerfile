FROM ubuntu:16.04

# INSTALAR VSFTPD, OPENSSH-SERVER Y SUPERVISORD
RUN apt-get update && \
    apt-get install -y supervisor && \
    apt-get install -y vsftpd openssh-server && \
    rm -rf /var/lib/apt/lists/*

# CREAMOS DIRECTORIOS NECESARIOS
RUN mkdir /etc/vsftpd && \
    mkdir -p /var/run/vsftpd/empty && \
    mkdir -p /etc/ssl/private/clients/pems && \
    mkdir /etc/ssl/private/ca && \
    mkdir /etc/ssl/private/service && \
    mkdir -p /var/run/sshd

VOLUME ["/pems"]

# VARIABLES DE ENTORNO PARA DEFINIR USUARIO Y ADMIN
ENV FTP_ADMIN=admin \
    FTP_ADMIN_PASSWORD=admin \
    FTP_USER=user \
    FTP_USER_PASSWORD=user

# CREAR USUARIOS
RUN useradd --create-home --shell /bin/bash -U $FTP_ADMIN && \
    useradd --create-home --shell /bin/bash -U $FTP_USER

# SETEAMOS LAS CLAVES DE LOS USUARIOS
RUN echo "$FTP_USER:$FTP_USER_PASSWORD" | chpasswd
RUN echo "$FTP_ADMIN:$FTP_ADMIN_PASSWORD" | chpasswd

# RESTRICCIONES DE ACCESO Y CREACION DE DIRECTORIO DE DATOS PARA LOS USUARIOS
RUN chown root /home/$FTP_USER && chmod 770 /home/$FTP_USER && \
    chown root /home/$FTP_ADMIN && chmod 770 /home/$FTP_ADMIN

WORKDIR /etc/ssl/private

# GENERAR CA
RUN openssl req \
	-newkey rsa:2048 -nodes -keyout ca/ca.key \
	-x509 -days 365 -out ca/ca.crt \
	-subj "/C=US/ST=New York/L=Brooklyn/O=Compania Prueba/CN=prueba.com"

# GENERAR KEY Y CSR PARA SSL/TLS
RUN openssl genrsa -out service/vsftpd.key 2048 && \
    openssl req -new -key service/vsftpd.key -out service/vsftpd.csr -subj "/C=US/ST=New York/L=Brooklyn/O=Compania Prueba/CN=prueba.com"

# GENERAR KEY Y CSR PARA USO DE FTP
RUN openssl genrsa -out clients/ftp.key 2048 && \
    openssl req -new -key clients/ftp.key -out clients/ftp.csr -subj "/C=US/ST=New York/L=Brooklyn/O=Compania Prueba/CN=prueba.com"

# FIRMAR CSR PARA SSL/TLS USANDO NUESTRO CA
RUN openssl x509 -req -days 365 -in service/vsftpd.csr -CA ca/ca.crt -CAkey ca/ca.key -set_serial 01 -out service/vsftpd.crt 

# FIRMAR CSR PARA FTP USANDO NUESTRO CA
RUN openssl x509 -req -days 365 -in clients/ftp.csr -CA ca/ca.crt -CAkey ca/ca.key -set_serial 01 -out clients/ftp.crt

# ARCHIVOS PEM
RUN cat service/vsftpd.key service/vsftpd.crt > vsftpd.pem 				# vsftpd.pem
RUN cat clients/ftp.crt > cacerts.pem							# cacerts.pem
RUN cat clients/ftp.key clients/ftp.crt > clients/pems/ftp.pem				# ftp_admin.pem

# AGREGAMOS USUARIOS AL CHROOT_LIST
RUN echo $FTP_ADMIN > /etc/vsftpd/chroot_list && \
    echo $FTP_USER >> /etc/vsftpd/chroot_list

COPY vsfptd_conf.sh /etc/vsftpd/vsftpd.conf

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# ACTIVAMOS MODO FOREGROUND PARA SUPERVISORD
RUN sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true/' /etc/supervisor/supervisord.conf

ENTRYPOINT ["/entrypoint.sh"]

CMD supervisord -c /etc/supervisor/supervisord.conf

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
RUN cat clients/ftp.crt > cacerts.pem							                # cacerts.pem
RUN cat clients/ftp.key clients/ftp.crt > clients/pems/ftp.pem		# ftp_admin.pem

RUN touch /etc/vsftpd/chroot_list

COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY entrypoint.sh /entrypoint.sh
COPY create-user.sh /bin/create-user
COPY batch-create-user.sh /bin/batch-create-user
COPY data/userlist.file /userlist.file
COPY data/ftp.list /ftp.list

RUN chmod u+x /entrypoint.sh && \
    chmod u+x /bin/batch-create-user && \
    chmod u+x /bin/create-user

RUN echo "/sbin/nologin" >> /etc/shells

# ACTIVAMOS MODO FOREGROUND PARA SUPERVISORD
RUN sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true/' /etc/supervisor/supervisord.conf

ENTRYPOINT ["/entrypoint.sh"]

CMD supervisord -c /etc/supervisor/supervisord.conf

# Docker container for Observium Community Edition

FROM ubuntu:20.04

LABEL maintainer "darko@krizic.net"
LABEL version="1.0"
LABEL description="Docker container for Observium Community Edition"

ARG OBSERVIUM_DB_HOST=observiumdb
ARG OBSERVIUM_DB_USER=observium
ARG OBSERVIUM_DB_PASS=passw0rd
ARG OBSERVIUM_DB_NAME=observium

# set environment variables
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV OBSERVIUM_DB_HOST=$OBSERVIUM_DB_HOST
ENV OBSERVIUM_DB_USER=$OBSERVIUM_DB_USER
ENV OBSERVIUM_DB_PASS=$OBSERVIUM_DB_PASS
ENV OBSERVIUM_DB_NAME=$OBSERVIUM_DB_NAME

# install prerequisites and cleanup
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get install -y libapache2-mod-php7.4 php7.4-cli php7.4-mysql php7.4-mysqli php7.4-gd php7.4-json \
    php-pear snmp fping mysql-client python3-mysqldb rrdtool subversion whois mtr-tiny \
    ipmitool graphviz imagemagick apache2 python3-pymysql python-is-python3 \
    cron locales supervisor wget curl
RUN rm -f /etc/apache2/sites-available/* && \
    rm -f /etc/cron.d/* && \
    rm -f /etc/cron.hourly/* && \
    rm -f /etc/cron.daily/* && \
    rm -f /etc/cron.weekly/* && \
    rm -f /etc/cron.monthly/* && \
    rm -f /etc/logrotate.d/* && \
    rm -f /etc/supervisord/conf.d/* && \
    rm -fr /var/log/* && \
    rm -fr /var/www && \
    mkdir /var/log/apache2

# set locale
RUN locale-gen en_US.UTF-8

# install observium package
RUN mkdir -p /opt/observium /opt/observium/logs /opt/observium/rrd && \
    cd /opt && \
    wget http://www.observium.org/observium-community-latest.tar.gz && \
    tar zxvf observium-community-latest.tar.gz && \
    rm -f observium-community-latest.tar.gz

# configure observium package
RUN cd /opt/observium && \
    cp config.php.default config.php && \
    sed -i -e "s/= 'localhost';/= getenv('OBSERVIUM_DB_HOST');/g" config.php && \
    sed -i -e "s/= 'USERNAME';/= getenv('OBSERVIUM_DB_USER');/g" config.php && \
    sed -i -e "s/= 'PASSWORD';/= getenv('OBSERVIUM_DB_PASS');/g" config.php && \
    sed -i -e "s/= 'observium';/= getenv('OBSERVIUM_DB_NAME');/g" config.php && \
    echo "\$config['base_url'] = getenv('OBSERVIUM_BASE_URL');" >> config.php

COPY observium-init.sh /opt/observium/observium-init.sh

RUN chmod a+x /opt/observium/observium-init.sh && \
    chown -R www-data:www-data /opt/observium

# check version and installed files
RUN [ -f /opt/observium/VERSION ] && cat /opt/observium/VERSION && \
    find /opt -ls

# configure php modules
RUN phpenmod mcrypt

# configure apache configuration and modules
COPY observium-apache24 /etc/apache2/sites-available/000-default.conf
RUN a2dismod mpm_event && \
    a2enmod mpm_prefork && \
    a2enmod php7.0 && \
    a2enmod rewrite && \
    chmod 644 /etc/apache2/sites-available/000-default.conf && \
    sed -i -e "s/\${APACHE_LOG_DIR}\//\/opt\/observium\/logs\/apache2-/g" /etc/apache2/apache2.conf

# configure cron and logrotate
COPY logrotate-conf /etc/logrotate.conf
COPY logrotate-cron /etc/cron.d/logrotate
COPY observium-cron /etc/cron.d/observium
RUN chmod 644 /etc/logrotate.conf /etc/cron.d/logrotate /etc/cron.d/observium

# configure working directory
WORKDIR /opt/observium

# configure entry point
COPY supervisord.conf /etc/supervisord.conf
ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]

# expose tcp port
EXPOSE 80/tcp

# set volumes
VOLUME ["/opt/observium/logs","/opt/observium/rrd"]


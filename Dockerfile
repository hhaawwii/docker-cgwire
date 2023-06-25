FROM ubuntu:22.04

RUN sudo apt-get install postgresql postgresql-client postgresql-server-dev-all
RUN sudo apt-get install redis-server
RUN sudo apt-get install python3 python3-pip
RUN sudo apt-get install git
RUN sudo apt-get install nginx
RUN sudo apt-get install ffmpeg

RUN git clone https://github.com/cgwire/zou.git /opt/zou && \
    git clone -b build https://github.com/cgwire/kitsu.git /opt/kitsu && \
    cd /opt/zou && \
    python3 setup.py install && \
    pip3 install \
        gunicorn \
        gevent

COPY gunicorn /etc/zou/gunicorn.conf
COPY nginx /etc/nginx/sites-available/zou

RUN useradd --home /opt/zou zou && \
    mkdir /opt/zou/logs && \
    chown zou: /opt/zou/logs && \
    chown -R zou:www-data /opt/kitsu && \
    chown -R zou:www-data /opt/zou && \
    rm /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/zou /etc/nginx/sites-enabled

USER postgres

RUN service postgresql start && \
    psql --command "create database zoudb;" -U postgres && \
    psql --command "ALTER USER postgres WITH PASSWORD 'mysecretpassword';"

USER root
WORKDIR /opt/zou

# About Gunicorn and port 5000
# Gunicorn is being reverse-proxied through Nginx,
# which is ultimately the process serving port 80
ENTRYPOINT \
    service nginx start && \
    service postgresql start && \
    echo Initialising Zou.. && \
    sleep 5 && \
    zou init_db && \
    zou init_data && \
    zou create_admin && \
    echo Running Zou.. && \
    gunicorn \
        -c /etc/zou/gunicorn.conf \
        -b 0.0.0.0:5000 \
        wsgi:application 

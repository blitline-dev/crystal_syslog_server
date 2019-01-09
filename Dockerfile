FROM crystallang/crystal:0.27.0

ENV c="2"
RUN apt-get update
RUN apt-get install -y nano

RUN mkdir '/var/log/commonlogs'
RUN chmod 771 -R /var/log/commonlogs

RUN apt-get update
RUN apt-get install -y wget socat nano tcpdump

ENV CL_VERSION="1.01.13"

RUN git clone https://github.com/blitline-dev/crystal_syslog_server.git
RUN cd crystal_syslog_server/src && crystal build --release main.cr -o server

WORKDIR crystal_syslog_server/src

# sudo docker run -d -p 6768:6768 -v /var/log/commonlogs:/var/log/commonlogs commonlogs/commonlogs_crystal:latest crystal main.cr


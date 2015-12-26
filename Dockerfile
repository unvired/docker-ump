FROM ubuntu:14.04
MAINTAINER Unvired <support@unvired.io>

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    	ca-certificates \
    	curl \
    	wget \
      zip \
      unzip \
      supervisor \
      redis-server \
    	openjdk-7-jre-headless \
    	&& rm -rf /opt/lib/apt/lists/*

LABEL vendor="Unvired Inc." \
      com.unvired.ump.module="PLATFORM" \
      com.unvired.ump.release="R-3.002.0050" \
      com.unvired.ump.release-date="25-Dec-2015"

# Directories for work and passing input at runtime
RUN mkdir -p /opt/unvired/temp \
	&& mkdir -p /var/UMPinput 

# Extract JBoss
RUN wget -q -O/opt/unvired/temp/UMP3_Docker.zip https://owncloud.unvired.com/index.php/s/p7qECutefEvRu9S/download

RUN unzip -qq /opt/unvired/temp/UMP3_Docker.zip -d /opt/unvired/UMP3 \
    && rm -f /opt/unvired/temp/UMP3_Docker.zip \
    && rm -f /opt/unvired/UMP3/bin/standalone.sh \
    && rm -f /opt/unvired/UMP3/bin/standalone.conf

# Get the runtime deployment / dependencies for UMP
RUN wget -q -O/opt/unvired/UMP3/standalone/deployments/UMP.ear https://owncloud.unvired.com/index.php/s/yZOZqZfniz5C241/download
RUN wget -q -O/opt/unvired/UMP3/modules/unvired/middleware/main/UMP_Core.jar https://owncloud.unvired.com/index.php/s/77VT7gsHyItbzN1/download
RUN wget -q -O/opt/unvired/UMP3/modules/unvired/middleware/main/UMP_Logger.jar https://owncloud.unvired.com/index.php/s/zH9gMQuMiteVofK/download
RUN wget -q -O/opt/unvired/UMP3/modules/unvired/middleware/main/UMP_odata_sdk.jar https://owncloud.unvired.com/index.php/s/wC5OCwphGtYim16/download
RUN wget -q -O/opt/unvired/UMP3/modules/unvired/middleware/main/UMP_sapjco_sdk.jar https://owncloud.unvired.com/index.php/s/nfePzZf9z26fcZY/download
RUN wget -q -O/opt/unvired/UMP3/modules/unvired/middleware/main/UMP_jdbc_sdk.jar https://owncloud.unvired.com/index.php/s/ht3HfsYyo603mSX/download

# Standard config
COPY config/hazelcast.xml /opt/unvired/UMP3/standalone/configuration/hazelcast.xml
COPY config/standalone-full.xml /opt/unvired/UMP3/standalone/configuration/standalone-full.xml
COPY config/standalone.conf /opt/unvired/UMP3/bin/standalone.conf
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/standalone.sh /opt/unvired/UMP3/bin/standalone.sh
COPY config/sentinel.sh /opt/unvired/UMP3/bin/sentinel.sh

RUN chmod +x /opt/unvired/UMP3/bin/standalone.sh \
  && chmod +x /opt/unvired/UMP3/bin/sentinel.sh \
  && rm /etc/redis/redis.conf \
  && rm /etc/redis/sentinel.conf

ENV JBOSS_HOME=/opt/unvired/UMP3
ENV DOCKER_UMP_VERSION=R-3.002.0050

# Main port and Management console, redis sentinel
EXPOSE 8080 9990 26379

# Any files like SAP JCO binaries can be passed in via this volume, the startup script will copy from here to start
VOLUME /var/UMPinput

# The data volume for persistence of data in case of data-center mode, this folder can be used in UMP post isntallation configuration
VOLUME /var/UMPdata

ENTRYPOINT ["supervisord"]

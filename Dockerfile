# set base Docker image to Alpine
FROM alpine:3.19.1

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# install dependencies
RUN apk add --no-cache tzdata musl-locales musl-locales-lang bash libxml2-utils netcat-openbsd \
    && rm -rf /var/cache/apk/*

ENV JAVA_VERSION=jdk-17.0.11+9

# install Temurin OpenJDK 17
RUN set -eux; \
    ARCH="$(apk --print-arch)"; \
    case "${ARCH}" in \
       amd64|x86_64) \
         ESUM='839326b5b4b3e4ac2edc3b685c8ab550f9b6d267eddf966323c801cb21e3e018'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.11%2B9/OpenJDK17U-jdk_x64_alpine-linux_hotspot_17.0.11_9.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
	  wget -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
	  echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
	  mkdir -p /opt/java/openjdk; \
	  tar --extract \
	      --file /tmp/openjdk.tar.gz \
	      --directory /opt/java/openjdk \
	      --strip-components 1 \
	      --no-same-owner \
	  ; \
    rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"

LABEL maintainer="Markus Kruger <markusdkruger@gmail.com>" 

# set Docker image build arguments
# build arguments for user/group configurations
ARG USER=activemq
ARG USER_ID=10001
ARG USER_GROUP=apache
ARG USER_GROUP_ID=10001
ARG USER_HOME=/home/${USER}

# build arguments for Apache ActiveMQ product installation
ARG AMQ_SERVER_NAME=activemq
ARG AMQ_SERVER_VERSION=5.18.6
ARG AMQ_SERVER=apache-${AMQ_SERVER_NAME}-${AMQ_SERVER_VERSION}
ARG AMQ_SERVER_HOME=${USER_HOME}/${AMQ_SERVER}
ARG AMQ_SERVER_DIST_URL=https://www.apache.org/dyn/closer.cgi?filename=/activemq/5.18.6/apache-activemq-5.18.6-bin.tar.gz&action=download
# build argument for MOTD
ARG MOTD='printf "\n\
 Apache ActiveMQ \n\
 --------------------------------- \n\
 This Docker container comprises of a Apache ActiveMQ and is custom image for testing \n"'
ENV ENV=${USER_HOME}"/.ashrc"

# create the non-root user and group and set MOTD login message
RUN \
    addgroup -S -g ${USER_GROUP_ID} ${USER_GROUP} \
    && adduser -S -u ${USER_ID} -h ${USER_HOME} -G ${USER_GROUP} ${USER} \
    && echo ${MOTD} > "${ENV}"

# add the activemq product distribution to user's home directory
RUN \
    wget -O ${AMQ_SERVER}.tar.gz "${AMQ_SERVER_DIST_URL}" \
    && mkdir ${AMQ_SERVER_HOME} \
    && tar -xf ${AMQ_SERVER}.tar.gz -C ${USER_HOME} \
    && chown activemq:apache -R ${AMQ_SERVER_HOME} \
    && rm -f ${AMQ_SERVER}.zip

# copy any config file
#COPY --chown=activemq:apache docker-entrypoint.sh ${USER_HOME}/
COPY --chown=activemq:apache jetty.xml ${AMQ_SERVER_HOME}/conf
COPY --chown=activemq:apache jolokia-access.xml ${AMQ_SERVER_HOME}/conf

# remove unnecesary packages
RUN apk del netcat-openbsd \
    && rm -rf /var/cache/apk/*

# set the user and work directory
USER ${USER_ID}
WORKDIR ${USER_HOME}

# set environment variables
ENV WORKING_DIRECTORY=${USER_HOME} \
    AMQ_SERVER_HOME=${AMQ_SERVER_HOME}

# expose ports
EXPOSE 61616 5672 61613 1883 61614 8161

# initiate container and start Apache ActiveMQ
CMD ["/bin/sh", "-c", "/home/activemq/apache-activemq-5.18.6/bin/activemq console"]
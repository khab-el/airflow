FROM python:3.8-slim-buster

# Never prompt the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.11
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

# Disable noisy "Handling signal" log messages:
# ENV GUNICORN_CMD_ARGS --log-level WARNING

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[crypto,celery,rabbitmq,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis==3.2' \
    && pip install ldap3 \
    && apt install -y libpq-dev \
    && apt install -y git \
    && apt -y install g++ curl telnet unixodbc-dev odbc-postgresql \
    && pip --no-cache install pyodbc \
    && pip install tqdm beautifulsoup4 pandas numpy sqlalchemy\
    && pip install psycopg2-binary \
    && pip install psycopg2 \
    && pip install pyamqp \
    && pip install docker \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base
RUN apt-get update -y && \
    apt-get install -y git
######################################################
###############################kerberos and odbc drive

RUN apt-get update -y
RUN apt-get -y install \
        python3-pip \
        unixodbc-dev \
        libpq-dev python-dev \
        odbc-postgresql

ADD clouderahiveodbc_2.6.9.1009-2_amd64.deb /tmp/clouderahiveodbc_2.6.9.1009-2_amd64.deb
ADD clouderaimpalaodbc_2.6.11.1011-2_amd64.deb /tmp/clouderaimpalaodbc_2.6.11.1011-2_amd64.deb

RUN apt install -y /tmp/clouderahiveodbc_2.6.9.1009-2_amd64.deb && \
    apt install -y /tmp/clouderaimpalaodbc_2.6.11.1011-2_amd64.deb

RUN apt-get update -y && apt install -y default-jre

RUN apt-get install -y krb5-user

RUN pip3 install \
         impala \
         pyodbc \
         psycopg2 \
         PyMySQL \
         sqlalchemy \
         jaydebeapi

COPY jars.tar /tmp/jars.tar

RUN  tar -C /tmp/ -xvf /tmp/jars.tar

ADD ./odbcinst.ini /etc/odbcinst.ini

########################################################

COPY ./entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg
COPY config/ldap_auth.py /usr/local/lib/python3.8/site-packages/airflow/contrib/auth/backends/ldap_auth.py
COPY config/packages.pth /usr/local/lib/python3.8/site-packages

RUN chown -R airflow: ${AIRFLOW_USER_HOME}

EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"]

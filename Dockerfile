FROM codecakes/buster_py:latest

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Create the file repository configuration:
RUN (addgroup --system postgres && adduser --system postgres && usermod -a -G postgres postgres)
RUN mkdir -p /var/lib/postgresql/data
RUN mkdir -p /run/postgresql/
RUN chown -R postgres:postgres /run/postgresql/
RUN chmod -R 777 /var/lib/postgresql/data
RUN chown -R postgres:postgres /var/lib/postgresql/data
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8
RUN apt-get update -y

RUN apt-get install -y --no-install-recommends lsb-release ca-certificates curl software-properties-common wget

# Import the repository signing key:
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update -y
RUN apt-get install -y libpq-dev postgresql postgresql-client postgresql-contrib

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
ENV PATH /usr/bin:$PATH

# Add bazel using bazelisk
RUN curl -Lo /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/download/v1.7.4/bazelisk-linux-amd64
RUN chmod +x /usr/local/bin/bazel
RUN export PATH=$PATH:/usr/local/bin/
RUN alias bazel=/usr/local/bin/bazel
RUN bazel version

COPY requirements.txt requirements.txt
COPY requirements_dev.txt requirements_dev.txt

# Prepare for pyenv
RUN apt-get install -y make build-essential libssl-dev zlib1g-dev \
 libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev\
 libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl\
 git
RUN curl https://pyenv.run | bash
RUN export PATH="/root/.pyenv/bin:$PATH"
RUN eval "$(pyenv init -)"
RUN eval "$(pyenv virtualenv-init -)"
RUN echo "export PATH="/root/.pyenv/bin:$PATH"" >> ~/.bashrc
RUN echo "eval "$(pyenv init -)"" >> ~/.bashrc
RUN echo "eval "$(pyenv virtualenv-init -)"" >> ~/.bashrc

# Setup celery project dir
ARG PROJECT=app
ARG PROJECT_DIR=/${PROJECT}
RUN mkdir -p $PROJECT_DIR

# WORKDIR /app
WORKDIR $PROJECT_DIR
COPY . $PROJECT_DIR

RUN if [ -d "static" ]; then chmod -R a+rx static/ && chown -R `whoami` static/ && rm -rf static; fi;
RUN touch $PROJECT_DIR/logs.log && chmod 0777 $PROJECT_DIR/logs.log && chown `whoami` $PROJECT_DIR/logs.log

ENV MAIN_USER=$(whoami)
# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER postgres
RUN echo "host all  all    0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf
# Expose the PostgreSQL port
EXPOSE 5432
RUN echo "listen_addresses='*'" >> /etc/postgresql/13/main/postgresql.conf
RUN /etc/init.d/postgresql start;
ENTRYPOINT /usr/lib/postgresql/13/bin/postgres -D /var/lib/postgresql/13/main -c config_file=/etc/postgresql/13/main/postgresql.conf
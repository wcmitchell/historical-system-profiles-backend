ARG deps="git-core python39-pip tzdata libpq"
ARG buildDeps="python39-devel gcc libpq-devel"
ARG poetryVersion="1.6.0"

ARG TEST_IMAGE=false

#######################

FROM registry.access.redhat.com/ubi8/ubi-minimal AS base

ARG deps
ARG poetryVersion

ENV LC_ALL=C.utf8
ENV LANG=C.utf8

RUN microdnf update -y && \
    microdnf module enable python39 && \
    microdnf install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs -y $deps && \
    microdnf clean all
RUN pip3 install --force-reinstall poetry~="${poetryVersion}"

#######################

FROM base AS build

ARG buildDeps
ARG poetryVersion

ENV LC_ALL=C.utf8
ENV LANG=C.utf8

ENV APP_ROOT=/opt/app-root

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CONFIG_DIR=/opt/app-root/.pypoetry/config \
    POETRY_DATA_DIR=/opt/app-root/.pypoetry/data \
    POETRY_CACHE_DIR=/opt/app-root/.pypoetry/cache
ENV UNLEASH_CACHE_DIR=/tmp/unleash_cache

RUN microdnf install --setopt=tsflags=nodocs -y $buildDeps

USER 1001

WORKDIR ${APP_ROOT}/src

# needed for poetry to work properly
ENV HOME=${APP_ROOT}

COPY --chown=1001:0 pyproject.toml poetry.lock ${APP_ROOT}/src

RUN poetry install --sync --no-root && rm -rf "$POETRY_CACHE_DIR"

#######################

FROM base AS final

ARG TEST_IMAGE

ENV LC_ALL=C.utf8
ENV LANG=C.utf8

ENV APP_ROOT=/opt/app-root

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CONFIG_DIR=/opt/app-root/.pypoetry/config \
    POETRY_DATA_DIR=/opt/app-root/.pypoetry/data \
    POETRY_CACHE_DIR=/opt/app-root/.pypoetry/cache

ENV UNLEASH_CACHE_DIR=/tmp/unleash_cache

ENV VIRTUAL_ENV_DIR=${APP_ROOT}/src/.venv

USER 1001

WORKDIR ${APP_ROOT}/src

COPY --chown=1001:0 . ${APP_ROOT}/src

COPY --from=build --chown=1001:0 $VIRTUAL_ENV_DIR $VIRTUAL_ENV_DIR

# allows unit tests to run successfully within the container if image is built in "test" environment
RUN if [ "$TEST_IMAGE" = "true" ]; then chgrp -R 0 $APP_ROOT && chmod -R g=u $APP_ROOT; fi

CMD poetry run ./run_app.sh

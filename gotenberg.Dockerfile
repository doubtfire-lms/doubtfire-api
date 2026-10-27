FROM gotenberg/gotenberg:8-libreoffice

USER root

RUN apt-get update \
    && apt-get install --yes --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY lib/shell/word_document_build.sh /gotenberg/word_document_build.sh
RUN chmod 755 /gotenberg/word_document_build.sh

USER gotenberg

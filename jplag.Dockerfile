FROM alpine:3.22.1

ENV JPLAG_VERSION=6.2.0
WORKDIR /jplag

RUN apk update && \
  apk add --no-cache bash openjdk21 wget && \
  wget -O jplag-jar-with-dependencies.jar \
  https://github.com/jplag/JPlag/releases/download/v$JPLAG_VERSION/jplag-$JPLAG_VERSION-jar-with-dependencies.jar

CMD ["sh", "-c", "sleep infinity"]

FROM eclipse-temurin:25-jre-alpine

ENV JPLAG_VERSION=6.3.0
WORKDIR /jplag

RUN apk update && \
  apk add --no-cache bash wget && \
  wget -O jplag-jar-with-dependencies.jar \
  https://github.com/jplag/JPlag/releases/download/v$JPLAG_VERSION/jplag-$JPLAG_VERSION-jar-with-dependencies.jar

CMD ["sh", "-c", "sleep infinity"]

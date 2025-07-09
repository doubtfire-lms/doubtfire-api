FROM alpine:3.21

ENV JPLAG_VERSION=6.1.0

RUN apk update
RUN apk add --no-cache bash openjdk21

RUN mkdir /jplag
RUN chmod 777 /jplag

WORKDIR /jplag

RUN wget https://github.com/jplag/JPlag/releases/download/v$JPLAG_VERSION/jplag-$JPLAG_VERSION-jar-with-dependencies.jar
RUN mv jplag-$JPLAG_VERSION-jar-with-dependencies.jar jplag-jar-with-dependencies.jar

CMD ["sh", "-c", "sleep infinity"]

FROM python:3-buster

VOLUME IPYNB_NBCPNVERT_VOLUME
WORKDIR /app

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get -y install pandoc
RUN apt-get -y install texlive-xetex texlive-fonts-recommended texlive-plain-generic

RUN pip install nbconvert


CMD bundle exec /bin/bash
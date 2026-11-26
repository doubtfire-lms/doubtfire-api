FROM python:3.12-alpine

RUN pip install --no-cache-dir --no-compile nbconvert==7.17.2 ipython==9.19.1

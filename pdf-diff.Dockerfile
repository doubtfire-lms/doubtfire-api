FROM golang:1.23-alpine AS builder

WORKDIR /tmp
RUN apk add --no-cache \
  wget \
  ca-certificates \
  tar
RUN wget -q https://github.com/serhack/pdf-diff/releases/download/v0.0.1/pdf-diff_0.0.1_Linux_x86_64.tar.gz
RUN tar -xzf pdf-diff_0.0.1_Linux_x86_64.tar.gz

FROM golang:1.23-alpine

RUN apk add --no-cache \
  poppler-utils \
  python3 \
  py3-pip \
  diff-pdf

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir img2pdf

WORKDIR /app
COPY --from=builder /tmp/pdf-diff /usr/local/bin/pdf-diff

CMD ["./app"]

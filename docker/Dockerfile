FROM hashicorp/packer:1.12

USER root

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qqy curl \
 && rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/itamae-kitchen/mitamae/releases/download/v1.14.2/mitamae-armhf-linux.tar.gz \
  | tar xvz

RUN mv mitamae-armhf-linux mitamae
WORKDIR /build

# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
# Set the base image as a build argument with a default value.
ARG BASE_IMAGE=gcr.io/distroless/base-debian13:latest@sha256:389cad21f73e4c37b94ffe5b13736d5a92bd5bd3c6c6b38c2be1c881e14ba2bd

################################################################################
# Create a stage for verifying the base image signature.
# This stage uses cosign to verify the signature of the specified base image.
# If the verification fails, the build will stop here.
# If it succeeds, a marker file is created to indicate success.
# This marker file is then copied to the final stage to enforce the execution
# of this stage.
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS image-verifier
ARG BASE_IMAGE
RUN apk add -u --no-cache cosign=~3.0 \
  && cosign verify $BASE_IMAGE \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  --certificate-oidc-issuer https://accounts.google.com \
  && touch /marker

################################################################################
# Create a stage for building/compiling the application.
FROM --platform=$BUILDPLATFORM gcc:16.2.0-trixie@sha256:ee908558f90e6802031aafec0859be575a8d4151099b33e53aa70795b1ab185b AS build

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# install unzip utility and cross-compilation tools for ARM64
RUN apt-get update && apt-get satisfy -y --no-install-recommends \
  "unzip (>> 6.0)" \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install cross-compilation tools if building for  architecture
RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ]; then \
  apt-get update && apt-get satisfy -y --no-install-recommends \
  "gcc-aarch64-linux-gnu (>>4:14.2)" \
  "g++-aarch64-linux-gnu (>>4:14.2)" \
  && apt-get clean different \
  && rm -rf /var/lib/apt/lists/*; \
  fi

# copy fonts and entrypoint script from context
# set permissions to non-root user
# checkov:skip=CKV_DOCKER_4 reason="Using a fixed, verified URL for downloading fonts"
ADD \
  --chown=1000:1000 \
  --checksum=sha256:8ca33a60c791392d872b80d26c42f2bfa914a480f9eb2d7516d9f84373c36897 \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip /fonts/
COPY --chown=1000:1000 app /app
# switch to non-root user
USER 1000:1000
# unzip fonts
WORKDIR /fonts
RUN unzip ./*.zip && rm ./*.zip
# build the C++ copy_fonts application
WORKDIR /app
RUN case "$TARGETPLATFORM" in \
  linux/arm64) \
    aarch64-linux-gnu-g++ -static-libstdc++ -static-libgcc -std=c++20 -g -O2 -o copy_fonts copy_fonts.cpp;; \
  linux/amd64|*) \
    g++ -static-libstdc++ -static-libgcc -std=c++20 -g -O2 -o copy_fonts copy_fonts.cpp;; \
  esac

################################################################################
# Create a final stage for running the application.
# This stage copies the compiled binary from the "build" stage.
# It uses a minimal base image to reduce image size and attack surface.
# checkov:skip=CKV_DOCKER_7 reason="Base image is defined and verified with cosign in a previous stage"
FROM ${BASE_IMAGE} AS final

LABEL org.opencontainers.image.authors="micgro2@gmail.com" \
  org.opencontainers.image.url='https://github.com/michael-grosshaeuser/rac_font_init' \
  org.opencontainers.image.documentation='https://github.com/michael-grosshaeuser/rac_font_init/blob/main/README.md' \
  org.opencontainers.image.source='https://github.com/michael-grosshaeuser/rac_font_init/blob/main/Dockerfile' \
  org.opencontainers.image.vendor='Michael Grosshaeuser' \
  org.opencontainers.image.licenses='MIT Licenses' \
  org.opencontainers.image.description="copy Nerd Fonts to a volume"

# copy the marker file from the image-verifier stage to enforce its execution
# if the image-verifier stage fails, this copy will not happen and the build will fail
COPY --from=image-verifier /marker /ignore-me

# Copy the executable from the "build" stage.
COPY --from=build /app/copy_fonts /usr/local/bin/copy_fonts
COPY --from=build /fonts /fonts

# Ensure the container exec commands handle range of utf8 characters
ENV LANG=C.UTF-8

# Add VOLUMEs where the fonts will be copied to
VOLUME  ["/font_volume"]

# Kubernetes init containers are expected to run once and exit successfully after
# performing their setup task. Docker healthchecks are not meaningful here and
# would only report a transient status for a short-lived container.
HEALTHCHECK NONE

# What the container should run when it is started.
ENTRYPOINT ["copy_fonts"]

# syntax=docker/dockerfile:1@sha256:dabfc0969b935b2080555ace70ee69a5261af8a8f1b4df97b9e7fbcf6722eddf
# Set the base image as a build argument with a default value.
ARG BASE_IMAGE=gcr.io/distroless/base-debian12:latest@sha256:9e9b50d2048db3741f86a48d939b4e4cc775f5889b3496439343301ff54cdba8

################################################################################
# Create a stage for verifying the base image signature.
# This stage uses cosign to verify the signature of the specified base image.
# If the verification fails, the build will stop here.
# If it succeeds, a marker file is created to indicate success.
# This marker file is then copied to the final stage to enforce the execution
# of this stage.
FROM alpine:3.22@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1 AS image-verifier
ARG BASE_IMAGE
RUN apk add -u --no-cache cosign=~2.4 \
    && cosign verify $BASE_IMAGE \
    --certificate-identity keyless@distroless.iam.gserviceaccount.com \
    --certificate-oidc-issuer https://accounts.google.com \
    && touch /marker

################################################################################
# Create a stage for building/compiling the application.
FROM gcc:15.2-bookworm@sha256:9ca91b05c7b07d2979f16413e8b2cd6ec8a7c80ffca4121ccab0aeba33f90460 AS build

# install unzip utility
RUN apt-get update && apt-get satisfy -y --no-install-recommends \
    "unzip (>> 6.0)" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# copy fonts and entrypoint script from context
# checkov:skip=CKV_DOCKER_4 reason="Using a fixed, verified URL for downloading fonts"
ADD https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip /fonts/
COPY app /app
# set permissions to non-root user
RUN chown -R 1000:1000 /app /fonts
USER 1000:1000
# unzip fonts
WORKDIR /fonts
RUN unzip ./*.zip && rm ./*.zip
# build the C++ copy_fonts application
WORKDIR /app
RUN g++ -static-libstdc++ -static-libgcc -std=c++17 -g -O2 -o copy_fonts copy_fonts.cpp

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
      org.opencontainers.image.licenses='GNU GENERAL PUBLIC LICENSE Version 3' \
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

# HEALTHCHECK: check if the copy_fonts binary exists and is executable
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD [ -x /usr/local/bin/copy_fonts ] || exit 1

# What the container should run when it is started.
ENTRYPOINT ["copy_fonts"]

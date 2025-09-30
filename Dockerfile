# syntax=docker/dockerfile:1

# Set the base image as a build argument with a default value.
ARG BASE_IMAGE=gcr.io/distroless/base-debian12:latest

################################################################################
# Create a stage for verifying the base image signature.
# This stage uses cosign to verify the signature of the specified base image.
# If the verification fails, the build will stop here.
# If it succeeds, a marker file is created to indicate success.
# This marker file is then copied to the final stage to enforce the execution
# of this stage.
FROM alpine:3.22 AS image-verifier
ARG BASE_IMAGE
RUN apk add -u --no-cache cosign \
    && cosign verify $BASE_IMAGE \
    --certificate-identity keyless@distroless.iam.gserviceaccount.com \
    --certificate-oidc-issuer https://accounts.google.com \
    && touch /marker

################################################################################
# Create a stage for building/compiling the application.
FROM gcc:15.2-bookworm AS build

# install unzip utility
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# copy fonts and entrypoint script from context
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
RUN g++ -static-libstdc++ -static-libgcc -std=c++17 -o copy_fonts copy_fonts.cpp

################################################################################
# Create a final stage for running the application.
# This stage copies the compiled binary from the "build" stage.
# It uses a minimal base image to reduce image size and attack surface.
FROM ${BASE_IMAGE} AS final

LABEL org.opencontainers.image.authors="micgro2@gmail.com" \
      org.opencontainers.image.url='https://github.com/michael-grosshaeuser/rac_font_init' \
      org.opencontainers.image.documentation='https://github.com/michael-grosshaeuser/rac_font_init/blob/main/README.md' \
      org.opencontainers.image.source='https://github.com/michael-grosshaeuser/rac_font_init/blob/main/Dockerfile' \
      org.opencontainers.image.vendor='Michael Grosshaeuser' \
      org.opencontainers.image.licenses='GNU GENERAL PUBLIC LICENSE Version 3' \
      org.opencontainers.image.description="copy Nerd Fonts to a volume"

# Copy the executable from the "build" stage.
COPY --from=build /app/copy_fonts /usr/local/bin/copy_fonts
COPY --from=build /fonts /fonts

# Das folgende COPY erzwingt die Ausführung/Bau der image-verifier Stage
COPY --from=image-verifier /marker /ignore-me

# Ensure the container exec commands handle range of utf8 characters
ENV LANG=C.UTF-8

# Add VOLUMEs where the fonts will be copied to
VOLUME  ["/font_volume"]

# What the container should run when it is started.
ENTRYPOINT ["copy_fonts"]

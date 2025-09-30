# Init container for authentik remote access control outpost

This project provides a secure, containerized tool to copy [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) (e.g., Hack) into a Docker volume.  
The container verifies the signature of the used base image with [cosign](https://github.com/sigstore/cosign) before starting, compiles a small C++ application for copying the fonts, and uses a minimal, secure runtime image.

The container could be used as init container for the authentik remote access control outpost to copy the fonts to a volume which is used by the rac container.

## Features

- **Secure build:** Verification of the base image with cosign.
- **Multi-stage build:** Compiles the application in a dedicated stage.
- **Minimal runtime image:** Uses distroless for maximum security.
- **Automatic extraction:** Downloads and extracts Nerd Fonts automatically.
- **Copies fonts:** Copies `.ttf` files into the specified volume.

## Usage

```bash
docker run --rm -v <target-directory>:/font_volume ghcr.io/michael-grosshaeuser/rac_font_init:latest
```

The fonts will then be available in the specified target directory.

### Notes

- The image runs as a non-privileged user by default.
- The Nerd Fonts used are downloaded from the official repository during build.
- The project is licensed under the GNU GPLv3.

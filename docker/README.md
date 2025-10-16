## Overview

The contents of this folder are used to create a Docker image that extends the
Nextstrain base image with tools necessary for running tuberculosis analyses.

## Usage

The automated build process happens in the
[docker.yml](../.github/workflows/docker.yml) GitHub Actions workflow. The
scripts can also be used locally. Loading and tagging the image is optional but
recommended for ease of use and removal.

    cd docker
    ./build --load --tag nextstrain-tb

The conda environments may not resolve on the `linux/arm64` platform (used by
default on Apple silicon computers). A workaround is to emulate for
`linux/amd64` (used by default in the GitHub Actions workflow), noting that emulation means slower build and run times.

    ./build --load --tag nextstrain-tb --platform linux/amd64

The image size is expected to be ~9 GB uncompressed. The builder volume size is expected to be ~4.5 GB.

The image extends the Nextstrain base image, so it is compatible with Nextstrain CLI.

    nextstrain shell --image nextstrain-tb .

To reclaim disk space, remove the builder and the tagged image.

    ./clean
    docker image rm nextstrain-tb

## References

Adapted from
[victorlin/github-actions-docker-build](https://github.com/victorlin/github-actions-docker-build),
which is based on work in
[nextstrain/docker-base](https://github.com/nextstrain/docker-base).

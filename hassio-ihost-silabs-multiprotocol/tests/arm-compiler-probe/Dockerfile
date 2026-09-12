ARG BUILDER_IMAGE
FROM --platform=linux/amd64 ${BUILDER_IMAGE}
ARG SDK_REVISION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git python3 cmake crossbuild-essential-armhf
WORKDIR /probe
RUN git clone --depth 1 --filter=blob:none --sparse --branch v2024.12.1-0 https://github.com/SiliconLabs/simplicity_sdk.git sdk \
    && test "$(git -C sdk rev-parse HEAD)" = "$SDK_REVISION" \
    && git -C sdk sparse-checkout set util/third_party/openthread/third_party/mbedtls util/third_party/ot-br-posix/third_party/openthread
COPY original-command.txt compare.py ./
RUN python3 compare.py

# FROM alpine:latest

# RUN curl -fsSL https://freenet.org/install.sh | sh

# EXPOSE 7509

# CMD ["freenet"]

FROM alpine:latest AS builder

RUN apk add --no-cache \
    build-base \
    musl-dev \
    pkgconfig \
    openssl-dev \
    git \
    curl

# Install Rust via rustup
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain stable

WORKDIR /build
RUN git clone --depth 1 https://github.com/freenet/freenet-core.git .

# Installs the `freenet` node binary to $CARGO_HOME/bin/freenet
RUN cargo install --path crates/core --locked

# Runtime
FROM alpine:latest

RUN apk add --no-cache ca-certificates libgcc

RUN addgroup -S freenet && adduser -S -G freenet freenet

COPY --from=builder /usr/local/cargo/bin/freenet /usr/local/bin/freenet

# TODO: confirm default data/config paths once the node runs once
# adjust this volume target to match so the datastore survives container recreation.
RUN mkdir -p /home/freenet/.config/freenet /home/freenet/.local/share/freenet \
    && chown -R freenet:freenet /home/freenet

USER freenet
WORKDIR /home/freenet
VOLUME ["/home/freenet/.local/share/freenet"]

EXPOSE 7509

ENTRYPOINT ["freenet"]
CMD ["--ws-api-address", "0.0.0.0", "--ws-api-port", "7509"]
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

RUN cargo install --path crates/core --locked

# Runtime stage
FROM alpine:latest

RUN apk add --no-cache ca-certificates bash

RUN addgroup -S freenet && adduser -S -G freenet -s /bin/bash freenet

COPY --from=builder /usr/local/cargo/bin/freenet /usr/local/bin/freenet
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# volume targets the datastore so survives container recreation
RUN mkdir -p /home/freenet/.config/freenet /home/freenet/.local/share/freenet \
    && chown -R freenet:freenet /home/freenet

USER freenet
WORKDIR /home/freenet
VOLUME ["/home/freenet/.local/share/freenet"]

EXPOSE 7509

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--ws-api-address", "0.0.0.0", "--ws-api-port", "7509"]

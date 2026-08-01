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
RUN apk add --no-cache ca-certificates bash tini su-exec
RUN addgroup -S freenet && adduser -S -G freenet -s /bin/bash freenet

COPY --from=builder /usr/local/cargo/bin/freenet /home/freenet/bin/freenet
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /home/freenet/bin/freenet

ENV PATH="/home/freenet/bin:${PATH}"

ENV DATA_DIR=/home/freenet/.local/share/freenet \
    CONFIG_DIR=/home/freenet/.config/freenet \
    LOG_DIR=/home/freenet/.local/state/freenet

RUN mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR" \
    && chown -R freenet:freenet /home/freenet

WORKDIR /home/freenet
EXPOSE 7509
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]

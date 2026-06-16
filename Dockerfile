ARG SNOWFLAKE_VERSION=v2.14.0
ARG SNOWFLAKE_COMMIT=7c9cf134d58dd46a104ef418613d48c2935ac977

ARG WEBTUNNEL_VERSION=v0.0.4
ARG WEBTUNNEL_COMMIT=2622136451a8f277d73611d5ee7b8558e2d86bd1

ARG OBFS4_VERSION=obfs4proxy-0.0.14
ARG OBFS4_COMMIT=336a71d6e4cfd2d33e9c57797828007ad74975e9

# ==========================================
# Stage 1: Build Snowflake client
# ==========================================
FROM golang:1.26.4-alpine3.24 AS snowflake-builder
RUN apk add --no-cache git
WORKDIR /build
ARG SNOWFLAKE_VERSION
ARG SNOWFLAKE_COMMIT
RUN git clone --depth 1 --branch ${SNOWFLAKE_VERSION} \
    https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git \
    /build/snowflake && \
    test "$(git -C /build/snowflake rev-parse HEAD)" = "${SNOWFLAKE_COMMIT}"
WORKDIR /build/snowflake/client
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o /snowflake-client .

# ==========================================
# Stage 2: Build obfs4proxy
# ==========================================
FROM golang:1.26.4-alpine3.24 AS obfs4-builder
RUN apk add --no-cache git
WORKDIR /build
ARG OBFS4_VERSION
ARG OBFS4_COMMIT
RUN git clone --depth 1 --branch ${OBFS4_VERSION} \
    https://github.com/Yawning/obfs4.git \
    /build/obfs4 && \
    test "$(git -C /build/obfs4 rev-parse HEAD)" = "${OBFS4_COMMIT}"
WORKDIR /build/obfs4
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o /obfs4proxy ./obfs4proxy/

# ==========================================
# Stage 3: Build WebTunnel client
# ==========================================
FROM golang:1.26.4-alpine3.24 AS webtunnel-builder
RUN apk add --no-cache git
WORKDIR /build
ARG WEBTUNNEL_VERSION
ARG WEBTUNNEL_COMMIT
RUN git clone --depth 1 --branch ${WEBTUNNEL_VERSION} \
    https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git \
    /build/webtunnel && \
    test "$(git -C /build/webtunnel rev-parse HEAD)" = "${WEBTUNNEL_COMMIT}"
WORKDIR /build/webtunnel
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o /webtunnel-client ./main/client/

# ==========================================
# Stage 4: Final lightweight runtime image
# ==========================================
FROM alpine:3.24

LABEL org.opencontainers.image.title="tor-gateway"
LABEL org.opencontainers.image.source="https://github.com/AndrewSaff/tor-gateway"

RUN apk add --no-cache \
    tor \
    privoxy \
    su-exec \
    netcat-openbsd \
    ca-certificates && \
    mkdir -p /run/tor && \
    chown tor:tor /run/tor && \
    chmod 700 /run/tor

COPY --from=snowflake-builder /snowflake-client /usr/local/bin/snowflake-client
COPY --from=obfs4-builder /obfs4proxy /usr/local/bin/obfs4proxy
COPY --from=webtunnel-builder /webtunnel-client /usr/local/bin/webtunnel-client

RUN chmod +x /usr/local/bin/snowflake-client /usr/local/bin/obfs4proxy /usr/local/bin/webtunnel-client

COPY additions/start.sh /start.sh
COPY additions/etc/tor/torrc /etc/tor/torrc
COPY additions/etc/privoxy/config /etc/privoxy/config

RUN chmod +x /start.sh

EXPOSE 5353/tcp 5353/udp 9040/tcp 9050/tcp 8118/tcp

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD nc -z 127.0.0.1 9050 && nc -z 127.0.0.1 8118

ENTRYPOINT ["/start.sh"]
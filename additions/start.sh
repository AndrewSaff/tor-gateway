#!/bin/sh
set -e

echo "=== Starting Tor Gateway & Pluggable Transports ==="

mkdir -p /run/tor
chown tor:tor /run/tor
chmod 700 /run/tor

if [ ! -f /etc/tor/torrc ]; then
    echo "ERROR: /etc/tor/torrc not found!"
    exit 1
fi

if [ ! -f /etc/privoxy/config ]; then
    echo "ERROR: /etc/privoxy/config not found!"
    exit 1
fi

for bin in snowflake-client obfs4proxy webtunnel-client; do
    if [ ! -x /usr/local/bin/$bin ]; then
        echo "ERROR: $bin not found or not executable!"
        exit 1
    fi
done

get_ver() {
  bin="$1"
  flag="$2"
  out=$("/usr/local/bin/$bin" "$flag" 2>&1 | head -1 || true)
  [ -n "$out" ] || out="version unknown"
  printf "%s" "$out"
  return 0
}

echo "Snowflake:  $(get_ver snowflake-client -version)"
echo "obfs4proxy: $(get_ver obfs4proxy --version)"
echo "WebTunnel:  $(get_ver webtunnel-client -version)"

echo "Starting Privoxy in background..."
su-exec privoxy privoxy --no-daemon /etc/privoxy/config &

echo "Starting Tor daemon as PID 1..."
exec su-exec tor tor -f /etc/tor/torrc
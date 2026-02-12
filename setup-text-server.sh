#!/data/data/com.termux/files/usr/bin/sh
# setup.sh — installs and writes rts.sh (Run Text Server)

set -e

echo "[1/4] Installing packages"
pkg update -y
pkg install -y busybox termux-api

BASE="$HOME/sms-gateway"
WWW="$BASE/www/cgi-bin"

echo "[2/4] Creating directory structure"
mkdir -p "$WWW"

echo "[3/4] Writing CGI SMS handler"

cat > "$WWW/send.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
echo "Content-Type: text/plain"
echo

echo "[`date`] Request received" >&2

if [ -n "$QUERY_STRING" ]; then
    QUERY="$QUERY_STRING"
    echo "[`date`] Using QUERY_STRING: $QUERY" >&2
else
    read QUERY
    echo "[`date`] Using POST body: $QUERY" >&2
fi

urldecode() {
  printf '%b' "$(echo "$1" | sed 's/+/ /g;s/%/\\x/g')"
}

RAW_TO=$(printf '%s\n' "$QUERY" | tr '&' '\n' | sed -n 's/^to=//p')
RAW_MSG=$(printf '%s\n' "$QUERY" | tr '&' '\n' | sed -n 's/^msg=//p')

TO=$(urldecode "$RAW_TO")
MSG=$(urldecode "$RAW_MSG")

echo "[`date`] Parsed TO: $TO" >&2
echo "[`date`] Parsed MSG: $MSG" >&2

if [ -z "$TO" ] || [ -z "$MSG" ]; then
  echo "[`date`] ERR: missing to or msg" >&2
  echo "ERR: missing to or msg"
  exit 1
fi

echo "[`date`] Sending SMS..." >&2
termux-sms-send -n "$TO" "$MSG"
echo "[`date`] SMS sent to $TO" >&2

echo "OK"
EOF

chmod +x "$WWW/send.sh"

echo "[4/4] Writing rts.sh"

cat > "$HOME/rts.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# rts.sh — Run Text Server

BASE="\$HOME/sms-gateway"
IP=\$(getprop dhcp.wlan0.ipaddress)

echo "=== Run Text Server ==="

if [ -n "\$IP" ]; then
  echo "Phone LAN IP: \$IP"
  echo "Test URL:"
  echo "http://\$IP:8080/cgi-bin/send.sh?to=+614xxxxxxxx&msg=hello%20world"
else
  echo "Could not auto-detect LAN IP. Check Wi-Fi settings."
fi

echo
echo "Starting HTTP server on port 8080..."
echo "Press Ctrl+C to stop."
echo

busybox httpd -f -p 8080 -h "\$BASE/www"
EOF

chmod +x "$HOME/rts.sh"

echo
echo "Setup complete."
echo "Run the server with:"
echo "  ~/rts.sh"
echo
echo "First SMS send may trigger permission prompt."
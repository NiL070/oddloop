clear
echo Installing Websocket-SSH Python
sleep 1
echo Sila Tunggu Sebentar...
sleep 0.5
cd

# // GIT USER
GitUser="NiL070"
namafolder="websocket-python"

# ================================
# SYSTEMD WEBSOCKET HTTPS (443)
# ================================
cat <<EOF> /etc/systemd/system/ws-https.service
[Unit]
Description=Python Proxy
Documentation=https://github.com/NiL070/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-https

[Install]
WantedBy=multi-user.target
EOF

# ================================
# SYSTEMD WEBSOCKET HTTP (80)
# ================================
cat <<EOF> /etc/systemd/system/ws-http.service
[Unit]
Description=Python Proxy
Documentation=https://github.com/NiL070/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-http

[Install]
WantedBy=multi-user.target
EOF

# ================================
# SYSTEMD WEBSOCKET OVPN (2097)
# ================================
cat <<EOF> /etc/systemd/system/ws-ovpn.service
[Unit]
Description=Python Proxy
Documentation=https://github.com/NiL070/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-ovpn 2097

[Install]
WantedBy=multi-user.target
EOF

# ================================
# DOWNLOAD PYTHON FILES
# ================================
wget -q -O /usr/local/bin/ws-https https://raw.githubusercontent.com/${GitUser}/oddloop/main/${namafolder}/ws-https
chmod +x /usr/local/bin/ws-https

wget -q -O /usr/local/bin/ws-http https://raw.githubusercontent.com/${GitUser}/oddloop/main/${namafolder}/ws-http2
chmod +x /usr/local/bin/ws-http

wget -q -O /usr/local/bin/ws-ovpn https://raw.githubusercontent.com/${GitUser}/oddloop/main/${namafolder}/ws-ovpn
chmod +x /usr/local/bin/ws-ovpn

# ================================
# ENABLE & RESTART SERVICES
# ================================
systemctl daemon-reload
systemctl enable ws-https
systemctl restart ws-https
systemctl enable ws-http
systemctl restart ws-http
systemctl enable ws-ovpn
systemctl restart ws-ovpn

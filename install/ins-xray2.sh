#!/bin/bash
# // wget https://github.com/${GitUser}/
GitUser="NiL070"

# // MY IPVPS
export MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )

# // install socat
apt install socat

# // EMAIL & DOMAIN
export emailcf=$(cat /usr/local/etc/xray/email)
export domain=$(cat /root/domain)

apt install iptables iptables-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
ntpdate pool.ntp.org
apt -y install chrony
timedatectl set-ntp true
systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony
timedatectl set-timezone Asia/Kuala_Lumpur
chronyc sourcestats -v
chronyc tracking -v
date

# // MAKE FILE TROJAN TCP
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray/
mkdir -p /var/log/xray/;
touch /usr/local/etc/xray/akunxtr.conf
touch /var/log/xray/access.log;
touch /var/log/xray/error.log;

# // VERSION XRAY
export version="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"

# // INSTALL CORE XRAY (LATEST)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data

systemctl stop nginx

# // INSTALL CERTIFICATES
mkdir /root/.acme.sh
curl https://raw.githubusercontent.com/NiL070/oddloop/main/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain -d sshws.$domain --standalone -k ec-256 --listen-v6
~/.acme.sh/acme.sh --installcert -d $domain -d sshws.$domain --fullchainpath /usr/local/etc/xray/xray.crt --keypath /usr/local/etc/xray/xray.key --ecc
chmod 755 /usr/local/etc/xray/xray.key;
service squid start
systemctl restart nginx
sleep 0.5;
clear;

# // UUID PATH
export uuid=$(cat /proc/sys/kernel/random/uuid)
export uuid1=$(cat /proc/sys/kernel/random/uuid)
export uuid2=$(cat /proc/sys/kernel/random/uuid)
export uuid3=$(cat /proc/sys/kernel/random/uuid)
export uuid4=$(cat /proc/sys/kernel/random/uuid)
export uuid5=$(cat /proc/sys/kernel/random/uuid)
export uuid6=$(cat /proc/sys/kernel/random/uuid)
export uuid7=$(cat /proc/sys/kernel/random/uuid)
export uuid8=$(cat /proc/sys/kernel/random/uuid)

# // JSON WS & TCP XTLS
cat > /usr/local/etc/xray/config.json << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
    "inbounds": [
        {
      "listen": "127.0.0.1",
      "port": 10085, # CEK USER QUOTA
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
            },
            {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "85454939-cd36-40f4-b9a5-1cc80bc557a7",
            "flow": "xtls-rprx-vision",
            "level": 0
#xray-vless-xtls-rprx-vision
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "name": "sshws.rnd.nil07.shop", # // SSHWS TLS
            "dest": 2091,
            "xver": 1
          },
          {
            "dest": 1211, # // TROJAN TCP TLS
            "xver": 1
          },
          {
            "path": "/vless", # // VLESS WS TLS
            "dest": 1212,
            "xver": 1
          },
          {
            "path": "/httpupgrade", # // HTTPUPGRADE TLS
            "dest": 1213,
            "xver": 1
          },
          {
            "path": "/vmess", # // VMESS WS TLS
            "dest": 1214,
            "xver": 1
          },
          {
            "path": "/trojanwstls", # // TROJAN WS TLS
            "dest": 1215,
            "xver": 1            
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/usr/local/etc/xray/xray.crt",
              "keyFile": "/usr/local/etc/xray/xray.key"
            }
          ],
          "minVersion": "1.2"
        }
      }
    },
    {
      "port": 1211,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "7c374438-44ee-466c-929c-bf9e05915573"
#trojan
          }
        ],
        "fallbacks": [
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "acceptProxyProtocol": true
        }
      }
    },
    {
      "port": 1212,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "53918212-d760-4622-ae19-25b7466d9523",
            "level": 0
#xray-vless-tls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vless"
        }
      }
    },
    {
      "port": 1214,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "037eb604-389b-4516-8b91-cc02556b1a81",
            "alterId": 0,
            "level": 0
#xray-vmess-tls
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess"
        }
      }
    },
    {
      "port": 1215,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "304a78b4-9956-4775-8b2b-b2433863b122"
#xray-trojan-tls
          }
        ],
        "udp": true
      },
      "streamSettings":{
        "network": "ws",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojanwstls"
        }
      }
    },
    {
      "port": 1213,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "53918212-d760-4622-ae19-25b7466d9523",
            "level": 0
#httpupgrade-tls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/httpupgrade"
        }
      }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "53918212-d760-4622-ae19-25b7466d9523"
#xray-vless-xhttp-tls 
          }           
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [ "h2", "http/1.1" ],
          "certificates": [
            {
              "certificateFile": "/usr/local/etc/xray/xray.crt",
              "keyFile": "/usr/local/etc/xray/xray.key"
            }
          ],
          "minVersion": "1.2"
        },
        "xhttpSettings": {
        "path": "/xhttp",
        "headers": {},
        "mode": "packet-up",
        "noSSEHeader": false,
        "scMaxEachPostBytes": "500000-1000000",
        "scMinPostsIntervalMs": "10-50",
        "scMaxBufferedPosts": 30
       }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },

      /* ===== DOMAIN WARP (MUDAH BUANG) ===== */
      {
        "type": "field",
        "domain": [
          "domain:example.net"
        ],
        "outboundTag": "direct"
      }
    ]
  },

  "stats": {},

  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },

  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "tag": "warp",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 40000
          }
        ]
      }
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "api"
    }
  ]
}
END

# // JSON WS NONE
cat > /usr/local/etc/xray/none.json << END
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
    "inbounds": [
        {
      "listen": "127.0.0.1",
      "port": 10086, # CEK USER QUOTA
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
            },
            {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "0eb24801-661a-4cd6-8505-a20087d4de5f"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 1301, # // VLESS NONE
            "xver": 1
          },
          {
            "path": "/httpupgrade", # // HTTPUPGRADE NONE
            "dest": 1302,
            "xver": 1			
          },
          {
            "path": "/vmess", # // VMESS NONE
            "dest": 1303,
            "xver": 1
          },
          {
             "path": "/trojanwsntls", # // TROJAN NONE
            "dest": 1304,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tlsSettings": {
          "alpn": ["http/1.1"]
        }
      }
    },
    {
      "port": "1301",
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption":"none",
        "clients": [
          {
            "id": "a539d4bf-77bb-4f2d-8525-ae2eb63614d2"
#xray-vless-nontls
          }
        ]
      },
      "streamSettings":{
        "network": "ws",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/"
        }
      }
    },
    {
      "port": "1303",
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "44378ff7-a1c0-4484-91c1-0f10b1563aed",
            "alterId": 0
#xray-vmess-nontls
          }
        ]
      },
      "streamSettings":{
        "network": "ws",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess"
        }
      }
    },
    {
      "port": "1304",
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "decryption":"none",
        "clients": [
          {
            "password": "5be18eb2-3035-4e4d-9c21-807152af7dd9"
#xray-trojan-nontls
          }
        ],
        "udp": true
      },
      "streamSettings":{
        "network": "ws",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojanwsntls"
        }
      }
    },
    {
      "port": 1302,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "a539d4bf-77bb-4f2d-8525-ae2eb63614d2",
            "level": 0
#httpupgrade-nontls
          }
        ]
      },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/httpupgrade"
        }
      }
    },
    {
      "port": 8080,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "a539d4bf-77bb-4f2d-8525-ae2eb63614d2"
#xray-vless-xhttp-nontls         
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/xhttp",
          "headers": {},
          "scMaxBufferedPosts": 20,
          "scMaxEachPostBytes": 800000,
          "noSSEHeader": false,
          "xPaddingBytes": "100-1000",
          "mode": "auto"
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },

      /* ===== DOMAIN WARP (MUDAH BUANG) ===== */
      {
        "type": "field",
        "domain": [
          "domain:example.net"
        ],
        "outboundTag": "direct"
      }
    ]
  },

  "stats": {},

  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },

  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "tag": "warp",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 40000
          }
        ]
      }
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "api"
    }
  ]
}
END

# // IPTABLE TCP 
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8880 -j ACCEPT


# // IPTABLE UDP
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8080 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8880 -j ACCEPT
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# // ENABLE XRAY TCP XTLS 80/443
systemctl daemon-reload
systemctl enable xray.service
systemctl restart xray.service
systemctl enable xray@none
systemctl restart xray@none

# // ENABLE XRAY WS TLS && NONE TLS
systemctl enable xray@config
systemctl restart xray@config

# download script
cd /usr/bin
wget -O port-xray "https://raw.githubusercontent.com/${GitUser}/oddloop/main/change-port/port-xray2.sh"
wget -O certv2ray "https://raw.githubusercontent.com/${GitUser}/oddloop/main/cert.sh"
wget -O trojaan "https://raw.githubusercontent.com/${GitUser}/oddloop/main/menu/trojaan2.sh"
wget -O xraay "https://raw.githubusercontent.com/${GitUser}/oddloop/main/menu/xraay2.sh"
chmod +x port-xray
chmod +x certv2ray
chmod +x trojaan
chmod +x xraay

# // Install XrayCore Mod V.25.10.15 (Custompath)
mv /usr/local/bin/xray /usr/local/bin/xray.bakk && wget -q -O /usr/local/bin/xray "https://github.com/howitzer07/xraycore/releases/download/v25.10.15/xray-linux-amd64" && chmod 755 /usr/local/bin/xray

cd
rm -f ins-xray.sh
mv /root/domain /usr/local/etc/xray/domain
cp /usr/local/etc/xray/domain /etc/xray/domain
sleep 1
clear;

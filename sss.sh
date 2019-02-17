#!/bin/bash
apt update && apt install shadowsocks nginx simple-obfs git letsencrypt haveged
systemctl disable shadowsocks-libev.service
systemctl stop shadowsocks-libev.service
echo "设置你的密码:"
read PASS
cat <<-EOF > /etc/shadowsocks-libev/config-obfs.json
{
    "server":"0.0.0.0",
    "server_port":443,
    "local_port":1080,
    "password":"${PASS}",
    "timeout":180,
    "method":"xchacha20-ietf-poly1305",
    "mode":"tcp_and_udp",
    "fast_open":true,
    "plugin":"obfs-server",
    "plugin_opts":"obfs=tls;failover=127.0.0.1:8088;fast-open"
}
EOF
systemctl stop nginx
echo "申请https证书，你将填写你的邮箱及域名等"
echo "遇到\"How would you like to authenticate with the ACME CA?\""
echo "选1(standalone)"
certbot certonly
echo "请再次输入你的域名，用于生成nginx配置:"
read DOMAIN
cat <<-EOF > /etc/nginx/sites-enabled/default
server {
       listen 80 fastopen=3;
       listen [::]:80 fastopen=3;
       server_name _;
       return 301 https://${DOMAIN}\$request_uri;
}
server {
       listen 127.0.0.1:8088 fastopen=3;
       listen [::1]:8088 fastopen=3 reuseport;

       ssl on;
       ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;        # path to your cacert.pem
       ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;    # path to your privkey.pem

       server_name ${DOMAIN};

       root /var/www/blog.edward-p.xyz;
       index index.html;

       location / {
               try_files \$uri \$uri/ =404;
       }
       server_tokens off;
       fastcgi_param   HTTPS               on;
       fastcgi_param   HTTP_SCHEME         https;
}
EOF

git clone https://github.com/edward-p/edward-p.github.io /var/www/blog.edward-p.xyz


cat <<-EOF >> /etc/security/limits.conf
*               soft    nofile          51200
*               hard    nofile          51200
EOF

cat <<-EOF > /etc/sysctl.conf
# BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# turn off icmp echo
net.ipv4.icmp_echo_ignore_all = 1

# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096

# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_fastopen_blackhole_timeout_sec = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# turn on TCP Fast Open on both client and server side
net.ipv4.tcp_fastopen = 3
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1
EOF
systemctl enable shadowsocks-libev-server@config-obfs

clear
echo "配置成功,按回车重启"
read
reboot

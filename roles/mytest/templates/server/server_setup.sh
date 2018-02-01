#!/bin/bash

if [[ $# -lt 4 ]]; then
    echo "Usage: bash server_setup.sh mytest-server-1/2/3/4/5/6/7/8/9 new|clone proxy_ip proxy_port"
    exit 0
fi

server_name=$1
proxy_ip=$3
proxy_port=$4

if [[ "$2" = "new" ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -x ${proxy_ip}:${proxy_port} | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update --fix-missing --allow-unauthenticated
    apt -y install docker.io python-pip
    yes | pip install ansible==2.3.2.0
    apt -y install apache2
    echo "http_proxy=http://${proxy_ip}:${proxy_port}" > /etc/default/docker
    echo "https_proxy=http://${proxy_ip}:${proxy_port}" >> /etc/default/docker
    echo "Acquire::http::Proxy \"http://${proxy_ip}:${proxy_port}\"" > /etc/apt/apt.conf
fi

mkdir -p /root/certs
cd /root/certs

rm -rf *.crt *.key
rm -rf /etc/docker/certs.d/*

openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 3650 -out domain.crt -subj "/C=US/ST=CA/L=SF/O=Company/OU=Engineering/CN=${server_name}"

cp domain.crt /usr/local/share/ca-certificates/${server_name}.crt
update-ca-certificates

mkdir -p /etc/docker/certs.d/${server_name}:5000
cp domain.crt /etc/docker/certs.d/${server_name}:5000/domain.cert
cp domain.key /etc/docker/certs.d/${server_name}:5000/domain.key
echo -en "{\n \"insecure-registries\" : [\"${server_name}:5000\"] \n}" > /etc/docker/daemon.json

service docker restart

# Ansible_Docker_Jenkins

Steps to create docker containers on VMs created on bare metals with VMware Hypervisor.

### Install VMware Hypervisor on 8RU/39RU bare metals hosts
* Download [VMware vSphere Hypervisor ESXi 6.5 iso](https://my.vmware.com/web/vmware/details?downloadGroup=ESXI650&productId=614) 
* Login CIMC and choose Remote Presence->Virtual Media->Add New Mapping->Mount Type:WWW
* Launch KVM Console and press Fn+F6 to enter boot menu, choose CIMC-Mapped vDVD to install
* After installation, Fn+F2 to config Network Adapters and IPv4 Configuration

### Create VM on host
* Add host via VMware vSphere Web Client
* SSH to admin VM and bring up PowerCLI: 
```sh
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -noe -c ". \"C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1\" $true"
Connect-VIServer test-vc.mycompany.com -User administrator@vsphere.local -Password mypassword
```
* Manually create golden Ubuntu 16.04 VM
  - Install Python, Apache, Ansible, Java JDK, Docker, etc
  ```
  apt install rpm vim lsb-release python python-dev openssl curl iptables netcat net-tools python-setuptools python-netifaces python-requests python-pip ipset iputils-ping dmidecode cpio jq
  apt install apache2 openjdk-8-jre-headless nmap imagemagick sshpass icedtea-netx corkscrew
  yes|pip install ansible=2.3.2.0
  yes|pip install --upgrade mechanize BeautifulSoup requests flask
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt-get update
  apt-get install docker.io
  ```
  - Export proxy if behind a proxy
* Clone golden VM using [vm_customize.ps1](https://github.com/LS2002/VMWare_PowerCLI/blob/master/vm_customize.ps1)

### Create ansible inventory, playbooks, and roles folder structure
* Put below structure under `roles/mytest/`
```
├── inventory
│   └── mytest.inventory
├── playbooks
│   └── mytest.yml
└── roles
    └── mytest
        ├── defaults
        │   └── main.yml
        ├── files
        │   ├── requirements.txt
        │   └── dummy.txt
        ├── handlers
        │   └── main.yml
        ├── tasks
        │   ├── main.yml
        │   └── test.yml
        └── templates
            ├── docker
            │   ├── Dockerfile_ubuntu
            │   └── docker_utils.sh
            ├── server
            │   ├── server_utils.py
            │   └── start_server.py
            ├── service
            │   ├── docker.service
            │   └── docker_http-proxy.conf
            └── worker
                ├── run_test_executor.sh
                ├── run_test_script.py
                └── start_container.sh
```

### Create Inventory `mytest.inventory`
* Use Google Spreadsheet to organize VMs in the format of: vm_name,vm_ip,container_subnet,instance_start,instance_end
* Add [server] along with its ip, and list of [workers] with data in above spreadsheet
* Choose a /21 [CIDR](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing#IPv4_CIDR_blocks) subnet to accomodate 2000 containers per VM

### Prepare Server `mytest-server`
* Clone a VM from golden VM and use it as Server
* Install docker
* Create self signed certificate
```
server_name=mytest-server
mkdir -p /root/certs
cd /root/certs

rm -rf *.crt *.key
rm -rf /etc/docker/certs.d/*

openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 3650 -out domain.crt -subj "/C=US/ST=CA/L=PA/O=COMPANY/OU=Engineering/CN=${server_name}"

cp domain.crt /usr/local/share/ca-certificates/${server_name}.crt
update-ca-certificates

mkdir -p /etc/docker/certs.d/${server_name}:5000
cp domain.crt /etc/docker/certs.d/${server_name}:5000/domain.cert
cp domain.key /etc/docker/certs.d/${server_name}:5000/domain.key
echo -en "{\n \"insecure-registries\" : [\"${server_name}:5000\"] \n}" > /etc/docker/daemon.json

service docker restart
```

### Install DNS Server on `mytest-server`
* bind9
```
apt install bind9 bind9utils bind9-doc
vi /etc/default/bind9 # add OPTIONS="-4 -u bind"
vi /etc/bind/named.conf.options # add transfer and trusted
vi /etc/bind/named.conf.local # add new zone
vi /etc/bind/db.mytest-server
/etc/init.d/bind9 restart
```

### Install Proxy Server on `mytest-server`
* squid
```
apt install squid
# edit squid.conf according to roles/mytest/files/squid.conf
vi /etc/squid/squid.conf
service squid restart
```

### Steps to run the test
```
cd mytest
ansible-playbook -i inventory/mytest.inventory playbooks/mytest.yml -vvv -s -e install=true  --forks 60
```

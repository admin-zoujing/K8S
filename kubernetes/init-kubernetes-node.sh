#! /bin/bash
#centos7.4 docker安装脚本
#DockerHub网站：https://hub.docker.com/
#chmod -R 777 /usr/local/src/docker
#时间时区同步，修改主机名
ntpdate ntp1.aliyun.com
hwclock -w
echo "*/30 * * * * root ntpdate -s ntp1.aliyun.com" >> /etc/crontab
crontab /etc/crontab
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld 

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid
echo "192.168.8.50 kubernetes-master
192.168.8.51 kubernetes-minion51" >> /etc/hosts

yum -y install kubernetes docker etcd flannel

sed -i 's|KUBE_MASTER="--master=http://127.0.0.1:8080"|KUBE_MASTER="--master=http://192.168.8.50:8080"|' /etc/kubernetes/config 

sed -i 's|KUBELET_ADDRESS="--address=127.0.0.1"|KUBELET_ADDRESS="--address=0.0.0.0"|' /etc/kubernetes/kubelet 
sed -i 's|# KUBELET_PORT="--port=10250"|KUBELET_PORT="--port=10250"|' /etc/kubernetes/kubelet 
sed -i 's|KUBELET_HOSTNAME="--hostname-override=127.0.0.1"|KUBELET_HOSTNAME="--hostname-override=192.168.8.51"|' /etc/kubernetes/kubelet 
sed -i 's|KUBELET_API_SERVER="--api-servers=http://127.0.0.1:8080"|KUBELET_API_SERVER="--api-servers=http://192.168.8.50:8080"|' /etc/kubernetes/kubelet 


sed -i 's|#ETCD_LISTEN_PEER_URLS="http://localhost:2380"|ETCD_LISTEN_PEER_URLS="http://192.168.8.51:2380"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_LISTEN_CLIENT_URLS="http://localhost:2379"|ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_NAME="default"|ETCD_NAME="slave1"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380"|ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.51:2380"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"|ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.51:2379"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER="default=http://localhost:2380"|ETCD_INITIAL_CLUSTER="master=http://192.168.8.50:2380,slave1=http://192.168.8.51:2380"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"|ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER_STATE="new"|ETCD_INITIAL_CLUSTER_STATE="new"|' /etc/etcd/etcd.conf 

for SERVICES in etcd docker kube-proxy kubelet; do
systemctl restart $SERVICES
systemctl enable $SERVICES
systemctl status $SERVICES
done


sed -i 's|FLANNEL_ETCD_ENDPOINTS="http://127.0.0.1:2379"|FLANNEL_ETCD_ENDPOINTS="http://192.168.8.50:2379,,http://192.168.8.51:2379"|' /etc/sysconfig/flanneld 
etcdctl --endpoints="http://192.168.8.50:2379,http://192.168.8.51:2379" set /atomic.io/network/config '{ "Network": "10.254.0.0/16","Backend": {"Type": "vxlan"} }'

for SERVICES in docker etcd flanneld kube-proxy kubelet; do
systemctl restart $SERVICES
systemctl enable $SERVICES
systemctl status $SERVICES
done


#docker --version 
#docker images 
#docker search lnmp |head 
#docker pull centos
#docker images
#docker run -itd docker.io/centos /bin/bash 
#cat /proc/version
#exit -exit docker
#exit

#Docker升级
#yum -y remove docker* 
#wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
#sed -i ‘s/gpgcheck=1/gpgcheck=0/g’ /etc/yum.repos.d/docker-ce.repo
#yum -y install docker-ce 
#或者
#wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.06.1.ce-1.el7.centos.x86_64.rpm
#docker --version 
#systemctl start docker 
#docker version 
#docker run hello-world
#$ docker run -it ubuntu bash


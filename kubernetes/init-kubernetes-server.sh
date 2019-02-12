#! /bin/bash
#centos7.4 kubernetes-server安装脚本

#chmod -R 777 /usr/local/src/kubernetes
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

yum -y install kubernetes etcd flannel

sed -i 's|KUBE_MASTER="--master=http://127.0.0.1:8080"|KUBE_MASTER="--master=http://192.168.8.50:8080"|' /etc/kubernetes/config 

sed -i 's|KUBE_API_ADDRESS="--insecure-bind-address=127.0.0.1"|KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0"|' /etc/kubernetes/apiserver 
sed -i 's|# KUBE_API_PORT="--port=8080"|KUBE_API_PORT="--port=8080"|' /etc/kubernetes/apiserver 
sed -i 's|# KUBELET_PORT="--kubelet-port=10250"|KUBELET_PORT="--kubelet-port=10250"|' /etc/kubernetes/apiserver 
sed -i 's|KUBE_ETCD_SERVERS="--etcd-servers=http://127.0.0.1:2379"|KUBE_ETCD_SERVERS="--etcd-servers=http://192.168.8.50:2379"|' /etc/kubernetes/apiserver 
sed -i 's|KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"|KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"|' /etc/kubernetes/apiserver 


sed -i 's|#ETCD_LISTEN_PEER_URLS="http://localhost:2380"|ETCD_LISTEN_PEER_URLS="http://192.168.8.50:2380"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_LISTEN_CLIENT_URLS="http://localhost:2379"|ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_NAME="default"|ETCD_NAME="master"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380"|ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.50:2380"|' /etc/etcd/etcd.conf 
sed -i 's|ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"|ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.50:2379"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER="default=http://localhost:2380"|ETCD_INITIAL_CLUSTER="master=http://192.168.8.50:2380,slave1=http://192.168.8.51:2380"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"|ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"|' /etc/etcd/etcd.conf 
sed -i 's|#ETCD_INITIAL_CLUSTER_STATE="new"|ETCD_INITIAL_CLUSTER_STATE="new"|' /etc/etcd/etcd.conf 

for SERVICES in etcd kube-apiserver kube-controller-manager kube-scheduler; do
systemctl restart $SERVICES
systemctl enable $SERVICES
systemctl status $SERVICES
done


sed -i 's|FLANNEL_ETCD_ENDPOINTS="http://127.0.0.1:2379"|FLANNEL_ETCD_ENDPOINTS="http://192.168.8.50:2379,http://192.168.8.51:2379"|' /etc/sysconfig/flanneld 
etcdctl --endpoints="http://192.168.8.50:2379,http://192.168.8.51:2379" set /atomic.io/network/config '{ "Network": "10.254.0.0/16","Backend": {"Type": "vxlan"} }'

for SERVICES in etcd flanneld kube-apiserver kube-controller-manager kube-scheduler; do
systemctl restart $SERVICES
systemctl enable $SERVICES
systemctl status $SERVICES
done

#检查以确认现在集群中fed-master能够看到fed-node
kubectl get nodes

mkdir -pv /etc/kubernetes/yaml
echo 'kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  labels:
    app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubernetes-dashboard
  template:
    metadata:
      labels:
        app: kubernetes-dashboard
    spec:
      containers:
      - name: kubernetes-dashboard
        image: docker.io/rainf/kubernetes-dashboard-amd64 
        imagePullPolicy: Always
        ports:
        - containerPort: 9090
          protocol: TCP
        args:
          # Uncomment the following line to manually specify Kubernetes API server Host
          # If not specified, Dashboard will attempt to auto discover the API server and connect
          # to it. Uncomment only if the default does not work.
           - --apiserver-host=http://192.168.8.50:8080
        livenessProbe:
          httpGet:
            path: /
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 9090
  selector:
    app: kubernetes-dashboard
' >  /etc/kubernetes/yaml/kubernetes-dashboard.yaml  

kubectl create -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml 
#  kubectl delete -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml
#  kubectl get pods --namespace kube-system
#  kubectl describe pod kubernetes-dashboard-422604472-qg884 --namespace kube-system
#  kubectl get  -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml
#  kubectl get pods --all-namespaces


#报错details: (open /etc/docker/certs.d/registry.access.redhat.com/redhat-ca.crt: no such file or directory)
#yum -y install *rhsm*
#wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
#rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem
#docker pull registry.access.redhat.com/rhel7/pod-infrastructure:latest

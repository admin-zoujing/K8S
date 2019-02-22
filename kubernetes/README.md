kubernetes简单安装，无需安全认证

#  kubernetes简单使用
# kubectl create -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml 
# kubectl delete -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml
# kubectl get  -f /etc/kubernetes/yaml/kubernetes-dashboard.yaml
# kubectl get pods -o wide
# kubectl get service
# kubectl describe pod frontend-13mvv
# kubectl delete pod frontend-13mvv
# kubectl describe service frontend
# kubectl delete service frontend
# kubectl scale rc frontend-13mvv --replicas=4

下面做一个基于NFS的存储，NFS支持多客户端的读写
yum -y install nfs-utils
mkdir -pv /data/volumes 

设置共享：
echo '/data/volumes 192.168.8.0/24(rw,no_root_squash)' > /etc/exports
systemctl start nfs

在node1和node2也安装nfs
yum -y install nfs-utils 
mount -t nfs 192.168.8.50:/data/volumes /mnt
umount /mnt
echo 'apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-nfs
  namespace: default
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: html
    nfs:
      path: /data/volumes
      server: 192.168.8.52
' > /etc/kubernetes/yaml/pod-vol-nfs.yaml 
kubectl apply -f /etc/kubernetes/yaml/pod-vol-nfs.yaml 
 
echo 'hello，word' > /data/volumes/index.html
kubectl get pods -o wide
curl 10.244.2.56
思考：这是一种利用NFS方式挂载到k8S内部的方式，有点，pod挂掉后数据还在，适合做存储。前提是每个节点都安装NFS
#####################################################
开始做PV和PVC实验
echo '/data/volumes/v1 192.168.8.0/24(rw,no_root_squash)
/data/volumes/v2 192.168.8.0/24(rw,no_root_squash)
/data/volumes/v3 192.168.8.0/24(rw,no_root_squash)
/data/volumes/v4 192.168.8.0/24(rw,no_root_squash)
/data/volumes/v5 192.168.8.0/24(rw,no_root_squash)
' > /etc/exports

 
重新加载配置：exportfs -arv
             showmount -e

 
查看PV的帮助文档: kuebctl explain pv
                 kubectl explain pv.spec.nfs
创建yaml文件
echo 'apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv001
  labels:
    name: pv001
spec:
  nfs:
    path: /data/volumes/v1
    server: node3
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 5Gi
--- 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv002
  labels:
    name: pv002
spec:
  nfs:
    path: /data/volumes/v2
    server: node3
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 7Gi
--- 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv003
  labels:
    name: pv003
spec:
  nfs:
    path: /data/volumes/v1
    server: node3
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 8Gi
--- 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv004
  labels:
    name: pv004
spec:
  nfs:
    path: /data/volumes/v4
    server: node3
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 10Gi
--- 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv005
  labels:
    name: pv005
spec:
  nfs:
    path: /data/volumes/v5
    server: node3
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 12Gi
--- 
' > /etc/kubernetes/yaml/pvs-demo.yaml 
开始创建：
kubectl get pv
kubectl apply -f pvs-demo.yaml 
kubectl get pv

pv定义完成，我们定义pvc
echo 'apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
  namespace: default
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 6Gi    #定义的资源是6G，他会在资源中自动寻找合适的
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-nfs
  namespace: default
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: html
    persistentVolumeClaim:
      claimName: mypvc
' > /etc/kubernetes/yaml/pod-vol-pvc.yaml 

创建资源
kubectl apply -f /etc/kubernetes/yaml/pod-vol-pvc.yaml 
kubectl get pv
kubectl get pvc

权限是单路读写，多路读写
说明mypvc已经绑定到了pv002上了
注意：如果定义的策略是return,将pv和pvc删除掉，数据也会存在目录上,一般情况下，我们只删除pv，而不会删除pvc
1.10版本之前能删除PVC的
1.10之后是不能删除PVC的
只要pv和pvc绑定，我们就不能删除pvc



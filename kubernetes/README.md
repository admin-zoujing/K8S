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
[root@master volumes]# cat pod-vol-nfs.yaml 
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
    nfs:
      path: /data/volumes
      server: node3.com
创建 kubectl apply -f pod-vol-nfs.yaml
 
[root@node3 volumes]# cd /data/volumes/
[root@node3 volumes]# vim index.html  输入：hello，word
查看kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP            NODE      NOMINATED NODE
pod-vol-nfs   1/1       Running   0          12s       10.244.2.56   node2     <none>
[root@master volumes]# curl 10.244.2.56
思考：这是一种利用NFS方式挂载到k8S内部的方式，有点，pod挂掉后数据还在，适合做存储。
前提是每个节点都安装NFS
#####################################################
开始做PV和PVC实验
vim /etc/exports
/data/volumes/v1 192.168.0.0/16(rw,no_root_squash)
/data/volumes/v2 192.168.0.0/16(rw,no_root_squash)
/data/volumes/v3 192.168.0.0/16(rw,no_root_squash)
/data/volumes/v4 192.168.0.0/16(rw,no_root_squash)
/data/volumes/v5 192.168.0.0/16(rw,no_root_squash)
 
重新加载配置：
[root@node3 volumes]# exportfs -arv
exporting 192.168.0.0/16:/data/volumes/v5
exporting 192.168.0.0/16:/data/volumes/v4
exporting 192.168.0.0/16:/data/volumes/v3
exporting 192.168.0.0/16:/data/volumes/v2
exporting 192.168.0.0/16:/data/volumes/v1
[root@node3 volumes]# showmount -e
Export list for node3:
/data/volumes/v5 192.168.0.0/16
/data/volumes/v4 192.168.0.0/16
/data/volumes/v3 192.168.0.0/16
/data/volumes/v2 192.168.0.0/16
/data/volumes/v1 192.168.0.0/16
 
查看PV的帮助文档
kuebctl explain pv
kubectl explain pv.spec.nfs
创建yaml文件
[root@master volumes]# cat pvs-demo.yaml 
apiVersion: v1
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
开始创建：
[root@master volumes]# kubectl get pv
No resources found.
[root@master volumes]# kubectl apply -f pvs-demo.yaml 
persistentvolume/pv001 created
persistentvolume/pv002 created
persistentvolume/pv003 created
persistentvolume/pv004 created
persistentvolume/pv005 created
[root@master volumes]# kubectl get pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
pv001     5Gi        RWO,RWX        Retain           Available                                      7s
pv002     7Gi        RWO,RWX        Retain           Available                                      7s
pv003     8Gi        RWO,RWX        Retain           Available                                      7s
pv004     10Gi       RWO,RWX        Retain           Available                                      7s
pv005     12Gi       RWO,RWX        Retain           Available                                      7s
[root@master volumes]# 
pv定义完成，我们定义pvc
[root@master volumes]# cat pod-vol-pvc.yaml 
apiVersion: v1
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
 
创建资源
[root@master volumes]# kubectl apply -f pod-vol-pvc.yaml 
persistentvolumeclaim/mypvc created
pod/pod-vol-nfs created
[root@master volumes]# kubectl get pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM           STORAGECLASS   REASON    AGE
pv001     5Gi        RWO,RWX        Retain           Available                                            16m
pv002     7Gi        RWO,RWX        Retain           Bound       default/mypvc                            16m   #自动寻找到PV002上
pv003     8Gi        RWO,RWX        Retain           Available                                            16m
pv004     10Gi       RWO,RWX        Retain           Available                                            16m
pv005     12Gi       RWO,RWX        Retain           Available                                            16m
我们查看一下PVC的状态
[root@master volumes]# kubectl get pvc
NAME      STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mypvc     Bound     pv002     7Gi        RWO,RWX                       3m
权限是单路读写，多路读写
说明mypvc已经绑定到了pv002上了
注意：如果定义的策略是return
将pv和pvc删除掉，数据也会存在目录上
一般情况下，我们只删除pv，而不会删除pvc
1.10版本之前能删除PVC的
1.10之后是不能删除PVC的
只要pv和pvc绑定，我们就不能删除pvc
e2KWEwPeFsZB


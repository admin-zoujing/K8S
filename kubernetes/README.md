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
yum install nfs-utils -y

mount -t nfs node3:/data/volumes /mnt
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


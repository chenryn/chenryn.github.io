---
layout: post
title: 私有 docker 仓库部署测试
category: cloud
tags:
  - docker
  - python
---

docker 的官方仓库 CDN 的ip 总是被 GFW 认证。为了更好的使用 docker ，有必要在自己内部搭建一个私有仓库。方法很简单：

```python
git clone https://github.com/dotcloud/docker-registry.git
cd docker-registry
# 安装依赖
yum install python-devel libevent-devel python-pip openssl-devel xz-devel --enablerepo=epel
python-pip install -r requirements.txt
# 默认读取config/config.yml里的dev配置
WORKER_SECRET_KEY="${WORKER_SECRET_KEY:-$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)}"
cat > config/config.yml<EOF
dev:
    storage: local
    storage_path: /tmp/registry
    secret_key: ${WORKER_SECRET_KEY}
EOF

# 默认的镜像存储位置，可以在 config.yml 里更改 storage_path
mkdir /tmp/registry
# 默认监听5000端口，前台运行，可以加入daemontools、supervisor、ubic之类的来负责
sh run.sh
```

这就完成了。如果想用 nginx 作代理和加速镜像下载性能的，代码里也提供了 nginx.conf 可用。不过注意要求 nginx 版本在 1.3.9 以上，同时编译的时候还要加上 chunkin 模块。否则镜像上传的时候会出错。

然后就是客户端如何指定镜像推送到私有仓库里：

```bash
# 在私有仓库注册用户
docker login 127.0.0.1:5000
# 给要提交的镜像打标签
docker tag <IMAGE ID> 127.0.0.1:5000/tagname
# 推送到私有仓库
docker push 127.0.0.1:5000/tagname
```

注意这里推送的时候使用的是REPOSITORY，也就是说不能是 `127.0.0.1:5000/ubuntu:12.04` 这样的格式。

现在就可以在其他地方用了：

```bash
docker pull 192.168.0.2:5000/tagname
```

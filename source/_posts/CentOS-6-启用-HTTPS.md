---
title: CentOS 6 启用 HTTPS
date: 2017-05-16 13:17:20
tags: 
	- HTTPS
	- Letsencrypt
photos:
	- https://oa7ktymto.qnssl.com/https.png
---

原文出处：[https://nixcp.com/install-lets-encrypt-ssl-centos-nginx/](https://nixcp.com/install-lets-encrypt-ssl-centos-nginx/)

<!--more-->

### 0x0001 写在前面

由于前段时间太忙，导致忘记了对 [Let's Encrypt](https://letsencrypt.org) 的证书做更新。等发现的时候，证书早已过期，尝试使用自动更新，结果失败。其实这个时候只需要修改一下 `nginx` 配置把原来的 `HTTPS` 关闭，然后再次自动更新应该就是可以成功的。但是当时没有想到这个点，就直接把 Let's Encrypt 的证书删除了，重新安装的。 这里记录一下安装过程中遇到的问题。

### 0x0010 介绍下 Let's Encrypt

[这里](https://letsencrypt.org)是他们的官网，里面有详细的介绍。我这边就简单说下为什么是 Let's Encrypt，而不是其他的家的。

- 免费，不需要花费1分钱就可以有自己的证书
- 很傻瓜式的安装方式
- 不需要任何手动签名或验证过程，这些都在 Linux shell 完成
- 理论上来讲一个命令就可以搞定了

### 0x0011 配置

我的 VPS 是 CentOS 6，然后 Web Server 使用的是 Nginx，这个是前提。如果是其他的系统的话就自己摸索。

##### 安装 Let's Encrypt 的依赖

我们需要安装 [certbot](https://certbot.eff.org/) 这个工具来生成免费证书，安装方式很简单：

```bash
cd /usr/bin
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto   # 给刚刚下载的这个工具执行权限
ln -s /usr/bin/certbot-auto /usr/bin/certbot    # 做一个软连接
```

##### 修改 Nginx 配置

工具安装好了，第二步就是修改 Nginx 的配置，在 Nginx 的配置文件里面加上：

```nginx
location ~ /.well-known {
	allow all;
}
```
加这个的目的是为了方便安装的时候做证书验证。

然后 Reload Nginx

```
service nginx reload
```

##### 安装 Let's Encrypt 证书

运行以下命令，把里面的 `wxy.sexy` 替换成你自己的域名，把 `/usr/local/nginx/html/www.wxy.sexy` 替换成你自己网站的根目录。

```bash
certbot certonly -a webroot --webroot-path=/usr/local/nginx/html/www.wxy.sexy -d wxy.sexy -d www.wxy.sexy
```

执行得到期望的结果如下：

```bash
[root@VPS ~]$ certbot certonly -a webroot --webroot-path=/usr/local/nginx/html/www.wxy.sexy -d wxy.sexy -d www.wxy.sexy
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for wxy.sexy
http-01 challenge for www.wxy.sexy
Using the webroot path /usr/local/nginx/html/www.wxy.sexy for all unmatched domains.
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/wxy.sexy-0001/fullchain.pem. Your cert will
   expire on 2017-08-15. To obtain a new or tweaked version of this
   certificate in the future, simply run certbot again. To
   non-interactively renew *all* of your certificates, run "certbot
   renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

```
到这里说明证书已经安装成功了。

##### 再次修改 Nginx 配置

现在我们来修改 Nginx 的配置，通过配置 `fullchain.pem` 和 `privkey.pem` 文件来启用 SSL 证书

```bash
listen 443 ssl; # 启用 SSL

# 证书依赖的 pem 文件
ssl_certificate /etc/letsencrypt/live/wxy.sexy/fullchain.pem; 
ssl_certificate_key /etc/letsencrypt/live/wxy.sexy/privkey.pem;
```

Reload Nginx

```bash
service nginx reload
```

完整的 Nginx 配置如下：

```
server {
    listen         80;
    server_name    wxy.sexy www.wxy.sexy;

    location / {
      return 301 https://www.wxy.sexy$request_uri;
    }
}
server {
    listen        443 ssl;
    server_name   wxy.sexy www.wxy.sexy;

    ssl     on;
    ssl_certificate     /etc/letsencrypt/live/wxy.sexy/fullchain.pem;
    ssl_certificate_key   /etc/letsencrypt/live/wxy.sexy/privkey.pem;

    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.4.4 8.8.8.8 valid=300s;
    resolver_timeout 10s;
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers On;
    ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;

    error_log   /usr/local/nginx/logs/www.wxy.sexy.error.log;
    access_log  /usr/local/nginx/logs/www.wxy.sexy.access.log;

    root   /usr/local/nginx/html/www.wxy.sexy;
    index  index.html;

    if ($request_method !~ ^(GET|HEAD)$ ) {
        return    444;
    }

    location ~ /.well-known {
          allow all;
    }

    location / {
        add_header              Strict-Transport-Security "max-age=31536000";
        add_header              X-Frame-Options deny;
        add_header              X-Content-Type-Options nosniff;
        add_header              Cache-Control no-cache;
    }
}
```

由于我的这个博客只有静态文件，所以就没有其他的一些配置。
这个里面每一项的配置的含义就交给你自己去搞懂了，我这里就不解释了。

##### 最后

这个时候你访问你的网站，如果发现打不开。
请尝试使用 curl -L 选项。如果出现以下的错误：

```
Initializing NSS with certpath: sql:/etc/pki/nssdb * 
CAfile: /etc/pki/tls/certs/ca-bundle.crt 
CApath: none
```
请睡一觉明天再来看这个问题，或许就好了(我出现这个问题就是这么搞定的)。

### 真的是最后了

你可以在 [https://www.ssllabs.com/ssltest/analyze.html?d=www.wxy.sexy&latest](https://www.ssllabs.com/ssltest/analyze.html?d=www.wxy.sexy&latest) 这里测试一下你网站 SSL 的安全等级。

我的是 C. ):逃走

![](https://oa7ktymto.qnssl.com/01234BDE-93AB-4C2F-B869-15A30B9ECE16.png)

## UPDATE 2019-03-18
[certbot](https://certbot.eff.org/)
用这个异常简单

然后在加一个 cronjob 就没啥好担心的了。
最近升级了一下 nginx 配置 现在我的 ssllab 等级已经是 A+ 了。
最新的 nginx 配置：
```
server {
    listen         80;
    server_name    wxy.sexy www.wxy.sexy;

    location / {
      return 301 https://$host$request_uri;
    }
}

server {
    listen        443 ssl;
    server_name   wxy.sexy www.wxy.sexy;

    ssl     on;
    ssl_certificate     /etc/letsencrypt/live/wxy.sexy/fullchain.pem;
    ssl_certificate_key   /etc/letsencrypt/live/wxy.sexy/privkey.pem;

    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.4.4 8.8.8.8 valid=300s;
    resolver_timeout 10s;
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers On;
    ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
    ssl_dhparam /usr/local/nginx/dh/dhparams.pem;

    error_log   /usr/local/nginx/logs/www.wxy.sexy.error.log;
    access_log  /usr/local/nginx/logs/www.wxy.sexy.access.log main;

    root   /usr/local/nginx/html/www.wxy.sexy;
    index  index.html;

    location / {
        add_header              Strict-Transport-Security "max-age=31536000";
        add_header              X-Frame-Options deny;
        add_header              X-Content-Type-Options nosniff;
        add_header              Cache-Control no-cache;
    }
}
```

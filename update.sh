#!/bin/bash

hexo clean

hexo generate

rsync -az -vv --delete -e 'ssh -p 61100 -i ~/.wxy/hy2eqrt' public/ root@wxy.sexy:/usr/share/nginx/html/www.wxy.sexy
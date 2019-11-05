# SYP脚本架

当前版本仅兼容适配 **Darwin/CentOS7.\***

## 安装部署

```
# Linux
$ curl -sS http://gitlab.idata.mobi/syp-apps/sypctl/raw/dev-0.1-master/env.sh | bash
# Darwin
$ curl -sS http://gitlab.idata.mobi/syp-apps/sypctl/raw/dev-0.1-master/darwin-env.sh | bash
```

## 使用手册

```
$ sypctl help
Usage: sypctl <command> [args]

常规操作：
sypctl help              sypctl 支持的命令参数列表，及已部署服务的信息
sypctl upgrade           更新 sypctl 源码
sypctl env               部署基础环境依赖：JDK/Rbenv/Ruby
sypctl deploy            部署服务引导，并安装部署输入 `y` 确认的服务
sypctl deployed          查看已部署服务
sypctl device:update     更新重新提交设备信息

sypctl agent   help      #代理# 配置
sypctl package help      #安装包# 管理
sypctl toolkit help      #工具# 安装
sypctl service help      #服务# 管理
sypctl backup:file help  #备份文件# 管理


  mmmm m     m mmmmm    mmm mmmmmmm m
 #"   " "m m"  #   "# m"   "   #    #
 "#mmm   "#"   #mmm#" #        #    #
     "#   #    #      #        #    #
 "mmm#"   #    #       "mmm"   #    #mmmmm

Current version is 0.0.84
For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git
```

## 工具集列表

- 代理服务管理
- 安装包管理
- 工具集管理
- [服务管理](linux/ruby/service-tools.md)
- 备份文件管理

## Nginx 挂载

```
server {
  server_name server.com;

  location /sypctl {
    proxy_pass         http://127.0.0.1:8086/;
    proxy_redirect     off;
    proxy_set_header   Host $host;
  }
}

# server.com/sypctl
```

## 待完善功能

- 检测业务服务(8080-8086)/redis(6379)/mysql(3306)/zookeeper(2888)/activeMQ(8161/61616)/vnc(5901) 端口的进程状态
- 安装 mysql、修改默认配置（sql_mode/charset）、更新 root 密码及远程登录
- 安装 redis、修改默认配置（支持外网访问/daemon 模式启动/pidpath/默认密码）
- 安装 kettle、支持指定版本
- 预览安装列表及安装路径
- 安装 vnc、支持添加账号

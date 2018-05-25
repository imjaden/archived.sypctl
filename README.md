## 初始化

```
$ curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/env.sh | bash
```

## 使用手册

```
$ sypctl.sh help
Usage: sypctl <command> [<args>]

sypctl help         sypctl 支持的命令参数列表，及已部署服务的信息
sypctl deploy       部署服务引导，并安装部署输入 `y` 确认的服务
sypctl deployed     查看已部署服务
sypctl env          部署基础环境依赖：JDK/Rbenv/Ruby
sypctl upgrade      更新 sypctl 源码

sypctl monitor      已部署的服务进程状态，若未监测到进程则启动该服务
sypctl start        启动已部署的服务进程
sypctl status       已部署的服务进程状态
sypctl restart      重启已部署的服务进程
sypctl stop         关闭已部署的服务进程

sypctl apk <app-name> 打包生意+ 安卓APK;支持的应用如下：
                      - 生意+ shengyiplus
                      - 睿商+ ruishangplus
                      - 永辉 yh_android
                      - 保臻 shenzhenpoly
sypctl <app-name>     切换生意+ iOS 不同项目的静态资源；应用名称同上

Current version is 0.0.7
For full documentation, see: http://gitlab.ibi.ren/syp/sypctl.git
```

## 约束

- 软件安装目录：/usr/local/src
- 数据存储目录: /data/
- 配置信息目录: /opt/syp-config/
- Web 服务目录: /var/www/

## 部署软件

- JDK
- Redis
- Zookeeper
- providerAPI(jar)
- Tomcat(war)
    - TomcatAPI
    - TomcatAdmin
    - TomcatSuperAdmin

## 环境配置

- 阿里云数据库
    - 创建数据库实例
    - 创建账号或给账号授权
    - 白名单配置服务器 IP
    
- 阿里云服务器
    - 防火墙开放端口号：6379/8080-8090
    - 关闭系统防火墙或开放上述端口 @iptables 
    - mysql 代理，以便外网访问 @haproxy

- 域名配置

## 服务监控

- 定时任务
- 开机启动

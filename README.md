## 部署软件

- jdk
- redis
- zookeeper
- providerAPI(jar)
- tomcat(war)
    - tomcatAPI
    - tomcatAdmin
    - tomcatSuperAdmin

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
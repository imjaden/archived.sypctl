## 初始化

```
$ curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/env.sh | bash
```

## 使用手册

```
Usage: sypctl <command> [<args>]

代理操作:
sypctl agent:init help
sypctl agent:init uuid <服务器端已分配的 UUID>
sypctl agent:init human_name <业务名称>
sypctl agent:init title <自定义代理 Web 的标题>
sypctl agent:init favicon <自定义代理 Web 的 favicon 图片链接>
sypctl agent:init list      初始化配置信息列表

sypctl agent:task guard     代理守护者，注册、提交功能
sypctl agent:task info      查看注册信息
sypctl agent:task log       查看提交日志
sypctl agent:task device    对比设备信息与已注册信息（调整硬件时使用）
sypctl agent:job:daemon     服务器端任务的监护者

服务管理:
sypctl service [args]
  list    查看管理的服务列表
  start   启动服务列表中的应用
  status  检查服务列表应用的运行状态
  stop    关闭服务列表中的应用
  restart 重启服务列表中的应用

常规操作：
sypctl help          sypctl 支持的命令参数列表，及已部署服务的信息
sypctl deploy        部署服务引导，并安装部署输入 `y` 确认的服务
sypctl deployed      查看已部署服务
sypctl env           部署基础环境依赖：JDK/Rbenv/Ruby
sypctl upgrade       更新 sypctl 源码
sypctl device:update 更新重新提交设备信息

sypctl monitor       已部署的服务进程状态，若未监测到进程则启动该服务
sypctl start         启动已部署的服务进程
sypctl status        已部署的服务进程状态
sypctl restart       重启已部署的服务进程
sypctl stop          关闭已部署的服务进程

sypctl toolkit <SYPCTL 脚本名称> [参数]
sypctl etl:import <数据表连接配置档>
sypctl etl:status

sypctl apk <app-name> 打包生意+ 安卓APK;支持的应用如下：
                      - 生意+ shengyiplus
                      - 睿商+ ruishangplus
                      - 永辉  yh_android
                      - 保臻  shenzhenpoly
sypctl <app-name>     切换生意+ iOS 不同项目的静态资源；应用名称同上

Current version is 0.0.73
For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git
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

## `sypctl service`

### 工具用途

1. 统一汇总各服务进程的管理命令（启动、关闭、PID）
2. 统一命令使用汇总的命令管理服务进程的状态
3. 基于上述两点，便捷、轻量级运维各服务进程

### 基本用法

```
服务进程管理脚本
Usage: sypctl service [args]
  list    查看管理的服务列表
  start   启动服务列表中的应用
  status  检查服务列表应用的运行状态
  stop    关闭服务列表中的应用
  restart 重启服务列表中的应用
```

### 配置档(services.json)

- 位置: `/etc/sypctl/services.json`
- services.json 内容为 JSON 数组对象
- 数组中元素字段:
    - name: 该服务进程名称
    - id: 该服务的唯一标识（相对 service.json 对象数组）
    - user: 启动该服务使用的系统用户
    - start: 启动服务的命令组
    - stop: 关闭服务的命令组
    - pidpath: 服务进程 PID 路径，进程状态根据 PID 判断

**强调，service 工具监控、关闭服务进程是基于 pid ，无法定位 pid 的服务请谨慎使用**

start/stop 操作是一个命令数组， 即需要预创建目录或清理日志等操作可以一并放在里面，同时命令中可以使用定义好的变量（或手工添加新字段），引用变量的语法 `{{variable}}`


### 操作示例

```
# 查看配置的服务列表(详细)
$ sypctl service list
# 查看配置的服务列表(仅列 name/id/是否属于本机管理)
$ sypctl service list id

# 查看配置的服务列表(详细，渲染命令中嵌套的变量)
$ sypctl service render

# 查看本机配置的服务列表
$ sypctl service status

# 启动所有服务（已启动则会提示当前运行的 pid）
$ sypctl service start
# 只启动 app-unicorn 服务（已启动则会提示当前运行的 pid）
$ sypctl service start app-unicorn

# 关闭所有服务
$ sypctl service stop
# 只关闭 app-unicorn 服务
$ sypctl service stop app-unicorn
```

[单机模式的生意+服务配置示例](linux/config/eziiot-services.json)

### TIPS

1. 支持自定义 key, 在命令中嵌套使用，语法：`{{variable}}`。
    - 1.1 不可与**预留关键 key: name/id/user/start/stop/pidpath 冲突**
    - 1.2 预留关键 key 也可以作为变量使用
    
    ```
    {
      "services": [
        {
          "name": "运营平台(普通配置)",
          "id": "saas-admin",
          "user": "root",
          "start": [
            "cd /usr/local/src/tomcatAdmin && bash bin/startup.sh"
          ],
          "stop": [
            "cd /usr/local/src/tomcatAdmin && bash bin/shutdown.sh"
          ],
          "pidpath": "/usr/local/src/tomcatAdmin/temp/running.pid"
        },
        {
          "name": "运营平台(嵌套变量)",
          "id": "saas-admin-variable",
          "user": "root",
          "tomcat_home": "/usr/local/src/tomcatAdmin",
          "start": [
            "cd {{tomcat_home}} && bash bin/startup.sh"
          ],
          "stop": [
            "cd {{tomcat_home}} && bash bin/shutdown.sh"
          ],
          "pidpath": "{{tomcat_home}}/temp/running.pid"
        }
      ]
    }
    ```

2. 支持集群统筹管理
    - 2.1 默认上述 `services.json` 配置的服务列表对所在机器全部有效
    - 2.2 大数据集群机器多，每台设备安装服务不同，按单机模式则每台配置的`services.json` 不同, 维护成本高；集群统筹方案为配置 key(`hostname`) 分配服务列表

    示例集群中有三台机器，共同维护了一份配置档，每台机器分配的服务不同，拷贝到各服务器，会按 `hostname` 分配的服务列表运维。
    
    单机模式也可以按集群模式配置，只是显得画蛇添足，配置的服务列表多于本机要运行的情况时可以使用该模式指定服务。
      
    ```
    {
      "services": [
        {
          "name": "service1",
          "id": "service1",
          "user": "user1",
          "start": ["start service1"],
          "stop": ["stop service1"],        
          "pidpath": "/tmp/service1.pid"
        },
        {
          "name": "service2",
          "id": "service2",
          "user": "user2",
          "start": ["start service2"],
          "stop": ["stop service2"],        
          "pidpath": "/tmp/service2.pid"
        },
        {
          "name": "service3",
          "id": "service3",
          "user": "user3",
          "start": ["start service3"],
          "stop": ["stop service3"],        
          "pidpath": "/tmp/service3.pid"
        }
      ],
      "hostname1": ["service1", "service2"],
      "hostname2": ["service2", "service3"],
      "hostname3": ["service1", "service2", "service3"]
    }
    ```

    [集群模式的Hadoop 大数据服务配置示例](linux/config/hadoop-cluster-services.json)

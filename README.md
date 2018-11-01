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
  render  查看服务配置(渲染变量)
```

### 配置档(services.json)

`/etc/sypctl/services.json`, 4 个一级预留关键字：

- services, 数组，必填，服务列表对象
- hosts, 哈希，选填，为指定主机分配服务列表
- extra, 哈希，选填，全局自定义变量（每个 service 对象也有 extra 关键字，配置优先级高于全局配置）
- config, 哈希, 选填，全局配置（每个 service 对象也有 config 关键字，配置优先级高于全局配置）

services, 数组中对象，8 个二级预留关键字:

- name，字符串，选填， 该服务进程名称
- id, 字符串，必填，该服务的唯一标识（相对 service.json 对象数组）
- user，字符串，选填，启动该服务使用的系统用户，默认当前执行命令时的用户
- start,数组，必填，启动服务的命令组，即需要预创建目录或清理日志等操作可以一并放在里面。
- stop, 数组，必填，关闭服务的命令组，即需要预创建目录或清理日志等操作可以一并放在里面。
- pid_path, 字符串，必填，服务进程 PID 路径，进程状态根据 PID 判断
- extra，哈希，选填，自定义变量（tomcat_home 等通用路径可以抽离出来作变量使用）
- config，哈希，选填，自定义配置
- depend，数组，选填，依赖的服务列表(比如 API 服务需要 mysql/redis, 放入该字段，则会提交 mysql/redis 的执行权重)

**强调，service 工具监控、关闭服务进程是基于 pid ，无法定位 pid 的服务请谨慎使用**

### 操作示例

```
# 查看配置的服务列表(详细)
$ sypctl service list
# 查看配置的服务列表(仅列 name/id/是否属于本机管理)
$ sypctl service list id

# 查看配置的服务列表(详细，渲染命令中嵌套的变量)
$ sypctl service render
# 查看配置的服务列表(仅渲染某个服务的执行命令)
$ sypctl service render app-unicorn

# 查看本机服务的状态状态
$ sypctl service status
# 查看某服务的运行状态
$ sypctl service status app-unicorn

# 启动所有服务（已启动则会提示当前运行的 pid）
$ sypctl service start
# 只启动 app-unicorn 服务（已启动则会提示当前运行的 pid）
$ sypctl service start app-unicorn

# 关闭所有服务
$ sypctl service stop
# 只关闭 app-unicorn 服务
$ sypctl service stop app-unicorn
```

[单机模式的生意+服务配置示例](linux/config/services-eziiot@centos7.json)

### 关于 PID

#### Apache Tomcat/8.5.24

修改 `bin/catalina.sh` 在 154 行添加一行给 `CATALINA_PID` 变量赋值。

```
$ vim bin/catalina.sh

if [ -r "$CATALINA_BASE/bin/setenv.sh" ]; then
  . "$CATALINA_BASE/bin/setenv.sh"
elif [ -r "$CATALINA_HOME/bin/setenv.sh" ]; then
  . "$CATALINA_HOME/bin/setenv.sh"
fi

# 添加此行
CATALINA_PID="$CATALINA_HOME/temp/running.pid"
```

#### nohup

手敲代码启动 nohup 后台服务时，一举指明访问日志（正确的及异常的）的输出文件、PID 文件:

```
nohup java -jar api-service.jar > api-service.log 2>&1 & echo $! > running.pid
```

- `> api-service.log` java 命令输出重定向到 api-service.log（异常的错误输出则会丢失，而这些是开发人员调试所需要的）
- `> api-service.log 2>&1` linux 中屏幕标准输出为 1，标准错误输出为 2，`2>&1` 则表示标准错误输出重定向到标准输出中
- `nohup ...command... &` nohup 标准用法
- `$!` 上一个后台执行程序的进程号(PID); `$?` 上一个命令执行的结果状态(0 成功，其他失败)；`$$` 当前的进程号(PID)
- `echo $! > running.pid` 把刚刚执行的 nohup 后台进程 PID 写入 running.pid 文件

**强调:** `sypctl service` 不支持上述命令，原因很简单：`$!` 会产生歧义， `sypctl service` 会起进程逐条运行 `start/stop` 中的命令，所以在运行上述命令时，`$!` 拿到的其实是 `sypctl service` 的进程号(逃)

推荐两部曲写法:(手工操作推荐上述命令)

```
nohup java -jar api-service.jar > api-service.log 2>&1 &
ps aux | grep api-service.jar | grep -v grep | grep -v nohup | awk '{ print $2 }' | sort | head -n 1 >  {{pid_path}}
```

### TIPS

1. 支持自定义变量, 在命令中嵌套使用，语法：`{{variable}}`。
    - 1.1 可以使用预留关键字(service 对象的 key)
    - 1.2 自定义的变量(`extra`)优先级高于预留关键字
    
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
          "pid_path": "/usr/local/src/tomcatAdmin/temp/running.pid"
        },
        {
          "name": "运营平台(嵌套变量)",
          "id": "saas-admin-variable",
          "user": "root",
          "start": [
            "cd {{tomcat_home}} && bash bin/startup.sh"
          ],
          "stop": [
            "cd {{tomcat_home}} && bash bin/shutdown.sh"
          ],
          "pid_path": "{{tomcat_home}}/temp/{{id}}.pid",
          "extra": {
            "id": "tomcat-admin",
            "tomcat_home": "/usr/local/src/tomcatAdmin"
          }
        }
      ]
    }

    $ sypctl service render saas-admin-variable
    [
      {
        "name": "运营平台(嵌套变量)",
        "id": "saas-admin-variable",
        "user": "root",
        "start": [
          "cd /usr/local/src/tomcatAdmin && bash bin/startup.sh"
        ],
        "stop": [
          "cd /usr/local/src/tomcatAdmin && bash bin/shutdown.sh"
        ],
        "pid_path": "/usr/local/src/tomcatAdmin/temp/tomcat-admin.pid",
        "extra": {
          "id": "tomcat-admin",
          "tomcat_home": "/usr/local/src/tomcatAdmin"
        }
      }
    ]
    ```

2. 支持集群统筹管理
    - 2.1 默认上述 `services.json` 配置的服务列表对所在机器全部有效
    - 2.2 大数据集群机器多，每台设备安装服务不同，按单机模式则每台配置的`services.json` 不同, 维护成本高；

    集群统筹方案为配置 key(`hostname`) 分配服务列表

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
          "pid_path": "/tmp/service1.pid"
        },
        {
          "name": "service2",
          "id": "service2",
          "user": "user2",
          "start": ["start service2"],
          "stop": ["stop service2"],        
          "pid_path": "/tmp/service2.pid"
        },
        {
          "name": "service3",
          "id": "service3",
          "user": "user3",
          "start": ["start service3"],
          "stop": ["stop service3"],        
          "pid_path": "/tmp/service3.pid"
        }
      ],
      "hosts": {
        "hostname1": ["service1", "service2"],
        "hostname2": ["service2", "service3"],
        "hostname3": ["service1", "service2", "service3"]
      }
    }
    ```

    [集群模式的Hadoop 大数据服务配置示例](linux/config/services-kylin@centos7.json)

3. 多措施关闭进程
    - 3.1 启动时由于各种原因进程启动成功但 PID 写入文件失败
    - 3.2 关闭进程时由于各种原因失败，但删除 PID 文件成功

    上述情况都会导致关闭进程的脚本提示关闭起程成功，但其实进程一直在运行。（业务 BUG 场景是部署的新代码没有生效，本质是代码重启失败）。

    推荐使用工具自带的关闭脚本关闭进程后，再使用 `ps` 把查找到服务目录的进程一同杀死。

    ```
    "cd {{tomcat_home}} && bash bin/shutdown.sh",
    "ps aux | grep {{tomcat_home}} | grep -v grep | awk '{ print $2 }' | xargs kill -KILL"

    # 或

    "cat {{pid_path}} | xargs kill -9",
    "ps aux | grep redis-server | grep -v grep | awk '{ print $2 }' | xargs kill -KILL"
    ```


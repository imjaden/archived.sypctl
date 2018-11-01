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

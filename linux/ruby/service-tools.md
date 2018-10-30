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

[单机模式的生意+服务配置示例](linux/config/eziiot-standalone-services.json)

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

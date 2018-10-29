## 工具用途

1. 统一汇总各服务进程的管理命令（启动、关闭、PID）
2. 统一命令使用汇总的命令管理服务进程的状态
3. 基于上述两点，便捷、轻量级运维各服务进程

## 基本用法

```
服务进程管理脚本
Usage: sypctl service [args]
  list    查看管理的服务列表
  start   启动服务列表中的应用
  status  检查服务列表应用的运行状态
  stop    关闭服务列表中的应用
  restart 重启服务列表中的应用
```

## 配置档(services.json)

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


## 操作示例

```
# 查看本机配置的服务列表
$ sypctl service list

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

完整的配置示例：

```
{
  "services": [
    {
      "name": "移动端 App 主服务",
      "id": "app-unicorn",
      "user": "root",
      "start": [
        "cd /usr/local/src/syp-app-server && bundle exec unicorn -c ./config/unicorn.rb -p 8085 -E production -D"
      ],
      "stop": [
        "cat {{pidpath}} | xargs kill -9"
      ],
      "pidpath": "/usr/local/src/syp-app-server/tmp/pids/unicorn.pid"
    },
    {
      "name": "移动端 App 消息队列管理",
      "id": "app-sidekiq",
      "user": "root",
      "start": [
        "cd /usr/local/src/syp-app-server && bundle exec sidekiq -r ./config/boot.rb -C ./config/sidekiq.yaml -e production -d"
      ],
      "stop": [
        "cat {{pidpath}} | xargs kill -9"
      ],
      "pidpath": "/usr/local/src/syp-app-server/tmp/pids/sidekiq.pid"
    },
    {
      "name": "运营平台",
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
      "name": "SAAS-SUPER 运营平台",
      "id": "saas-super-admin",
      "user": "root",
      "start": [
        "cd /usr/local/src/tomcatSuperAdmin && bash bin/startup.sh"
      ],
      "stop": [
        "cd /usr/local/src/tomcatSuperAdmin && bash bin/shutdown.sh"
      ],
      "pidpath": "/usr/local/src/tomcatSuperAdmin/temp/running.pid"
    },
    {
      "name": "JAVA 服务消费者",
      "id": "saas-api",
      "user": "root",
      "start": [
        "cd /usr/local/src/tomcatAPI && bash bin/startup.sh"
      ],
      "stop": [
        "cd /usr/local/src/tomcatAPI && bash bin/shutdown.sh"
      ],
      "pidpath": "/usr/local/src/tomcatAPI/temp/running.pid"
    },
    {
      "name": "JAVA 服务提供者",
      "id": "saas-api-service",
      "user": "root",
      "start": [
        "cd /usr/local/src/providerAPI && nohup java -jar api-service.jar > api-service.log 2>&1 &",
        "ps aux | grep api-service.jar | grep -v grep | grep -v nohup | awk '{ print $2 }' | sort | head -n 1 >  {{pidpath}}"
      ],
      "stop": [
        "cat {{pidpath}} | xargs kill -9"
      ],
      "pidpath": "/usr/local/src/providerAPI/running.pid"
    },
    {
      "name": "JMS 消息队列管理",
      "id": "apache-activemq-5.15.5",
      "user": "root",
      "start": [
        "cd /usr/local/src/apache-activemq-5.15.5 && bash bin/activemq start"
      ],
      "stop": [
        "cd /usr/local/src/apache-activemq-5.15.5 && bash bin/activemq stop"
      ],
      "pidpath": "/usr/local/src/apache-activemq-5.15.5/data/activemq.pid"
    },
    {
      "name": "公共服务",
      "id": "redis",
      "user": "root",
      "start": [
        "redis-server /etc/redis/redis.conf"
      ],
      "stop": [
        "cat {{pidpath}} | xargs kill -9"
      ],
      "pidpath": "/var/run/redis_6379.pid"
    },
    {
      "name": "公共服务",
      "id": "nginx",
      "user": "root",
      "start": [
        "nginx"
      ],
      "stop": [
        "nginx -s stop"
      ],
      "pidpath": "/var/run/nginx.pid"
    },
    {
      "name": "公共服务",
      "id": "zookeeper",
      "user": "root",
      "start": [
        "bash /usr/local/src/zookeeper/bin/zkServer.sh start"
      ],
      "stop": [
        "bash /usr/local/src/zookeeper/bin/zkServer.sh stop"
      ],
      "pidpath": "/usr/local/src/zookeeper/data/zookeeper_server.pid"
    }
  ]
}
```
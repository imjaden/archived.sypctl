## 基本用法

```
服务进程管理脚本
Usage: sypctl service [args]
    -h, --help                       参数说明
    -l, --list                       查看管理的服务列表
    -t, --check                      检查配置是否正确
    -s, --start                      启动服务列表中的应用
    -e, --status                     检查服务列表应用的运行状态
    -k, --stop                       关闭服务列表中的应用
    -r, --restart                    重启服务列表中的应用
```

## services.json

- services.json 内容为 JSON 数组对象
- 位置: /etc/sypctl/services.json
- 数组中元素字段:
    - group: 该服务所属群组
    - name: 该服务进程名称
    - user: 启动该服务使用的系统账号
    - start_commands: 启动服务的命令组
    - stop_commands: 关闭服务的命令组
    - pid_path: 服务进程 PID 路径，进程状态根据 PID 判断

配置示例:

```
[
  {
    "group": "移动端 App",
    "name": "App Server Unicon",
    "user": "junjieli",
    "start_commands": [
      "cd /Users/junjieli/Work/eziiot/syp-app-server && bundle exec unicorn -c ./config/unicorn.rb -p 8085 -E production -D"
    ],
    "stop_commands": [
      "cat {{pid_path}} | xargs -I pid sudo kill -QUIT pid"
    ],
    "pid_path": "/Users/junjieli/Work/eziiot/syp-app-server/tmp/pids/unicorn.pid"
  },
  {
    "group": "移动端 App",
    "name": "App Server Sidekiq",
    "user": "junjieli",
    "start_commands": [
      "cd /Users/junjieli/Work/eziiot/syp-app-server && bundle exec sidekiq -r ./config/boot.rb -C ./config/sidekiq.yaml -e production -d"
    ],
    "stop_commands": [
      "cat {{pid_path}} | xargs -I pid sudo kill -QUIT pid"
    ],
    "pid_path": "/Users/junjieli/Work/eziiot/syp-app-server/tmp/pids/sidekiq.pid"
  },
  {
    "group": "公共服务",
    "name": "Redis",
    "user": "junjieli",
    "start_commands": [
      "sudo /usr/local/bin/redis-server /etc/redis/redis.conf"
    ],
    "stop_commands": [
      "cat {{pid_path}} | xargs -I pid sudo kill -QUIT pid"
    ],
    "pid_path": "/var/run/redis_6379.pid"
  },
  {
    "group": "公共服务",
    "name": "Nginx",
    "user": "junjieli",
    "start_commands": [
      "nginx"
    ],
    "stop_commands": [
      "nginx -s stop"
    ],
    "pid_path": "/usr/local/var/run/nginx.pid"
  }
]
```

## 操作示例

启动命令:

```
$ sypctl service --start
```

日志输出:

```
## 启动 App Server Unicon

$ cd /Users/junjieli/Work/eziiot/syp-app-server && bundle exec unicorn -c ./config/unicorn.rb -p 8085 -E production -D


## 启动 App Server Sidekiq

$ cd /Users/junjieli/Work/eziiot/syp-app-server && bundle exec sidekiq -r ./config/boot.rb -C ./config/sidekiq.yaml -e production -d


## 启动 Redis

$ sudo /usr/local/bin/redis-server /etc/redis/redis.conf


## 启动 Nginx

$ nginx

+------------+--------------------+---------------+
| 群组       | 服务               | 进程状态      |
+------------+--------------------+---------------+
| 移动端 App | App Server Unicon  | 运行中(54901) |
| 移动端 App | App Server Sidekiq | 运行中(54923) |
| 公共服务   | Redis              | 运行中(54931) |
| 公共服务   | Nginx              | 运行中(54934) |
+------------+--------------------+---------------+
```

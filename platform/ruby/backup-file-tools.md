## 服务器端

- 管理要备份的文件列表（统一维护，只增、禁删、禁修）
- 文件存储在服务器端, 以主机 UUID 作为目录名称
- 主机独立维护存在的文件列表（JSON 格式，备份列表的子集）

## 代理端

- 定时提交主机信息时，同时提交备份列表字符串 MD5 值，服务器端对比，若不一致则响应最新备份列表
- 提交主机 UUID, 上传文件，文件追加 MD5、时间戳，留存历史修改记录
- 主机表添加备份信息字段，JSON 格式，维护文件最新的记录状态

## 存储视图

1. 单文件上传
2. 按原始目录归档
3. 记录最近目录状态
4. 记录历史目录状态
5. 文档统一归档，文件链接只存归档路径

单文件上传

```
{
  "device_uuid": "Sypctl::Device.uuid",
  "backup_uuid": "要备份的目录/文件路径",
  "backup_path": "要备份的目录/文件路径",
  "file_path": "本次更新的文件的绝对路径",
  "file_object": "文件对象",
  "file_md5": "文件MD5",
  "file_mtime": "文件修改时间"
}
```

监控目录的最近视图
1. 更新最近目录视图
2. 对比留存历史视图(包括上述视图)

```
# parameters
{
  "device_uuid": "Sypctl::Device.uuid",
  "backup_uuid": "要备份的目录/文件路径",
  "backup_path": "要备份的目录/文件路径",
  "file_type": "f/d",
  "file_count": 4,
  "file_size": 10,
  "file_mtime": 1573282378,
  "description": "sypctl 数据库备份配置档",
  "filelist": {
    "/etc/sypctl/backup-mysql.json": {mtime": "1573447822586", "fmd5": "11f02e01e9a44cb4b426133d316d4113", "pmd5": "11f02e01e9a44cb4b426133d316d4113"}
  },
  "filetree": "",
  "history": []
}

# server snapshot
{
  "device_uuid": "Sypctl::Device.uuid",
  "backup_uuid": "要备份的目录/文件路径",
  "backup_path": "要备份的目录/文件路径",
  "file_type": "f/d",
  "file_count": 4,
  "file_size": 10,
  "file_mtime": 1573282378,
  "description": "sypctl 数据库备份配置档",
  "filelist": {
    "/etc/sypctl/backup-mysql.json": {"synced": true, "mtime": "1573447822586", "fmd5": "11f02e01e9a44cb4b426133d316d4113", "pmd5": "11f02e01e9a44cb4b426133d316d4113"}
  },
  "filetree": "",
  "history": {
    "/etc/sypctl/backup-mysql.json": {"mtime": "1573447822586", "fmd5": "11f02e01e9a44cb4b426133d316d4113", "pmd5": "11f02e01e9a44cb4b426133d316d4113"}
  }
}

# 监控的文档有目录结构，但存储时只保留一级(去目录化)
# 保证文档归档名称的唯一性，结构 `文件路径MD5-时间戳-文件名称`
# 示例: "/etc/sypctl/backup-mysql.json"
# - 目录MD5: MD5 ("/etc/sypctl/backup-mysql.json") = 05de2bedaf056bff7114fc1c49757a65
# - 文件名称: backup-mysql.json
# - 文件时间: 1573447822586
# 归档文件名称: 05de2bedaf056bff7114fc1c49757a65-1573447822586-backup-mysql.json
```

device-uuid
  snapshot.json
  snapshots
      05de2bedaf056bff7114fc1c49757a65-1573447822586-backup-mysql.json
      05de2bedaf056bff7114fc1c49757a65-1573447822586-backup-mysql.json
      05de2bedaf056bff7114fc1c49757a65-1573447822586-backup-mysql.json


{backup-uuid}-snapshot-v2.json
{
  "device_uuid": "Sypctl::Device.uuid",
  "backup_uuid": "要备份的目录/文件路径",
  "backup_path": "要备份的目录/文件路径",
  "file_type": "f/d",
  "file_count": 4,
  "file_size": 10,
  "file_mtime": 1573282378,
  "description": "sypctl 数据库备份配置档",
  "filelist": {
    "/etc/sypctl/backup-mysql.json": {
      "synced": true,
      "mtime": "1573447822586",
      "fmd5": "11f02e01e9a44cb4b426133d316d4113",
      "pmd5": "11f02e01e9a44cb4b426133d316d4113"
    }
  },
  "filetree": ""
  "history": {
    "/etc/sypctl/backup-mysql.json": {
      "mtime": "1573447822586",
      "fmd5": "11f02e01e9a44cb4b426133d316d4113",
      "pmd5": "11f02e01e9a44cb4b426133d316d4113"
    }
  }
}
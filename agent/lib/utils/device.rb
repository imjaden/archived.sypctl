# encoding: utf-8
require 'json'
require 'fileutils'
require 'securerandom'
require File.expand_path('../../core_ext/numberic.rb', __FILE__)

module Sypctl
  class Darwin
    class << self
      def whoami
        `whoami`.strip
      end

      def device_uuid
        `system_profiler SPHardwareDataType | awk '/UUID/ { print $3; }'`.strip
      end

      def memory
        g = `system_profiler SPHardwareDataType | awk '/Memory/ { print $2; }'`.strip.to_i
        g ** 1024
      end

      def cpu
        `sysctl -n machdep.cpu.core_count`.strip.to_i * `sysctl -n machdep.cpu.thread_count`.strip.to_i
      end

      def disk
        `diskutil list | grep GB | head -n 1`.strip.scan(/(\d+).\d+ GB/).flatten[0].to_i ** 1024
      end

      def hostname
        `hostname`.strip
      end

      def os_type
        `uname -s`.strip
      end

      def os_version
        `sw_vers -productName`.strip + '@' +`sw_vers -productVersion`.strip
      end

      def free_m
        total, wired, free  = `top -l 1 -s 0 | grep PhysMem`.scan(/(\S+) used \((\S+) wired\), (\S+) unused/).flatten
        {"total" => total, "wired" => wired, "free" => free}
      end

      def top_memory_snapshot
        {}
      end

      def df_h
        titles, *disks = `df -h`.sub("Mounted on", "MountedOn").split("\n").map { |line| line.split(/\s+/) }
        disks.map do |disk|
          titles.each_with_object({}).with_index do |(title, hsh), index|
            hsh[title] = disk[index]
          end
        end
      end

      def uptime
        (`uptime`.strip.scan(/^(.*?)\s+up\s+(.*?),\s+(\d+)\susers?,\s+load\saverages?:\s?(.*?)$/) || []).flatten
      end

      def lan_ip
        ips = `ifconfig`.scan(/\d+\.\d+\.\d+\.\d+/).flatten

        ips_10 = ips.select { |ip| ip.start_with?('10.') }
        return ips_10[0] unless ips_10.empty?

        ips_192 = ips.select { |ip| ip.start_with?('192.') }
        return ips_192[0] unless ips_192.empty?

        ips[0]
      end

      def wan_ip
        `curl --silent --connect-timeout 1 --max-time 1 https://api.sypctl.com/api/v1/ifconfig.me`.strip
      end

      def process_number
        `ps -ax | wc -l`.strip.to_i
      end

      def pid_max
        `sysctl kern.maxfiles`.strip.scan(/kern.maxfiles: (\d+)/).flatten[0].to_i
      end

      def process_analyse(top_limit = 5)
        list = `ps aux`.split(/\n/).map do |line| 
          parts = line.split(/\s+/)
          pid = parts[1]
          command = parts[9..-1].join(' ')
          [command, pid]
        end

        group_hash = list.group_by { |parts| parts[0] }
        top_array = group_hash.keys.map do |key|
          [key, group_hash[key][0][1], group_hash[key].length]
        end.sort_by { |arr| arr[2] }.reverse.first(top_limit)

        top_array.each do |parts|
          puts "-" * 20
          puts "进程数量：#{parts[2]}, pid: #{parts[1]}"
          puts "进程命令：\n#{parts[0]}"
        end
      end
    end
  end

  class Linux
    class << self
      def whoami
        `whoami`.strip
      end

      # $ blkid -s UUID
      # /dev/mapper/centos_java1-var: UUID="f3a814b5-6fe3-4ecf-a53f-799520c7f932"
      # /dev/sda2: UUID="qAaXeF-RwkI-2qX8-MbUJ-CCCd-2Ta6-3GfEM8"
      # /dev/mapper/centos_java1-root: UUID="a1cae138-52d3-41e9-bfce-fcb466e32e93"
      # /dev/mapper/centos_java1-usr: UUID="7b13ba37-7cfd-4fdb-b4ce-f6a8e6cd7c30"
      # /dev/sda1: UUID="310d9b14-9a2d-415a-b6a8-e8c72facec5c"
      # /dev/mapper/centos_java1-swap: UUID="3d19a3b6-dde5-420a-a0b5-f4de1e90d42b"
      # /dev/mapper/centos_java1-data: UUID="ac3b2ef2-d3a0-458f-89ce-605f8c0afb81"
      # /dev/mapper/centos_java1-tmp: UUID="4d690f04-c4cd-4e29-be86-d4cd46e9e385"
      # /dev/mapper/centos_java1-opt: UUID="8f7236ea-97ef-4aa9-886f-9e1a50a030a1"
      # /dev/mapper/centos_java1-home: UUID="bae67bdc-1ff5-477f-ba08-11f02d2a00d2"
      def device_uuid
        "#{_device_uuid(`sudo blkid -s UUID`)}@#{hostname}"
      end

      def _device_uuid(blkid_lines)
        device_list = blkid_lines.split(/\n/).map do |line|
           device, uuid = line.scan(/(.*?):\sUUID="(.*?)"/).flatten
           {device: device, uuid: uuid}
        end
        device_hsh, i = nil, 0

        while !device_hsh && i < 10
          device_hsh = device_list.find { |hsh| hsh[:device] == "/dev/sda#{i}" || hsh[:device] == "/dev/xvda#{i}" }
          i += 1
        end
        device_hsh = device_list.first unless device_hsh

        "#{device_hsh[:device]}-#{device_hsh[:uuid]}".gsub("/", "_")
      rescue => e
        puts e.message
        "exception-#{SecureRandom.uuid}"
      end

      def memory
        free_m['total'].to_i ** 1024
      end

      def cpu
        `cat /proc/cpuinfo| grep "processor"| wc -l`.strip
      end

      # $ df
      # Filesystem               1K-blocks      Used  Available Use% Mounted on
      # /dev/mapper/centos-root   52403200    436280   51966920   1% /
      # devtmpfs                  16377812         0   16377812   0% /dev
      # tmpfs                     16389648        20   16389628   1% /dev/shm
      # tmpfs                     16389648     50252   16339396   1% /run
      # tmpfs                     16389648         0   16389648   0% /sys/fs/cgroup
      # /dev/mapper/centos-usr   104806400   8346252   96460148   8% /usr
      # /dev/mapper/centos-tmp    10475520    361836   10113684   4% /tmp
      # /dev/mapper/centos-home  104806400     33496  104772904   1% /home
      # /dev/mapper/centos-data 2146435072 145504524 2000930548   7% /data
      # /dev/mapper/centos-opt    10475520    979456    9496064  10% /opt
      # /dev/sda1                  1038336    213300     825036  21% /boot
      # /dev/mapper/centos-var   104806400   8522604   96283796   9% /var
      # tmpfs                      3277932         0    3277932   0% /run/user/0
      def disk
        blocks = `df`.split(/\n/).reject(&:empty?).map { |line| line.scan(/\b\d+\b/).flatten[0].to_f }.inject(:+)
        blocks * 1024
      end

      def hostname
        `hostname`.strip
      end

      def os_type
        `lsb_release -i | awk '{ print $3 }'`.strip
      end

      def os_version
        `lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }'`.strip
      end

      # $ free -m
      #               total        used        free      shared  buff/cache   available
      # Mem:          32011       11120       20030          24         860       20193
      # Swap:         32767           1       32766
      def free_m
        titles, memory, *swap = `free -m`.split("\n").map { |line| line.split(/\s+/) }
        titles.shift if titles[0].empty?
        memory.shift while titles.length < memory.length

        titles.each_with_object({}).with_index do |(title, hsh), index|
          hsh[title] = memory[index]
        end
      end

      def top_memory_snapshot
        lines = `top -b -n 1 -d 3 -o %MEM | head -n 10`.split("\n")
        title_index = lines.find_index { |line| line.include?("PID") }
        titles = lines[title_index].strip.split(/\s+/).map(&:strip)
        lines[title_index+1..-1].map do |line|
          fields = line.split(/\s+/)
          i = 0
          titles.each_with_object({}) do |title, hsh|
            hsh[title] = fields[i]
            hsh["COMMAND"] = `ps --pid #{hsh["PID"]} --format cmd | tail -n 1`.strip if title == "COMMAND"
            i += 1
          end
        end
      end

      # $ df -h
      # Filesystem                     Size  Used Avail Use% Mounted on
      # /dev/mapper/centos_java1-root   50G  567M   50G   2% /
      # devtmpfs                        16G     0   16G   0% /dev
      # tmpfs                           16G     0   16G   0% /dev/shm
      # tmpfs                           16G   25M   16G   1% /run
      # tmpfs                           16G     0   16G   0% /sys/fs/cgroup
      # /dev/mapper/centos_java1-usr   100G  3.1G   97G   4% /usr
      # /dev/sda1                     1014M  167M  848M  17% /boot
      # /dev/mapper/centos_java1-tmp    10G   33M   10G   1% /tmp
      # /dev/mapper/centos_java1-opt    10G   67M   10G   1% /opt
      # /dev/mapper/centos_java1-home  100G   33M  100G   1% /home
      # /dev/mapper/centos_java1-data  600G   35M  600G   1% /data
      # /dev/mapper/centos_java1-var   100G  1.4G   99G   2% /var
      # tmpfs                          3.2G     0  3.2G   0% /run/user/0
      def df_h
        titles, *disks = `df -h`.sub("Mounted on", "MountedOn").split("\n").map { |line| line.split(/\s+/) }
        disks.map do |disk|
          titles.each_with_object({}).with_index do |(title, hsh), index|
            hsh[title] = disk[index]
          end
        end
      end

      # $ uptime
      # 13:13:34 up 7 days, 14:00,  1 user,  load average: 38.79, 43.28, 42.16
      #
      # > `uptime`
      # => "18:04  up 2 days,  8:03, 10 users, load averages: 1.53 1.62 1.60\n"
      #> (`uptime`.strip.scan(/^(.*?)\s+up\s+(.*?),\s+(\d+)\susers?,\s+load\saverages?:\s?(.*?)$/) || []).flatten
      # => ["18:04", "2 days,  8:03", "10", "1.62 1.64 1.61"]
      #
      # > `uptime`
      # => " 18:05:04 up 21:22,  1 user,  load average: 3.46, 3.70, 3.74\n"
      # > (`uptime`.strip.scan(/^(.*?)\s+up\s+(.*?),\s+(\d+)\susers?,\s+load\saverages?:\s?(.*?)$/) || []).flatten
      # => ["18:05:04", "21:22", "1", "3.46, 3.70, 3.74"]
      def uptime
        (`uptime`.strip.scan(/^(.*?)\s+up\s+(.*?),\s+(\d+)\susers?,\s+load\saverages?:\s?(.*?)$/) || []).flatten
      end

      def lan_ip
        ips = `ifconfig`.scan(/\d+\.\d+\.\d+\.\d+/).flatten

        ips_10 = ips.select { |ip| ip.start_with?('10.') }
        return ips_10[0] unless ips_10.empty?

        ips_192 = ips.select { |ip| ip.start_with?('192.') }
        return ips_192[0] unless ips_192.empty?

        ips[0]
      end

      def wan_ip
        `curl --silent --connect-timeout 1 --max-time 1 https://api.sypctl.com/api/v1/ifconfig.me`.strip
      end

      def process_number
        `ps -eLf | wc -l`.strip.to_i
      end

      def pid_max
        `sysctl kernel.pid_max`.strip.scan(/kernel.pid_max = (\d+)/).flatten[0].to_i
      end

      def process_analyse(top_limit = 5)
        list = `ps -eLf`.split(/\n/).map do |line| 
          parts = line.split(/\s+/)
          pid = parts[1]
          command = parts[9..-1].join(' ')
          [command, pid]
        end

        group_hash = list.group_by { |parts| parts[0] }
        top_array = group_hash.keys.map do |key|
          [key, group_hash[key][0][1], group_hash[key].length]
        end.sort_by { |arr| arr[2] }.reverse.first(top_limit)

        top_array.each do |parts|
          puts "-" * 20
          puts "进程数量：#{parts[2]}, pid: #{parts[1]}"
          puts "进程命令：\n#{parts[0]}"
        end
      end
    end
  end

  class Device
    class << self

      def klass
        platform = `uname -s`.strip
        ['Sypctl', platform].inject(Object) { |obj, klass| obj.const_get(klass) }
      end

      def report
        method_list = [:whoami, :uuid, :hostname, :os_type, :os_version, :memory, :memory_usage,
          :cpu, :disk, :disk_usage, :lan_ip, :wan_ip, :process_number, :pid_max, :process_usage]
        method_list.each_with_object({}) do |method_name, hsh|
          hsh[method_name] = send(method_name)
        end
      end

      def print_report
        puts JSON.pretty_generate(report || {})
      end

      def whoami
        klass.whoami
      rescue => e
        e.message
      end

      def uuid(use_cache = true)
        rake_root_path = ENV['RAKE_ROOT_PATH'] || Dir.pwd
        rake_root_path = "#{rake_root_path}/agent" if rake_root_path.split('/').last != 'agent'
        uuid_tmp_path = File.join(rake_root_path, ".config/device-uuid")

        use_cache = true if `uname -s`.strip == 'Darwin'
        if use_cache && File.exist?(uuid_tmp_path)
          device_uuid = File.read(uuid_tmp_path).strip

          return device_uuid unless device_uuid.empty?
          FileUtils.rm_f(uuid_tmp_path)
        end

        device_uuid = klass.device_uuid
        device_uuid = "empty-#{SecureRandom.uuid}" if device_uuid.empty?
        File.open(uuid_tmp_path, "w:utf-8") { |file| file.puts(device_uuid) }

        return device_uuid
      end

      def memory
        klass.memory.number_to_human_size(true)
      rescue => e
        e.message
      end

      def cpu
        klass.cpu
      rescue => e
        e.message
      end

      def disk
        klass.disk.number_to_human_size(true)
      rescue => e
        e.message
      end

      def hostname
        klass.hostname
      rescue => e
        e.message
      end

      def os_type
        klass.os_type
      rescue => e
        e.message
      end

      def os_version
        klass.os_version
      rescue => e
        e.message
      end

      def memory_usage
        hsh = memory_usage_description
        (hsh['used'].to_f/hsh['total'].to_f).round(5)
      rescue => e
        e.message
      end

      def free_m
        klass.free_m
      rescue => e
        e.message
      end

      alias_method :memory_usage_description, :free_m

      def top_memory_snapshot
        klass.top_memory_snapshot
      rescue => e
        e.message
      end

      def cpu_usage
        hsh = cpu_usage_description
        "#{hsh[:latest_load]}/#{hsh[:cpu]}"
      end

      # ["13:10:20", "7 days", "13:57", "1 user", "load average: 54.57, 45.68, 42.34"]
      def cpu_usage_description
        system_time, running_time, connected_users, load_average = klass.uptime
        {
          system_time: system_time,
          running_time: running_time,
          connected_users: connected_users,
          load_average: load_average.strip,
          latest_load: load_average.strip.split(/,/)[0],
          cpu: cpu,
          uptime: `uptime`.strip
        }
      rescue => e
        {exception: e.message}
      end

      def file_size_convertor(file_size)
        file_size = file_size.to_s.downcase.gsub("i", "")
        unit = file_size[-1]
        size = file_size.sub(unit, "").to_f
        unit_size = case unit
        when "m" then 1
        when "g" then 1024
        when "t" then 1024**2
        when "p" then 1024**3
        when "e" then 1024**3
        else 1
        end

        (size * unit_size).round(1)
      rescue => e
        0
      end

      # bug#fix
      # `df -h` 输出的标题头有可能为中文，读取 hash 时无法确实 key 名称（i18n 太多可能）
      def disk_usage
        arr = disk_usage_description
        maximum_item = arr.max { |a, b| file_size_convertor(a.values[1]) <=> file_size_convertor(a.values[1]) }

        (maximum_item.values[4].to_i*1.0/100).round(5)
      rescue => e
        e.message
      end

      def disk_usage_description
        klass.df_h
      rescue => e
        e.message
      end

      def lan_ip
        klass.lan_ip
      rescue => e
        e.message
      end

      def wan_ip
        klass.wan_ip
      rescue => e
        e.message
      end

      def process_number
        klass.process_number
      rescue => e
        e.message
      end

      def pid_max
        klass.pid_max
      rescue => e
        e.message
      end

      def process_usage
        (process_number*1.0/pid_max).round(5)
      rescue => e
        e.message
      end

      def process_analyse
        klass.process_analyse
      rescue => e
        e.message
      end
    end
  end
end


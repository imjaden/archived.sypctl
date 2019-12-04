#!/usr/bin/env ruby
# encoding: utf-8
require 'json'
require 'optparse'
require 'colorize'
require 'colorized_string'

obj = JSON.parse(File.read('version.json'))
obj['commit'] = obj['commit'].to_i + 1
version = [obj['major'], obj['minor'], obj['commit']].join('.')

def run_command(label, command)
  puts ''
  puts '# '.colorize(:gray) + label.colorize(:yellow)
  puts '$ '.colorize(:gray) + command.colorize(:yellow)
  puts ''
  system(command)
  puts ''
end

if ARGV.length < 3
  puts '示例:'
  puts '$ ./gap.rb <type> <module> <message>'
  exit 1
end

trap("SIGINT") do
  puts ''
  puts '捕捉到 ' + 'CTL+C'.colorize(:red) + ' 退出操作!'
  exit 1
end

git_status = `git status -s`.strip
if git_status.empty?
  puts "本地代码没有调整，退出 GAP 操作！"
  exit 1
end

puts `git status`
puts '本地代码如上调整, 是否操作(y/n)?'.colorize(:yellow)

yes_or_not = STDIN.gets
yes_or_not.strip!
if yes_or_not != "y"
  puts '退出操作'
  exit 1
end

type, moduler, *message = ARGV
steps = [
  {label: '查看当前代码状态',  command: 'git status -s'},
  {label: '添加当前修改的文件', command: 'git add .'},
  {label: 'commit 当前修改', command: "git commit -m \"#{type}@#{version}(#{moduler}): #{message.join(' ')}\""},
  {label: '调整配置，允许 pull 时无需进入编辑模式', command: 'git config --global core.mergeoptions --no-edit'},
  {label: '从服务器 pull 代码', command: 'git pull origin $(git symbolic-ref --short -q HEAD)'},
  {label: '查看当前代码状态',  command: 'git status -s'},
  {label: '提交当前 commit 至服务器', command: 'git push origin $(git symbolic-ref --short -q HEAD)'}
]

File.open('version', 'w:utf-8') { |file| file.puts("#{obj['major']}.#{obj['minor']}.#{obj['tiny']}/#{obj['commit']}") }
File.open('version.json', 'w:utf-8') { |file| file.puts(JSON.pretty_generate(obj)) }
steps.each do |step|
  run_command(step[:label], step[:command])
end

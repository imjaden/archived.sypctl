namespace :message_center do
  task :deliver => :environment do
    MessageCenter.where(send_state: false).order(notify_level: :desc).map(&:deliver)
  end

  # select distinct su.user_name, su.mobile
  # from sys_action_logs as sal
  # inner join sys_users as su on su.id = sal.user_id
  # where sal.browser like '%Mac%'

  # select *
  # from sys_action_logs
  # where browser not like '%Mac%' and browser not like '%Android%'
  task :send_sms => :environment do
    content = "【永辉生意人】各位，由于 iOS 应用证书管理不当，若苹果手机上的生意人应用点击闪退，请卸载后再重新安装，真的非常抱歉[抱拳]。苹果手机 安装链接：https://www.pgyer.com/yh-i"
    list = IO.readlines("tmp/mobile.list")
    # find_all { |line| %w(李俊杰).any? { |n| line.include?(n) } }
    list.each do |line|
      name, mobile = line.split(',').map(&:strip)
      response = SMS.send([mobile], content);
      output = "#{name}, #{response}"
      puts output
      `echo "#{output}" >> tmp/send_sms.output`
      sleep(0.2)
    end
  end

end

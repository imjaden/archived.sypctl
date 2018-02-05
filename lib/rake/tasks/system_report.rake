namespace :system_report do
  task :log_analyse => :environment do
    reports = [
      { kpi_id: 1000, kpi_name: '日志报表', kpi_group: '系统报表', link: 1000, group_order: 1000, item_order: 1 }
    ]
  end

  def generate_system_report(options)
    # step1: kpi
    options = { kpi_id: 1000, kpi_name: '日志报表', kpi_group: '系统报表', link: 1000, group_order: 1000, item_order: 1 }
    KpiBase.create(options) unless KpiBase.find_by(kpi_id: options[:kpi_id])
    # step2: kpi data
    # step3: report
    # step4: report data
    # step4: role resource
  end
end

if(document.getElementById('cpanelVueApp')) {
  new Vue({
    el: '#cpanelVueApp',
    data: function() {
      return { 
        screenHeight: document.documentElement.clientHeight - 100,
        menus: [
          {label: '本机信息', id: 'register'},
          {label: '服务状态', id: 'service'},
          {label: '文档备份', id: 'file_backup'},
          {label: 'MySQL备份', id: 'mysql_backup'},
          {label: '安装包状态', id: 'packages'},
          {label: 'ETL邮件配置', id: 'sypetl_sendmail'}
        ],
        menu: {},
        registerData: {},
        serviceData: {},
        fileBackups: {},
        mysqlBackups: {},
        packagesData: {},
        etlSendmail: {},
        modal: {
          title: '标题',
          body: '加载中...',
          textareaReadonly: true
        },
        fileBackup: {}
      }
    },
    created() {
      let menuIndex = 0,
          menuId = window.localStorage.getItem('cpanel.menu.id') || 'null';
      if(this.menus.findIndex) { menuIndex = this.menus.findIndex(function(menu) { return menu.id == menuId; }) }
      if(menuIndex < 0 || menuIndex >= this.menus.length) { menuIndex = 0 }
      this.getData(this.menus[menuIndex])
    },
    watch: {
      'menu.id': {
        handler(now, old) {
        },
        immediate: true
      }
    },
    methods: {
      clickSideMenu(menu) {
        switch(menu.id) {
          case 'register':
            if(JSON.stringify(this.registerData) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'service':
            if(JSON.stringify(this.serviceData) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'file_backup':
            if(JSON.stringify(this.fileBackups) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'mysql_backup':
            if(JSON.stringify(this.mysqlBackups) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'packages':
            if(JSON.stringify(this.packagesData) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'sypetl_sendmail':
            if(JSON.stringify(this.etlSendmail) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
        }
        window.localStorage.setItem('cpanel.menu.id', menu.id)
      },
      getData(menu) {
        let that = this;
        if(!menu || !menu.id) { return false; }
        $.ajax({
          type: 'get',
          url: `/sypctl/cpanel/data/${menu.id}`,
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          if(res.code !== 200) {
            alert(res.message)
            return false
          }

          switch(menu.id) {
            case 'register':
              let keys = ['uuid', 'human_name', 'hostname', 'username', 'password', 'os_type', 'os_version', 'api_token', 'memory', 'cpu', 'disk', 'lan_ip', 'wan_ip', 'request_agent', 'synced', 'created_at', 'updated_at'],
                  tableRows = {
                    heads: ['键名', '键值'],
                    widths: ['20%', '80%'], rows: [], 
                    timestamp: res.data.data.updated_at,
                    rows: keys.map(function(key) { return [key, res.data.data[key]]; })
                  };
              
              that.registerData = tableRows
            break;
            case 'service':
              let output = res.data.data.output;
              that.serviceData = {
                table: {
                  heads: output.heads,
                  rows: output.data,
                  widths: ['30%', '20%', '10%', '10%', '30%'],
                  timestamp: output.timestamp
                },
                config: res.data.data.service
              }
            break;
            case 'file_backup':
              that.fileBackups = res.data.data
            break;
            case 'mysql_backup':
              that.mysqlBackups = res.data.data
            break;
            case 'packages':
              that.packagesData = res.data.data
            break;
            case 'sypetl_sendmail':
              that.etlSendmail = res.data.data
            break;
            default: 
              console.log("未知 menu: " + JSON.stringify(menu))
          }
          that.menu = menu
        }).fail(function(xhr, status, error) {
        }).always(function(res, status, xhr) {
        });
      },
      displayModal() {
        $("#infoModal").modal('show')
        if(this.menu.id == 'service') {
          this.modal.title = '服务配置'
          this.modal.body = JSON.stringify(this.serviceData.config, null, 4)
        }

        switch(this.menu.id) {
          case 'service':
            this.modal.title = '服务配置'
            this.modal.body = JSON.stringify(this.serviceData.config, null, 4)
          break;
          case 'file_backup':
            this.modal.title = '文档备份'
            this.modal.body = JSON.stringify(this.fileBackups.config, null, 4)
          break;
          case 'mysql_backup':
            this.modal.title = '文档备份'
            this.modal.body = JSON.stringify(this.mysqlBackups.config, null, 4)
          break;
          case 'sypetl_sendmail':
            this.modal.title = 'ETL邮件配置'
            this.modal.body = JSON.stringify(this.etlSendmail.config, null, 4)
          break;
        }
      },
      btnEditClick() {
        this.modal.textareaReadonly = false
      },
      postSaveConfig(menu, config) {
        let that = this;
        if(!menu || !menu.id) { return false; }
        $.ajax({
          type: 'post',
          url: `/sypctl/cpanel/data/${menu.id}`,
          data: JSON.stringify({ config: config }),
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
        }).fail(function(xhr, status, error) {
        }).always(function(res, status, xhr) {
        });
      },
      btnSaveClick() {
        try {
          JSON.parse(this.modal.body)
          this.postSaveConfig(this.menu, this.modal.body)
          this.modal.textareaReadonly = true
          this.getData(this.menu)
          alert("保存成功")
        } catch(e) {
          alert("请检测JSON格式正确！")
        }
      },
      getBackupFile(type, file) {
        let that = this,
            url = `/sypctl/cpanel/file_backup/${type}?snapshot_filename=${file.snapshot_filename}`;

        if(type == 'download') {
          window.open(url, 'blank')
          return false
        }
        window.Loading.show("获取数据中...");
        $.ajax({
          type: 'get',
          url: url,
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          console.log(res)
          that.modal.title = file.file_path
          that.modal.body = res.code == 200 ? res.data : res.message
          $("#infoModal").modal('show')
        }).fail(function(xhr, status, error) {
        }).always(function(res, status, xhr) {
          window.Loading.hide();
        });
      },
      getBackupFileTree(item) {
        this.modal.title = item.backup_path
        this.modal.body = item.file_tree
        $("#infoModal").modal('show')
      },
      getBackupFileList(item) {
        item.file_list_array = Object.keys(item.file_list).map((file_path) => {
          let file = item.file_list[file_path]
          file['file_path'] = file_path
          file['snapshot_filename'] = file.pmd5 + "-" + file.mtime + "-" + file_path.split('/').pop()
          return file
        })
        
        this.fileBackup = item
        $(".file-list").removeClass("hidden")
        $(".file-backups").addClass("hidden")
      },
      backFileBackups() {
        $(".file-list").addClass("hidden")
        $(".file-backups").removeClass("hidden")
      },
      formatDate(timestamp) {
        if(!timestamp || String(timestamp).length != 10) { return '-' }
        let date = new Date(parseInt(timestamp) * 1000)
        return date.format('yy/MM/dd hh:mm:ss')
      },
      logout() {
        if(!confirm('确认登出？')) { return false }
        $.ajax({
          type: 'get',
          url: '/sypctl/logout',
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          window.location.href = '/sypctl'
        })
      }
    }
  })
}
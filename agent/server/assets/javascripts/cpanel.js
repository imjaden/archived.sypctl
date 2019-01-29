if(document.getElementById('cpanelVueApp')) {
  new Vue({
    el: '#cpanelVueApp',
    data: function() {
      return { 
        screenHeight: document.documentElement.clientHeight - 100,
        menus: [
          {label: '注册信息', id: 'register'},
          {label: '监控服务', id: 'service'},
          {label: '备份配置', id: 'backup'},
          {label: '安装包状态', id: 'packages'}
        ],
        menu: {},
        registerData: {},
        serviceData: {},
        backupData: {},
        packagesData: {},
        modal: {
          title: '标题',
          body: '加载中...',
        }
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
          case 'backup':
            if(JSON.stringify(this.backupData) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
          case 'packages':
            if(JSON.stringify(this.packagesData) == "{}") { this.getData(menu) } else { this.menu = menu; }
          break;
        }
        window.localStorage.setItem('cpanel.menu.id', menu.id)
      },
      getData(menu) {
        console.log(menu)
        let that = this;
        if(!menu || !menu.id) {return false;}
        $.ajax({
          type: 'get',
          url: `/sypctl/cpanel/data/${menu.id}`,
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          console.log(res)
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
              console.log(that.serviceData)
            break;
            case 'backup':
              that.backupData = res.data
              break;
            case 'packages':
              that.packagesData = res.data.data
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
          console.log(this.serviceData.config)
        }
      }
    }
  })
}
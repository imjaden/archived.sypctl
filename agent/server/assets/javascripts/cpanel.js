if(document.getElementById('cpanelVueApp')) {
  new Vue({
    el: '#cpanelVueApp',
    data: function() {
      return { 
        screenHeight: document.documentElement.clientHeight - 100,
        menus: [
          {label: '注册信息', id: 'regisiter'},
          {label: '监控服务', id: 'service'},
          {label: '服务状态', id: 'service_output'},
          {label: '备份配置', id: 'backup'},
        ],
        menu: {},
        data: {}
      }
    },
    created() {
      this.menu = this.menus[0]
    },
    watch: {
      'menu.id': {
        handler(now, old) {
          this.getData()
        },
        immediate: true
      }
    },
    methods: {
      clickSideMenu(menu) {
        this.menu = menu
      },
      getData() {
        let that = this;
        if(!that.menu || !that.menu.id) {return false;}
        $.ajax({
          type: 'get',
          url: '/sypctl/cpanel/data/' + that.menu.id,
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          console.log(res)
          if(res.code === 200) {
            if(that.menu.id == 'regisiter') {
              let keys = ['uuid', 'human_name', 'hostname', 'username', 'password', 'os_type', 'os_version', 'api_token', 'memory', 'cpu', 'disk', 'lan_ip', 'wan_ip', 'request_agent', 'synced', 'created_at', 'updated_at'],
                  table_rows = {heads: ['键名', '键值'], width: ['20%', '80%'], rows: [], timestamp: res.data.data.updated_at };
              
              table_rows.rows = keys.map(function(key) { return [key, res.data.data[key]]; });
              that.data = table_rows
              console.log(table_rows)
              console.log(that.data)
            } else if(that.menu.id == 'service_output') {
              let data = res.data.data;
              that.data = {
                heads: data.heads,
                rows: data.data,
                width: ['30%', '20%', '10%', '10%', '30%'],
                timestamp: data.timestamp
              }
            } else {
              that.data = res.data
            }
          } else {
            alert(res.message)
          }
        }).fail(function(xhr, status, error) {
        }).always(function(res, status, xhr) {
        });
      }
    }
  })
}
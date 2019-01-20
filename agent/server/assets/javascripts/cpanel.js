new Vue({
  el: '#vueApp',
  data: function() {
    return { 
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
      $.ajax({
        type: 'get',
        url: '/cpanel/data/' + that.menu.id,
        contentType: 'application/json'
      }).done(function(res, status, xhr) {
        console.log(res)
        if(res.code === 200) {
          that.data = res.data
        } else {
          alert(res.message)
        }
      }).fail(function(xhr, status, error) {
      }).always(function(res, status, xhr) {
      });
    }
  }
})
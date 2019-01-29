if(document.getElementById('indexVueApp')) {
  new Vue({
    el: '#indexVueApp',
    data: function() {
      return { 
        screenHeight: document.documentElement.clientHeight - 100,
        records: [],
        record: {},
        user: {
          username: '',
          password: '',
          message: ''
        }
      }
    },
    created() {
      this.getRecords()
      console.log('screenHeight:', this.screenHeight)
    },
    methods: {
      clickSideMenu(record) {
        console.log(record)
        this.record = record
      },
      checkForm(el) {
        if(!this.user.username.length) {
          this.user.message = "请输入登录账号"
        } else if(!this.user.password.length) {
          this.user.message = "请输入登录密码"
        } else {
          let that = this;
          $.ajax({
            type: 'post',
            url: '/sypctl/login',  
            contentType: 'application/json',
            dataType: 'json',
            processData: false,
            data: JSON.stringify({username: that.user.username, password: that.user.password})
          }).done(function(res, status, xhr) {
            $(".text-danger").html(res.message)
            if(res.code === 201 && res.message == '登录成功') {
              window.location.href = '/sypctl/cpanel'
            }
          }).fail(function(xhr, status, error) {
          }).always(function(res, status, xhr) {
          });
        }
        el.preventDefault();
      },
      getRecords() {
        let that = this;
        $.ajax({
          type: 'get',
          url: '/sypctl/data',
          contentType: 'application/json'
        }).done(function(res, status, xhr) {
          console.log(res)
          if(res.code === 200) {
            that.$nextTick(function() {
              that.records = res.data
              if(that.records.length) { that.record = that.records[0] }
            })
          } else {
            alert(res.message)
          }
        }).fail(function(xhr, status, error) {
        }).always(function(res, status, xhr) {
        });
      },
      displayInfoModal(record) {
        let items = [], cols = [];

        $("#slideInfo .modal-title").html(record.title);
        items.push("<div style='white-space: pre;word-break: normal;'>" + record.description + "</div>");
        items.push("<br>隐藏/显示表格列：<br>");

        record.headings.forEach(function(head) {
          var state = $(this).hasClass("hidden") ? "" : "checked"
          cols.push("<input type=checkbox " + state + " data-class=" + $(this).data("class") + ">" + head);
        })
        $("#slideInfo .modal-body").html(items.join("") + cols.join("&nbsp;&nbsp;"))
        $("#slideInfo .mtime").html(record.mtime)

        $("#slideInfo").modal("show");
        $("input[type=checkbox]").change(function() {
          var $klass = $("." + $(this).data("class"));
          if(this.checked) {
            $klass.removeClass("hidden");
          } else {
            $klass.addClass("hidden");
          }
        });
      }
    }
  })
}
Date.prototype.format = function(format) {
  var date = {
    "M+": this.getMonth() + 1,
    "d+": this.getDate(),
    "h+": this.getHours(),
    "m+": this.getMinutes(),
    "s+": this.getSeconds(),
    "q+": Math.floor((this.getMonth() + 3) / 3),
    "S+": this.getMilliseconds()
  };
  if (/(y+)/i.test(format)) {
    format = format.replace(RegExp.$1, (this.getFullYear() + '').substr(4 - RegExp.$1.length));
  }
  for (var k in date) {
    if (new RegExp("(" + k + ")").test(format)) {
      format = format.replace(RegExp.$1, RegExp.$1.length == 1 ? date[k] : ("00" + date[k]).substr(("" + date[k]).length));
    }
  }
  return format;
}

window.App = {
  addNotify: function(message, type) {
    let html = '<div class="alert alert-' + type + ' alert-dismissible" role="alert">' +
      '<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>' + 
      message +
      '<br><small>' + new Date().toISOString().replace('T', ' ').split('.')[0] + '</small>' +
    '</div>';

    $(".system-notify").prepend(html)
  },
  addSuccessNotify: function(message) {
    window.App.addNotify(message, 'success')
  },
  addWarningNotify: function(message) {
    window.App.addNotify(message, 'warning')
  }, 
  addInfoNotify: function(message) {
    window.App.addNotify(message, 'info')
  }, 
  addDangerNotify: function(message) {
    window.App.addNotify(message, 'danger')
  }, 
  showLoading: function() {
    return $(".loading").removeClass("hidden");
  },
  showLoading: function(text) {
    $(".loading").html(text);
    return $(".loading").removeClass("hidden");
  },
  hideLoading: function() {
    $(".loading").addClass("hidden");
    return $(".loading").html("loading...");
  },
  params: function(type) {
    var i, key, keys, obj, pair, pairs, value, values;
    obj = {};
    keys = [];
    values = [];
    pairs = window.location.search.substring(1).split("&");
    for (i in pairs) {
      if (pairs[i] === "") {
        continue;
      }
      pair = pairs[i].split("=");
      key = decodeURIComponent(pair[0]);
      value = decodeURIComponent(pair[1]);
      keys.push(key);
      values.push(value);
      obj[key] = value;
    }
    if (type === "key") {
      return keys;
    } else if (type === "value") {
      return values;
    } else {
      return obj;
    }
  },
  removeGlyphicon: function() {
    $(".dropdown-menu i.glyphicon").remove();
    return $(".dropdown-menu a").each(function() {
      return $(this).text($.trim($(this).text()));
    });
  },
  checkboxState: function(self) {
    var state;
    state = $(self).attr("checked");
    if (state === void 0 || state === "undefined") {
      return false;
    } else {
      return true;
    }
  },
  checkboxChecked: function(self) {
    return $(self).attr("checked", "true");
  },
  checkboxUnChecked: function(self) {
    return $(self).removeAttr("checked");
  },
  checkboxState1: function(self) {
    var state;
    state = $(self).attr("checked");
    if (state === void 0 || state === "undefined") {
      $(self).attr("checked", "true");
      return true;
    } else {
      $(self).removeAttr("checked");
      return false;
    }
  },
  reloadWindow: function() {
    return window.location.reload();
  },
  activeMenu: function() {
    var klass, pathname, parts;
    pathname = window.location.pathname;
    parts = pathname.split("/");

    $(".navbar-nav li").removeClass("active");
    $(".navbar-nav .menu-" + parts[1]).addClass("active");
    $(".navbar-nav a").filter(function(inx) {
      if(pathname === ($(this).attr("href") || "").split("?")[0]) { 
        $(this).closest("li").addClass("active");
        
        /*
         * 记录菜单使用频率至浏览器缓存, 提供最近访问菜单功能
         * 以此改善用户使用体验
         */
        try {
          let ue = window.localStorage.getItem('_ue_visit_menu'),
              ueObj = {},
              tmp;
          if(ue) { ueObj = JSON.parse(ue) }

          if(!ueObj[pathname]) { 
            ueObj[pathname] = {
              weight: 0,
              path: pathname
            }
          }
          ueObj[pathname]['title'] = $(this).text().replace(/\n|\s/g, '')
          ueObj[pathname]['weight'] = ueObj[pathname]['weight'] + 1
          ueObj[pathname]['timestamp'] = new Date().valueOf()
          window.localStorage.setItem('_ue_visit_menu', JSON.stringify(ueObj))
        } catch(e) {
          console.log(e)
        }
      }
    })
  },
  resizeWindow: function() {
    var d, e, footer_height, g, main_height, nav_height, w, x, y;
    w = window;
    d = document;
    e = d.documentElement;
    g = d.getElementsByTagName("body")[0];
    x = w.innerWidth || e.clientWidth || g.clientWidth;
    y = w.innerHeight || e.clientHeight;
    nav_height = 80 || $("nav:first").height();
    footer_height = 100 || $("footer:first").height();
    main_height = y - nav_height - footer_height;
    if (main_height > 300) {
      return $("#main").css({
        "min-height": main_height + "px"
      });
    }
  },
  initBootstrapNavbarLi: function() {
    var navbar_lis = $(".navbar-nav:first li, .navbar-right li:lt(" + navbar_right_lis + ")"),
      navbar_right_lis = $("#navbar_right_lis").val() || 1
      path_name = window.location.pathname,
      navbar_match_index = -1,
      navbar_hrefs = navbar_lis.map(function() { return $(this).children("a:first").attr("href"); }),
      paths = path_name.split('/');

    while(paths.length > 0 && navbar_match_index === -1) {
      var temp_path = paths.join('/');
      for(var i = 0, len = navbar_hrefs.length; i < len; i++) {
        if(navbar_hrefs[i] === temp_path) {
          navbar_match_index = i;
          break;
        }
      }
      paths.pop();
    }
    navbar_lis.each(function(index) {
      navbar_match_index === index ? $(this).addClass("active") : $(this).removeClass("active");
    });
  },
  initBootstrapPopover: function() {
    return $("body").popover({
      selector: "[data-toggle=popover]",
      container: "body"
    });
  },
  initBootstrapTooltip: function() {
    return $("body").tooltip({
      selector: "[data-toggle=tooltip]",
      container: "body"
    });
  },
  breadcrumbSearch: function(ctl) {
    var keywords = (ctl.tagName === 'INPUT' ? $(ctl) : $(ctl).siblings(".breadcrumb-search-input:first")).val();
    var params = window.Param.parse();
    keywords = $.trim(keywords);
    if(keywords.length) {
      params["page"] = 1;
      params["keywords"] = keywords;
    } else {
      if(params.keywords) { delete params.keywords }
    }
    window.Param.redirectTo(params);
  },
  recordLoginOrLogout: function() {
    var params = window.App.params("object");
    if(params.login_authen_to_redirect || params.logout_authen_to_redirect) {
      if(!params.user_num) return;

      try {
        var objects = {user: { id: params.user_num, name: params.user_name, type: "user" }},
            scene = params.login_authen_to_redirect ? "user.login" : "user.logout";
            window.action_logger = {operator: objects.user};
        window.OperationLogger.record(scene, objects);
      } catch(e) { console.log(e) }

      delete params.login_authen_to_redirect;
      delete params.logout_authen_to_redirect;
      delete params.user_num;
      delete params.user_name;
      delete params.bsession;
      window.Param.redirectTo(params);
    }
  },
  toggleDisplayVisitMenus: function() {
    if($('.visit-menus').hasClass('hidden')) {
      let ue = window.localStorage.getItem('_ue_visit_menu'),
          ueObj = {},
          menus = [],
          lis, ul;
      if(ue) { ueObj = JSON.parse(ue) }
      menus = Object.values(ueObj).sort((a, b) => { return b.timestamp - a.timestamp; })
      lis = menus.map((menu) => {
        let title = menu.title
        if(!title || !title.length) {
          title = '未获取到标题'
        }
        return '' + 
          '<li class="list-group-item">' + 
            '<span class="badge">' + menu.weight + '</span>' + 
             '<a href="' + menu.path + '">' + title + '</a>' +
          '</li>';
      })
      // lis.unshift(
      //   '<li class="list-group-item active">' + 
      //      '最近访问:' +
      //   '</li>'
      // )
      ul = '<li class="list-group-item active">' + 
               '最近访问:' +
            '</li>' +
            '<ul class="list-group">' + lis.join('') + '</ul>'
      $('.visit-menus').html(ul);

      $('.visit-menus').removeClass('hidden')
      $('.system-notify').addClass('hidden')
    } else {
      $('.visit-menus').addClass('hidden')
      $('.system-notify').removeClass('hidden')
    }
  },
  lazyLoadImg: function() {
    $("img.img-lazy-load").each(function() { $(this).attr('src', null) })
    // 图片懒加载
    $("img.img-lazy-load").lazyload({ 
    　　effect : "fadeIn", 
    　　threshold : 180,
    　　event: 'scroll',
    　　container: $("#container"),
    　　failure_limit: 2 
    });
  }
};

window.Param = {
  params: {},
  parse: function() {
    var params = {},
        search = window.location.search.substring(1),
        parts = search.split('&'),
        pairs = [];

    for(var i = 0, len = parts.length; i < len; i++) {
      pairs = parts[i].split('=');
      params[pairs[0]] = (pairs.length > 1 ? pairs[1] : null);
    }
    window.Param.params = params;

    return params;
  },
  toString: function(paramsHash) {
    var pairs = [];
    paramsHash['_t'] = (new Date().valueOf())
    for(var key in paramsHash) {
      pairs.push(key + "=" + paramsHash[key]);
    }
    var href = window.location.href.split("?")[0] + "?" + pairs.join("&");
    return href;
  },

  redirectTo: function(paramsHash) {
    let url = window.Param.toString(paramsHash);
    if(window.history.pushState) {
      window.history.pushState(null, null, url);
    } else {
      window.location.href = url
    }
  }
}

window.Loading = {
  setState: function(state) {
    if(state === 'show') {
      $(".loading").removeClass("hidden");
    } else {
      setTimeout("$('.loading').addClass('hidden');", 1000);
    }
  },
  show: function(text) {
    window.Loading.makeSureLoadingExist();

    $(".loading").html(text);
    window.Loading.makeSureCenterHorizontal();
    window.Loading.setState('show');
  },
  hide: function() {
    window.Loading.setState('hide');
  },
  makeSureLoadingExist: function(type) {
    if($(".loading").length === 0) {
      $("body").append('<div class="loading hidden">loading...</div>');
    }
  },
  popup: function(text) {
    window.Loading.makeSureLoadingExist();

    $(".loading").html(text);
    window.Loading.makeSureCenterHorizontal();
    window.Loading.setState('show');
    $(".loading").slideDown(1000, function() {
      $(this).slideUp(1500);
    })
  },
  makeSureCenterHorizontal: function() {
    var w = window,
        d = document,
        e = d.documentElement,
        g = d.getElementsByTagName('body')[0],
        x = $(".container").width() || w.innerWidth || e.clientWidth || g.clientWidth,
        y = w.innerHeight|| e.clientHeight || g.clientHeight,
        loading_width = $(".loading").width(),
        left_width = (x - loading_width - 50)/2;

    // console.log({"x": x, "w": loading_width, "left": left_width, "margin-left": '0px'});
    $(".loading").css({"left": left_width, "margin-left": '0px'});
  }
}

window.Image = {
  onerror: function(img) {
    let src = $(img).attr('src'),
        src404 = '/images/404-small.png';
    console.group('图片加载异常')
    console.log('当前图片链接:', src)
    console.log('备份链接属性:', 'data-errorurl')
    console.log('加载默认图片:', src404)
    console.groupEnd()
    $(img).attr('src', src404).attr('data-errorurl', src)
  }
}

window.TabMenu = {
  stringToHash: function(string) {
    let i, pair, pairs, hash = {};
    pairs = string.split("@@");
    for (i in pairs) {
      pair = pairs[i].split(":");
      if (pair.length != 2) { continue; }
      hash[pair[0]] = pair[1]
    }
    return hash
  },
  hashToString: function(hash) {
    let result;
    result = Object.keys(hash).reduce(function(array, key) {
      array.push(key + ':' + hash[key])
      return array;
    }, [])
    return result.join('@@')
  },
}

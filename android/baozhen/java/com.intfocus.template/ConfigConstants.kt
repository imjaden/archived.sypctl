package com.intfocus.template

/**
 * ****************************************************
 * @author JamesWong
 * @createdOn 17/11/04 上午09:52
 * @email PassionateWsj@outlook.com
 * @name 生意+ 配置类
 * @desc * 表示的是默认的配置
 *          仅列出了部分 功能&界面展示 的开关，资源替换等需要额外配置（参考文档 ****）
 * ****************************************************
 */
object ConfigConstants {

    const val kAppCode = "baozhen"

    /**
     * 登录前进行Saas验证
     *
     * true : 开启
     * false : 关闭 *
     */
    const val SAAS_VERIFY_BEFORE_LOGIN: Boolean = false
    /**
     * 启动页更新资源开关
     *
     * true : 启动页有资源更新 *
     * false : 启动页无资源更新，启动后停留 2s 进入下一页面
     */
    const val UP_DATE_ASSETS: Boolean = true
    /**
     * 启动页底部广告条
     *
     * true : 显示
     * false : 不显示
     */
    const val SPLASH_ADV: Boolean = false
    /**
     * 第一次登录是否展示 使用 Guide 说明页面
     *
     * true : 展示 *
     * false : 不展示
     */
    const val GUIDE_SHOW: Boolean = false
    /**
     * 是否显示登陆页底部 忘记密码 | 申请注册
     *
     * true : 显示 *
     * false : 不显示
     */
    const val UNABLE_LOGIN_SHOW: Boolean = true
    /**
     * 在报表页面结束应用，再次登录时是否自动跳转上次报表页面
     *
     * true : 跳转
     * false : 不跳转 *
     */
    const val REVIEW_LAST_PAGE: Boolean = false
    /**
     * 是否保存上次退出时停留的主页签
     *
     * true : 跳转
     * false : 每次登录默认显示第一个页签 *
     */
    const val LOAD_LAST_FRAGMENT_WHEN_LAUNCH: Boolean = false
    /**
     * 是否提供扫码功能 (Kpi 概况页签)
     *
     * true : 提供 *
     * false : 不提供
     */
    const val SCAN_ENABLE_KPI: Boolean = false
    /**
     * 是否提供扫码功能 (Report 报表页签)
     *
     * true : 提供 *
     * false : 不提供
     */
    const val SCAN_ENABLE_REPORT: Boolean = false
    /**
     * 是否提供扫码功能 (WorkBox 工具箱页签)
     *
     * true : 提供
     * false : 不提供 *
     */
    const val SCAN_ENABLE_WORKBOX: Boolean = false
    /**
     * 扫一扫 条码/二维码 开关
     *
     * true : 不支持二维码 *
     * false : 支持二维码
     */
    const val SCAN_BARCODE: Boolean = true
    /**
     * 是否支持 相册扫码 功能
     *
     * true : 支持 *
     * false : 不支持
     */
    const val SCAN_BY_PHOTO_ALBUM: Boolean = true
    /**
     * 是否支持 扫码定位显示
     *
     * true : 支持 *
     * false : 不支持
     */
    const val SCAN_LOCATION: Boolean = true
    /**
     * 帐号输入是否只支持数字键盘
     *
     * true : 数字输入键盘 *
     * false : 文本键盘
     */
    const val ACCOUNT_INPUTTYPE_NUMBER: Boolean = false
    /**
     * 主页面显示 Kpi 概况页签
     *
     * true : 显示 *
     * false : 不显示
     */
    const val KPI_SHOW: Boolean = true
    /**
     * 显示 Report 报表页签
     *
     * true : 显示 *
     * false : 不显示
     */
    const val REPORT_SHOW: Boolean = true
    /**
     * 显示 WorkBox 工具箱页签
     *
     * true : 显示 *
     * false : 不显示
     */
    const val WORKBOX_SHOW: Boolean = true
    /**
     * 我的页面是否只显示 个人信息 一个页签
     *
     * true : 1 个
     * false : 3 个 *
     */
    const val ONLY_USER_SHOW: Boolean = true
    /**
     * 我的页面是否自定义: 访问统计、文章收藏、消息、修改密码、问题反馈
     *
     * true : 用户自定义添加界面 *
     * false : 显示用户基本信息
     */
    const val USER_VISIT_STATISTIC: Boolean = false
    const val USER_FAVORITE_ARTICLE: Boolean = false
    const val USER_PUSH_MESSAGES: Boolean = false
    const val USER_MODIFY_PASSWORD: Boolean = true
    const val USER_FEEDBACK: Boolean = false

    /**
     * 归属部门是否有内容
     *
     * true : 可点击跳转
     * false : 不可点击 *
     */
    const val USER_GROUP_CONTENT: Boolean = false
    /**
     * 头像是否支持点击上传
     *
     * true : 支持 *
     * false : 不支持
     */
    const val HEAD_ICON_UPLOAD_SUPPORT: Boolean = true
    /**
     * 是否允许主页面4个页签 滑动切换
     *
     * true : 允许滑动
     * false : 不允许滑动 *
     */
    const val DASHBOARD_ENABLE_HORIZONTAL_SCROLL: Boolean = false
    /**
     * 登录过的用户，下次开启应用是否免密登录
     *
     * true : 下次启动免密登录
     * false : 每次重新启动客户端都需输入密码 *
     */
    const val LOGIN_WITH_LAST_USER: Boolean = false
    /**
     * 工具箱单行显示个数（横屏）
     */
    const val WORK_BOX_NUM_COLUMNS_LAND: Int = 6
    /**
     * 工具箱单行显示个数（竖屏）
     */
    const val WORK_BOX_NUM_COLUMNS_PORT: Int = 3
    /**
     * 报表单行显示个数（横屏）
     */
    const val REPORT_NUM_COLUMNS_LAND: Int = 5
    /**
     * 报表单行显示个数（竖屏）
     */
    const val REPORT_NUM_COLUMNS_PORT: Int = 3
    /**
     * 应用在切换到后台 1 小时后，需要重新登录
     *
     * true : 开启 *
     * false : 关闭
     */
    const val LOGOUT_WITHIN_ONE_HOUR: Boolean = false
    /**
     * 开启沉浸式效果
     *
     * true : 开启 *
     * false : 关闭
     */
    const val ENABLE_FULL_SCREEN_UI: Boolean = true
}

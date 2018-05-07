#!/usr/bin/env bash

##############################################################################
##
##  Script switch YH-IOS apps for UN*X
##
##############################################################################
#
# $ bash appkeeper.sh shengyiplus
#

check_assets() {
    local shared_path="YH-IOS/Shared/"

    if [[ -z "$1" ]];
    then
        echo "ERROR: please offer server"
        exit
    fi
    if [[ -z "$2" ]];
    then
        echo "ERROR: please offer assets filename"
        exit
    fi

    local server="$1"
    local filename="$2.zip"
    local filepath="$shared_path/$filename"
    local url="${server}/api/v1/download/${filename}"

    echo -e "\n## $filename\n"
    local status_code=$(curl -s -o /dev/null -I -w "%{http_code}" $url)

    if [[ "$status_code" != "200" ]];
    then
        echo "ERROR: $status_code - $url"
        exit
    fi
    echo "- http response 200."

    curl -s -o $filename $url
    echo "- download $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"

    local md5_server=$(md5 ./$filename | cut -d ' ' -f 4)
    local md5_local=$(md5 ./$filepath | cut -d ' ' -f 4)

    if [[ "$md5_server" = "$md5_local" ]];
    then
        echo "- not modified."
        test -f $filename && rm $filename
    else
        mv $filename $filepath
        echo "- $filename updated."
    fi
}

case "$1" in
    format)
        ruby config/format_keeper.rb
    ;;
    assets:check)
    ;;
    ruishangdev|ruishang|shengyiplus|qiyoutong|test|yonghuidev|yonghui|yonghuitest|shenzhenpoly)
        current_app="$1"

        # 声明对应应用的变量
        source config/${current_app}.conf.sh

        # 校正更新本地静态资源
        check_assets ${base_url} assets
        check_assets ${base_url} fonts
        check_assets ${base_url} images
        check_assets ${base_url} javascripts
        check_assets ${base_url} stylesheets
        check_assets ${base_url} loading
        check_assets ${base_url} icons

        # 切换应用图标
        rm -fr YH-IOS/Assets.xcassets/AppIcon.appiconset && cp -rf config/Assets.xcassets/${current_app}/AppIcon.appiconset YH-IOS/Assets.xcassets/
        rm -fr YH-IOS/Assets.xcassets/AppIcon-1.appiconset && cp -rf config/Assets.xcassets/${current_app}/AppIcon.appiconset YH-IOS/Assets.xcassets/AppIcon-1.appiconset
        rm -fr YH-IOS/Assets.xcassets/Banner-Logo.imageset && cp -rf config/Assets.xcassets/${current_app}/Banner-Logo.imageset YH-IOS/Assets.xcassets/
        rm -fr YH-IOS/Assets.xcassets/Banner-Setting.imageset && cp -rf config/Assets.xcassets/${current_app}/Banner-Setting.imageset YH-IOS/Assets.xcassets/
        rm -fr YH-IOS/Assets.xcassets/background.imageset && cp -rf config/Assets.xcassets/${current_app}/background.imageset YH-IOS/Assets.xcassets/
        rm -fr YH-IOS/Assets.xcassets/Login-Logo.imageset && cp -rf config/Assets.xcassets/${current_app}/Login-Logo.imageset YH-IOS/Assets.xcassets/
        rm -fr YH-IOS/Assets.xcassets/logo.imageset && cp -rf config/Assets.xcassets/${current_app}/logo.imageset YH-IOS/Assets.xcassets/
        
        # 切换应用私变量
        header_file=YH-IOS/Macros/PrivateConstants.h
        cp config/PrivateConstants.conf $header_file

        sed -i '' s#SAAS_MODE#$saas_mode#g $header_file
        sed -i '' s#SAAS_API_URL#$saas_api_url#g $header_file

        sed -i '' s#LOGIN_BLACK_BACKGROUND_MODE#$login_black_background#g $header_file
        
        sed -i '' s#BASE_URL#$base_url#g $header_file
        sed -i '' s#APP_CODE#$app_code#g $header_file
        sed -i '' s#SLOGAN#$slogan#g $header_file
        sed -i '' s#INIT_PASSWORD#$init_password#g $header_file
        sed -i '' s#APPLICATION_ID#$application_id#g $header_file
        sed -i '' s#APITOKEN#$api_token#g $header_file

        sed -i '' s#FORGET_PWD_OR_REGISTER_AREA#$foreget_pwd_or_register_area#g $header_file

        sed -i '' s#DASHBOARD_ADD#$dashboard_add#g $header_file
        sed -i '' s#DROPMENU_SCAN#$dropmenu_scan#g $header_file
        sed -i '' s#DROPMENU_VOICE#$dropmenu_voice#g $header_file
        sed -i '' s#DROPMENU_SEARCH#$dropmenu_search#g $header_file
        sed -i '' s#DROPMENU_USERINFO#$dropmenu_userinfo#g $header_file

        sed -i '' s#TABBAR_KPI#$tabbar_kpi#g $header_file
        sed -i '' s#TABBAR_ANALYSE#$tabbar_analyse#g $header_file
        sed -i '' s#TABBAR_APP#$tabbar_app#g $header_file
        sed -i '' s#TABBAR_MESSAGE#$tabbar_message#g $header_file

        sed -i '' s#SUBJECT_COMMENT#$subject_comment#g $header_file
        sed -i '' s#SUBJECT_SHARE#$subject_share#g $header_file

        sed -i '' s#BUGLY_ID#$bugly_id#g $header_file
        sed -i '' s#AMAP_KEY#$amap_key#g $header_file
        sed -i '' s#UMENG_APP_ID#$umeng_app_id#g $header_file
        sed -i '' s#WEIXIN_APP_ID#$weixin_app_id#g $header_file
        sed -i '' s#WEIXIN_APP_SECRET#$weixin_app_secret#g $header_file
        sed -i '' s#HOT_FIX#$hot_fix#g $header_file
        sed -i '' s#PGYER_APP_KEY#$pgyer_app_key#g $header_file
        sed -i '' s#PGYER_API_KEY#$pgyer_api_key#g $header_file
        sed -i '' s#PGYER_USER_KEY#$pgyer_user_key#g $header_file
        sed -i '' s#PGYER_INSTALL_URL#$pgyer_install_url#g $header_file

        sed -i '' s#MINE_DEPARTMENT_CLICKABLE#$mine_department_clickable#g $header_file
        sed -i '' s#MINE_HEADER#$mine_header#g $header_file
        sed -i '' s#MINE_STATISTIC#$mine_statistic#g $header_file
        sed -i '' s#MINE_DEPARTMENT#$mine_department#g $header_file
        sed -i '' s#MINE_STAFF_NUMBER#$mine_staff_number#g $header_file
        sed -i '' s#MINE_FAVORITE#$mine_favorite#g $header_file
        sed -i '' s#MINE_MESSAGE#$mine_message#g $header_file
        sed -i '' s#MINE_SETTING#$mine_setting#g $header_file
        sed -i '' s#MINE_UPDATE_PWD#$mine_update_pwd#g $header_file
        sed -i '' s#MINE_FEEDBACK#$mine_feedback#g $header_file
    ;;
    pgyer)
        bundle exec ruby config/app_keeper.rb --app="$(cat .current-app)" --pgyer
    ;;
    view)
      bundle exec ruby config/app_keeper.rb --view
    ;;
    del:entitle)
        project=YH-IOS.xcodeproj/project.pbxproj
        sed -i '.bak' /CODE_SIGN_ENTITLEMENTS/d YH-IOS.xcodeproj/project.pbxproj
        diff ${project} ${project}.bak
        mv ${project}.bak build/
    ;;
    git:push)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git push origin ${git_current_branch}
    ;;
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    *)
        test -z "$1" && echo "current app: $(cat .current-app)" || echo "unknown argument - $1"
    ;;
esac

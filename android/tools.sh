#!/usr/bin/env bash

##############################################################################
##
##  Script switch SYP-Android apps for UN*X
##
##############################################################################

check_assets() {
    local shared_path="app/src/main/assets"

    if [[ -z "$1" ]];
    then
        echo "ERROR: please offer assets filename"
        exit
    fi

    local filename="$1.zip"
    local configpath="config/Assets/zip-$filedirname"
    local projectfilepath="$shared_path/$1.zip"
    local url="${downloadurl}/api/v1/download/$1.zip"

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

    if [[ ! -d "$configpath" ]]; 
    then
      mkdir "$configpath"
    fi

    cp -R $filename "$configpath/$filename"
    test -f $filename && rm $filename

    local md5_server=$(md5 ./"$configpath/$filename" | cut -d ' ' -f 4)
    local md5_local=$(md5 ./$projectfilepath | cut -d ' ' -f 4)

    if [[ "$md5_server" = "$md5_local" ]];
    then
        echo "- not modified."
    else
        cp -R "$configpath/$filename" "$shared_path"
        echo "- $filename updated."
    fi
}

download_assets() {
  check_assets "assets"
}

case "$1" in
  assemble)
      build_target="$2"
      build_type="assembleShengyiplusRelease"
      case "${build_target}" in
        template)
            build_type='assembleTemplateRelease'
        ;;
        shengyiplus)
            build_type='assembleShengyiplusRelease'
        ;;
        yh_android)
            build_type='assembleYh_androidRelease'
        ;;
        hx|ruishangplus)
            build_target='hx'
            build_type='assembleHxRelease'
        ;;
        yonghuitest)
            build_type='assembleYonghuitestRelease'
        ;;
        *)
            build_target=shengyiplus
        ;;
      esac

      bash gradlew ${build_type}
      open app/build/outputs/apk/${build_target}
  ;;
  refresh:config)
    test -d syp-scripts && {
        cd syp-scripts
        git pull origin dev-0.0.1
        cd -
    } || {
        git clone --branch dev-0.0.1 --depth 1 git@gitlab.ibi.ren:syp/syp-scripts.git
    }

    for project in $(ls syp-scripts/android/); do
      cp -rf syp-scripts/android/ app/src/

        status_format="%-20s %-30s\n"
      printf "%-20s %-10s %-30s\n" ${project} $([[ $? -eq 0 ]] && echo '成功' || echo '失败')
    done
  ;;
  shengyiplus|qiyoutong|test)
    # bundle exec ruby config/app_keeper.rb --app=shengyiplus --gradle --mipmap --manifest --res --java --apk --pgyer
    bundle exec ruby config/app_keeper.rb --app="$1" --gradle --mipmap --manifest --res --java
  ;;
  yh_android)
    downloadurl="http://yonghui.idata.mobi"
    filedirname="yh_android"
    download_assets
    bundle exec ruby config/app_keeper.rb --app="$1" --gradle --mipmap --manifest --res --java
  ;;
  yonghuitest)
    downloadurl="http://yonghui-test.idata.mobi"
    filedirname="yonghuitest"
    download_assets
    bundle exec ruby config/app_keeper.rb --app="$1" --gradle --mipmap --manifest --res --java
  ;;
  yhdev)
    downloadurl="http://yonghui-dev.idata.mobi"
    filedirname="yhdev"
    download_assets
    bundle exec ruby config/app_keeper.rb --app="$1" --gradle --mipmap --manifest --res --java
  ;;
  pgyer)
    bundle exec ruby config/app_keeper.rb --app="$(cat .current-app)" --apk --pgyer
  ;;
  github)
    bundle exec ruby config/app_keeper.rb --github
  ;;
  updata:yhtest)
    downloadurl="http://yonghui-test.idata.mobi"
    download_assets
    ;;
  updata:yh)
    downloadurl="http://yonghui.idata.mobi"
    download_assets
    ;;
  view)
    bundle exec ruby config/app_keeper.rb --view
  ;;
  deploy)
    bash "$0" shengyiplus
    bash "$0" pgyer
    bash "$0" qiyoutong
    bash "$0" pgyer
    bash "$0" yh_android
    bash "$0" pgyer
  ;;
  all)
    echo 'TODO'
  ;;
  *)
    if [[ -z "$1" ]]; then
      bundle exec ruby config/app_keeper.rb --check
    else
      echo "unknown argument - $1"
    fi
  ;;
esac
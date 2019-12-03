#!/bin/bash
#
########################################
#
#  Static File Manager
#
########################################


jenkins_project_name="SypPro-VapeLabTrackingCode"

remote_www_path="/data/work/www/frontend-apps/"
remote_ssh_user="sy-devops-user"
remote_ssh_port="22"

ssh sy-devops-user@api.idata.mobi "mkdir -p ${remote_www_path}/vapelab-tracking-code"
scp -p -r * sy-devops-user@api.idata.mobi:${remote_www_path}/vapelab-tracking-code
ssh sy-devops-user@api.idata.mobi "tree ${remote_www_path}/vapelab-tracking-code"

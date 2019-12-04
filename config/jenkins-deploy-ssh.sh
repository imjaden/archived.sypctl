#!/bin/bash
#
########################################
#
#  SSH Remote Manager
#
########################################

echo "## api.idata.mobi"
echo ""
ssh sy-devops-user@api.idata.mobi "bash /data/work/www/syp-webassets/tool.sh guard"
ssh sy-devops-user@api.idata.mobi "cd /data/work/www/syp-webassets/ && git --no-pager log --pretty=oneline -10"
echo ""
echo ""
echo "## api-dev.idata.mobi"
echo ""
ssh sy-devops-user@api-dev.idata.mobi "bash /data/work/www/syp-webassets/tool.sh guard"
ssh sy-devops-user@api-dev.idata.mobi "cd /data/work/www/syp-webassets/ && git --no-pager log --pretty=oneline -10"

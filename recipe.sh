#!/bin/bash
set -e

MYEOF=E_O_F

# Add '/' at the end of path string
pathfix()
{
    if [ ! "/" = "${1:0-1}" ]; then
        echo "${1}/"
    else
        echo "$1"
    fi
}

##################
# Get Env values #
##################
# path of where i am
BASEPATH=$(cd `dirname $0`; pwd)
BASEPATH=`pathfix $BASEPATH`

# cfg file path
CFGFILE="${BASEPATH}recipe.conf"

# configs from cfg file
if [ ! -f $CFGFILE ]; then
    echo "Config file dose NOT exist!" >&2
    echo "Please create it with the name: recipe.conf" >&2
    exit -1
fi

# read all cfgs from cfg file
while read MYLINE; do
    if [ "#" = "${MYLINE:0:1}" ]; then
        continue
    fi
    if [ 0 -eq ${#MYLINE} ]; then
        continue
    fi
    eval ${MYLINE%%:*}=${MYLINE#*:}
done << $MYEOF
    `cat $CFGFILE | sed s/[[:space:]]//g`
$MYEOF

while [ 0 ] ; do
    echo "THis is a hexo blog helper. Select what you want:"
    select MYSEL in \
        "Init hexo" \
        "Synchronize my blog file" \
        "Link hexo with my blog file" \
        "Start/Restart hexo server" \
        "Stop hexo server" \
        "New draft" \
        "Move to post" \
        "Move to draft" \
        "Exit" \
        "Init my blog file (DANGER!!!)" \
    ; do
        case $REPLY in
            9) : ;;
        esac
        break
    done
    if [ $REPLY -eq 9 ]; then
        break
    fi
done

#echo $BASEPATH


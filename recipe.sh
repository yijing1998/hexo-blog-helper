#!/bin/bash
set -e

##################
# Get Env values #
##################
# path of where i am
BASEPATH=$(cd `dirname $0`; pwd)
if [ ! "/" = "${BASEPATH:0-1}" ]; then
    BASEPATH="${BASEPATH}/"
fi

# cfg file path
CFGFILE="${BASEPATH}recipe.conf"

# configs from cfg file
if [ ! -f $CFGFILE ]; then
    echo "Config file dose NOT exist!" >&2
    echo "Please create it with the name: recipe.conf" >&2
    exit -1
fi

CFGARRAY=(
    "CFGHEXOBLOGPATH"
    "CFGHEXOMYSOURCE"
)
cat $CFGFILE | sed s/[[:space:]]//g | while read MYLINE; do
    if [ "#" = "${MYLINE:0:1}" ]; then
        continue
    fi
    if [ 0 -eq ${#MYLINE} ]; then
        continue
    fi
    echo ${MYLINE%:*}
    case ${MYLINE%:*} in
        CFGHEXOBLOGPATH)
            CFGHEXOBLOGPATH=${MYLINE#*:}
            ;;
        CFGHEXOMYSOURCE)
            CFGHEXOMYSOURCE=${MYLINE#*:}
            ;;
        *)
            echo "no"
            ;;
    esac
done

usage()
{
    echo "A hexo blog helper!"
}

# enviroment check
mycheck()
{
    echo "check"
}

# enviroment check and setup
myinit()
{
    echo "init"
}

# Parse options
if [ $# -eq 0 ]; then
    usage
else
    while getopts "i" MYARG; do
        case $MYARG in
            i)
                myinit
                ;;
            ?)
                usage
                ;;
        esac
    done
fi


echo "val":${CFGHEXOBLOGPATH}



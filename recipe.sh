#!/bin/bash
MYEOF=E_O_F

# Add '/' at the end of path string
pathfix()
{
    if [ ! "/" = "${1:0-1}" ]; then
        echo "${1}/"
    else
        echo "${1}"
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
    echo "Config file dose NOT exist!" 1>&2
    echo "Please create it with the name: recipe.conf" 1>&2
    exit 1
fi

# read all cfgs from cfg file
while read MYLINE; do
    if [ "#" = "${MYLINE:0:1}" ]; then
        continue
    fi
    if [ -z $MYLINE ]; then
        continue
    fi
    eval ${MYLINE%%:*}=${MYLINE#*:}
done <<$MYEOF
`cat $CFGFILE | sed s/[[:space:]]//g`
$MYEOF

# create a new draft
do_new_draft()
{
    if [ ! -d "$CFGHEXOMYSOURCE" ]; then
        echo "Error: Please creat your blog folder in up menu => 'Mysource manage'." >&2
        return
    fi

    # change dir to basepath
    cd $BASEPATH > /dev/null

    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local drpath="${mypath}_drafts/"
	local popath="${mypath}_posts/"
    local ymname=`date "+%Y%m"`

    if [ ! -d "${drpath}${ymname}" ]; then
		mkdir -p "${drpath}${ymname}"
	fi
	if [ ! -d "${popath}${ymname}" ]; then
		mkdir -p "${popath}${ymname}"
	fi

    local fn=""
	local tmpstr=`ls ${popath}${ymname} ${drpath}${ymname} 2> /dev/null | grep .*\.md | sort -r | head -1`

    if [ -z $tmpstr ]; then
		# first post of current month
		fn=`date "+%Y-%m-%d.001.md"`
    else
        tmpstr=${tmpstr: 11: 3}
        if [ "$tmpstr" = "999" ]; then
			echo "Error: Too many posts a month! 999 is the max." 1>&2
			return
		fi
        ((tmpstr=10#$tmpstr+1))
        if [ $tmpstr -lt 10 ]; then
			fn=`date "+%Y-%m-%d.00${tmpstr}.md"`
		elif [ $tmpstr -lt 100 ]; then
			fn=`date "+%Y-%m-%d.0${tmpstr}.md"`
		else
			fn=`date "+%Y-%m-%d.${tmpstr}.md"`
		fi
    fi

    # create the post
	cat > ${drpath}${ymname}/${fn} <<$MYEOF
---
title: title place for you!
date: `date "+%Y-%m-%d %H:%M:%S"`
tags:
---
$MYEOF
  echo "Info: New draft created! File Name: $fn"
  read -p "press 'Enter' TWICE to continue ..."
  # while read ... do : "read" asynchronous with "echo"
}

# check if $1 is number
# and $1 is between $2 and $3
# 0: is    1: no
numrangeok()
{
    # param check
    if [ ! $# -eq 3 ]; then
        return 1
    fi
    
    # number check
    local tmpstr=`echo $1$2$3 | grep '^[[:digit:]]*$'`
    if [ -z $tmpstr ]; then
        #echo "not a number" 1>&2
        return 1
    fi

    # range check
    if [ $1 -lt $2 ]; then
        # too small
        #echo "too small" 1>&2
        return 1
    fi
    if [ $1 -gt $3 ]; then
        # too big
        #echo "too big" 1>&2
        return 1
    fi

    return 0
}

# move filename $1 between $2 and $3
# do not check params: the caller has checked them
moveaction()
{
    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local drpath="${mypath}_drafts/"
	local popath="${mypath}_posts/"
    local ymname="${1:0:4}${1:5:2}"
    
    if [ ! -d "${drpath}${ymname}" ]; then
		mkdir -p "${drpath}${ymname}"
	fi
	if [ ! -d "${popath}${ymname}" ]; then
		mkdir -p "${popath}${ymname}"
	fi
    
    mv -f "$2$ymname/$1" "$3$ymname/$1" 2>/dev/null

    return $?
}

# move a blog file between _draft and _post according to $1
# 0: draft2post    1: post2draft
do_movefile()
{
    if [ ! -d "$CFGHEXOMYSOURCE" ]; then
        echo "Error: Please creat your blog folder in up menu => 'Mysource manage'." >&2
        return
    fi
    
    # change dir to basepath
    cd $BASEPATH > /dev/null

    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local drpath="${mypath}_drafts/"
	local popath="${mypath}_posts/"
    local farr=
    local farrsize=0
    local farrvalid=0
    local cpage=0
    local cid=0
    local pgcnt=0
    local tmpcnt=0
    local cmin=0
    local cmax=0
    local nowfrom=
    local nowto=
    local nowmsg=

    if [ $1 -eq 0 ]; then
        nowfrom=$drpath
        nowto=$popath
        nowmsg="Move file from _draft to _post. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    else
        nowfrom=$popath
        nowto=$drpath
        nowmsg="Move file from _post to _draft. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    fi

    while [ : ]; do
        clear
        echo -e $nowmsg 
        # get fname array
        if [ 0 -eq $farrvalid ]; then
            farr=(`ls -Rrl $nowfrom | grep ^- | awk '{print $9}'`)
            ((farrsize=${#farr[*]}))
            if [ 0 -eq $farrsize ]; then
                echo "Info: No posts in folder _${nowfrom##*_}."
                read -p "press 'Enter' to continue ..."
                break
            fi
            farrvalid=1
            ((pgcnt=${farrsize}%${CFGPAGESIZE}))
            if [ $pgcnt -gt 0 ]; then
                ((pgcnt=${farrsize}/${CFGPAGESIZE}+1))
            else
                ((pgcnt=${farrsize}/${CFGPAGESIZE}))
            fi
            cpage=0
        fi
        
        for ((i=0;i<$CFGPAGESIZE;i++)); do
            ((cid=$i+$cpage*$CFGPAGESIZE))
            if [ $cid -ge $farrsize ]; then
                break
            fi
            echo $cid ${farr[$cid]}
        done

        ((cmin=$cpage*$CFGPAGESIZE))
        ((cmax=$cmin+$CFGPAGESIZE-1))
        ((tmpcnt=$farrsize-1))
        if [ $cmax -gt $tmpcnt ]; then
            cmax=$tmpcnt
        fi

        read -p "Your choice: " MYCMD
        case $MYCMD in
            x) break ;;
            j) # prev page
                if [ $cpage -gt 0 ]; then
                    ((cpage-=1))
                fi
                ;;
            k) # next page
                ((tmpcnt=$pgcnt-1))
                if [ $cpage -lt $tmpcnt ] ; then
                    ((cpage+=1))
                fi
                ;;
            *) # parse Num
                if [ -z $MYCMD ]; then
                    # no input
                    continue
                fi

                numrangeok $MYCMD $cmin $cmax
                if [ 0 -ne $? ]; then
                    # not pass the check
                    continue
                fi

                moveaction ${farr[$MYCMD]} $nowfrom $nowto
                if [ 0 -ne $? ]; then
                    # move failed
                    echo "Move failed. Please check user permissions."
                    read -p "press 'Enter' to continue ..."
                    continue
                fi
                
                echo "Move succeeded."
                read -p "press 'Enter' to continue ..."
                ((farrvalid=0))
                ;;
        esac
    done
}

# Menu 3
menu_myblog()
{
    clear
    echo "You can manage your draft or post here."
    echo "1) New draft  2) Move draft to post  3) Move post to draft"
    echo "4) Delete draft  5) Clear empty folders  6) Back"
    while read MYLINE ; do
        clear
        echo "You can manage your draft or post here."
        echo "1) New draft  2) Move draft to post  3) Move post to draft"
        echo "4) Delete draft  5) Clear empty folders  6) Back"
        case $MYLINE in
            1) do_new_draft ;;
            2) do_movefile 0 ;;
            3) do_movefile 1 ;;
            4) : ;;
            5) : ;;
            6) break ;;
            *) : ;;
        esac
    done
}

# test
menu_myblog

# Main menu
: <<$MYEOF
while [ : ] ; do
    echo "THis is a hexo blog helper. Select what you want:"
    select MYSEL in \
        "Mysouce manage" \
        "Server control" \
        "Blog edit" \
        "Exit" \
    ; do
        case $REPLY in
            1) : ;;
            2) : ;;
            3) menu_myblog ;;
            4) : ;;
        esac
        break
    done
    if [ $REPLY -eq 4 ]; then
        break
    fi
done
$MYEOF


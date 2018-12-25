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

# check basic configs
if [ 0 -eq ${#CFGHEXOBLOGPATH} ]; then
    echo "config: CFGHEXOBLOGPATH is missing!" 1>&2
    echo "Please set it up in: recipe.conf!" 1>&2
    exit 1
fi

if [ 0 -eq ${#CFGHEXOMYSOURCE} ]; then
    echo "config: CFGHEXOMYSOURCE is missing!" 1>&2
    echo "Please set it up in: recipe.conf!" 1>&2
    exit 1
fi
if [ "${CFGHEXOMYSOURCE}" = "/" ]; then
    echo "config: CFGHEXOMYSOURCE can NOT be '/'!" 1>&2
    echo "Please correct it in: recipe.conf!" 1>&2
    exit 1
fi

if [ 0 -eq ${#CFGPAGESIZE} ]; then
    echo "config: CFGPAGESIZE is missing!" 1>&2
    echo "Please set it up in: recipe.conf!" 1>&2
    exit 1
fi



# create a new draft
do_new_draft()
{
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
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
    else
        echo "Info: New draft created! File Name: $fn"
    fi
  read -p "press 'Enter' to continue ..."
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

# delete filename $1 from _drafts/_posts $2
delaction()
{
    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local ymname="${1:0:4}${1:5:2}"

    rm -f "$2$ymname/$1" 2>/dev/null

    return $?
}

# get *.md file $1's title from folder _drafts/_posts $2
getmdtitle()
{
    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local ymname="${1:0:4}${1:5:2}"
    local MYLINE=`head -n 3 $2$ymname/$1 | grep ^title:`
    echo ${MYLINE:6}
}

# 0 1 move a blog file between _draft and _post according to $1
# 0: draft2post    1: post2draft
# 2 delete a blog file from _draft
do_cookfile()
{
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
        nowmsg="Move file from _drafts to _posts. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    elif [ $1 -eq 1 ]; then
        nowfrom=$popath
        nowto=$drpath
        nowmsg="Move file from _posts to _drafts. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    elif [ $1 -eq 2 ]; then
        nowfrom=$drpath
        nowmsg="Delete file from _drafts. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    else
        nowfrom=$popath
        nowmsg="Delete file from _posts. Files are listed here.\nChoose the file NUMBER Or pageup=>j pagedown=>k back=>x"
    fi

    while [ : ]; do
        clear
        echo -e $nowmsg 
        # get fname array
        if [ 0 -eq $farrvalid ]; then
            farr=(`ls -Rrl $nowfrom | grep ^- | awk '{print $NF}'`)
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
            echo $cid ${farr[$cid]} `getmdtitle ${farr[$cid]} $nowfrom`
        done

        ((cmin=$cpage*$CFGPAGESIZE))
        ((cmax=$cmin+$CFGPAGESIZE-1))
        ((tmpcnt=$farrsize-1))
        if [ $cmax -gt $tmpcnt ]; then
            cmax=$tmpcnt
        fi

        read -p "[Page $((cpage+1))/$pgcnt]. Your choice: " MYCMD
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

                if [ 2 -eq $1 ]; then
                    # delete action
                    delaction ${farr[$MYCMD]} $nowfrom
                else
                    # move action
                    moveaction ${farr[$MYCMD]} $nowfrom $nowto
                fi

                if [ 0 -ne $? ]; then
                    # move failed
                    echo "Operation failed. Please check user permissions."
                    read -p "press 'Enter' to continue ..."
                    continue
                fi
                
                echo "Operation succeeded."
                read -p "press 'Enter' to continue ..."
                ((farrvalid=0))
                ;;
        esac
    done
}

# clear empty folders from _posts and _drafts
do_clearempty()
{
    # change dir to basepath
    cd $BASEPATH > /dev/null

    local mypath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    local drpath="${mypath}_drafts/"
	local popath="${mypath}_posts/"

    local farr=(`ls -l $drpath | grep ^d | awk '{print $NF}'`)
    local tmptest
    for tmpfolder in ${farr[@]}; do
        tmptest=`ls -A $drpath$tmpfolder`
        if [ 0 -eq ${#tmptest} ]; then
            echo "_drafts/$tmpfolder deleted!"
            rm -rf $drpath$tmpfolder 2>/dev/null
        fi
    done

    farr=(`ls -l $popath | grep ^d | awk '{print $NF}'`)
    for tmpfolder in ${farr[@]}; do
        tmptest=`ls -A $popath$tmpfolder`
        if [ 0 -eq ${#tmptest} ]; then
            echo "_posts/$tmpfolder deleted!"
            rm -rf $popath$tmpfolder 2>/dev/null
        fi
    done
    echo "Clear done!"
    read -p "press 'Enter' to continue ..."
}

# Menu 3
menu_myblog()
{
    # change dir to basepath
    cd $BASEPATH > /dev/null

    if [ ! -d "$CFGHEXOMYSOURCE" ]; then
        echo "Error: Please creat your blog folder in up menu => 'Mysource manage'." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi

    while [ : ] ; do
        clear
        echo "You can manage your draft or post here."
        echo "1) New draft  2) Move draft to post  3) Move post to draft"
        echo "4) Delete draft  5) Clear empty folders  6) Back"
        read -p "Your choice: " MYLINE
        case $MYLINE in
            1) do_new_draft ;;
            2) do_cookfile 0 ;;
            3) do_cookfile 1 ;;
            4) do_cookfile 2 ;;
            5) do_clearempty ;;
            6) break ;;
        esac
    done
}

# check if hexo is installed
hexook()
{
    hexo version 2>&1 1>/dev/null
    if [ 0 -ne $? ]; then
        return 1
    fi

    return 0
}

# init blog folders from Hexo
do_initblog_hexo()
{
    # change dir to basepath
    cd $BASEPATH > /dev/null

    if [ ! -d "$CFGHEXOBLOGPATH" ]; then
        echo "Your hexo folder doesn't exist. Create it in up menu => 'Hexo manage'." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi
    local tmptest
    local hepath=`pathfix $(cd $CFGHEXOBLOGPATH; pwd)`
    hexo 2>&1 >/dev/null
    if [ 0 -ne $? ]; then
        echo "Hexo is NOT installed! Please install it first." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi

    while read MYLINE; do
        tmptest=`echo $MYLINE | grep ^server`
        if [ 0 -eq ${#tmptest} ]; then
            continue
        else
            break
        fi
    done <<$MYEOF
`hexo --cwd $hepath`
$MYEOF

    if [ 0 -eq ${#tmptest} ];  then
        echo "Hexo is installed, but your hexo blog does NOT exist." >&2
        echo "Init your hexo blog in up menu => 'Hexo manage'." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi

    if [ ! -d "${hepath}source" ]; then
        echo "Perhaps your Hexo blog is NOT initialized properly." >&2
        echo "Reinit your hexo blog in up menu => 'Hexo manage'." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi

    # copy default source/ to .defsource/ for further use
    if [ ! -d "${hepath}.defsource" ]; then
        cp -RL "${hepath}source" "${hepath}.defsource" 2>/dev/null
    fi
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
        read -p "press 'Enter' to continue ..."
        return
    fi

    # copy .defsource/ to $CFGHEXOMYSOURCE
    if [ -d "$CFGHEXOMYSOURCE" ]; then
        echo "Warning: Your blog folder Exists! Action will clear All files in it!"
        read -p "Continue the action: (no)" MYLINE
        if [ ! "${MYLINE,,}" = "y" ] && [ ! "${MYLINE,,}" = "yes" ]; then
            return
        fi
        rm -rf "$CFGHEXOMYSOURCE" 2>/dev/null
        if [ 0 -ne $? ]; then
            echo "Operation failed. Please check user permissions."
            read -p "press 'Enter' to continue ..."
            return
        fi
    fi

    cp -R "${hepath}.defsource" "$CFGHEXOMYSOURCE" 2>/dev/null
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
        read -p "press 'Enter' to continue ..."
        return
    fi

    local mspath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    ln -s "$mspath" "${hepath}source" 2>/dev/null
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
        read -p "press 'Enter' to continue ..."
        return
    fi

    echo "Blog inited from Hexo's source/ folder."
    read -p "press 'Enter' to continue ..."
}

# Menu 2
menu_mysource()
{
    while [ : ]; do
        clear
        echo "You can manage your blog folders here."
        echo "1) Init blog folders from Hexo"
        echo "2) Init blog folders from Git"
        echo "3) Simple Git Syncronize"
        echo "4) Back"
        read -p "Your choice: " MYLINE
        case $MYLINE in
            1) do_initblog_hexo ;;
            2) : ;;
            3) : ;;
            4) break ;;
        esac
    done
}

# test
menu_mysource

# Main menu
: <<$MYEOF
while [ : ] ; do
    echo "THis is a hexo blog helper. Select what you want:"
    select MYSEL in \
        "Hexo manage" \
        "Mysouce manage" \
        "Blog edit" \
        "Exit" \
    ; do
        case $REPLY in
            1) : ;;
            2) menu_mysource ;;
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


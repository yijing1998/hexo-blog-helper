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

    local hepath=`pathfix $(cd $CFGHEXOBLOGPATH; pwd)`
    
    # copy .defsource/ to $CFGHEXOMYSOURCE
    if [ ! -d "${hepath}.defsource" ]; then
        echo "Seems your Hexo server was not properly installed!"
        echo "Please reinstall hexo in up menu => 'Hexo manage'"
        echo -p "press 'Enter' to continue ..."
        return
    fi

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

    # create symlink
    local mspath=`pathfix $(cd $CFGHEXOMYSOURCE; pwd)`
    rm -rf "${hepath}source" 2>/dev/null
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
        read -p "press 'Enter' to continue ..."
        return
    fi
    ln -s "$mspath" "${hepath}source" 2>/dev/null
    if [ 0 -ne $? ]; then
        echo "Operation failed. Please check user permissions."
        read -p "press 'Enter' to continue ..."
        return
    fi

    echo "Blog inited from Hexo's source/ folder."
    echo "And blog folder is linked to hexo server"
    read -p "press 'Enter' to continue ..."
}

# init blog folders from Git
do_initblog_git()
{

}

# Menu 2
menu_mysource()
{
    while [ : ]; do
        clear
        echo "You can manage your blog folders here."
        echo "1) Init blog folder from Hexo"
        echo "2) Init blog folder from Git"
        echo "3) Link blog folder to Hexo server"
        echo "4) Simple Git Syncronize"
        echo "5) Back"
        read -p "Your choice: " MYLINE
        case $MYLINE in
            1) do_initblog_hexo ;;
            2) do_initblog_git ;;
            3) : ;;
            4) : ;;
            5) break ;;
        esac
    done
}

# Install Hexo server
do_install_hserver()
{
    # change dir to basepath
    cd $BASEPATH > /dev/null

    if [ -d "$CFGHEXOBLOGPATH" ]; then
        echo "Your hexo server folder EXISTS! Old hexo server files will be removed!"
        echo "You should relink hexo server to your blog files in up menu => 'Mysouce manage'."
        read -p "Continue the action: (no)" MYLINE
        if [ ! "${MYLINE,,}" = "y" ] && [ ! "${MYLINE,,}" = "yes" ]; then
            return
        fi

        rm -rf "$CFGHEXOBLOGPATH" 2>/dev/null
        if [ 0 -ne $? ]; then
            echo "Operation failed. Please check user permissions."
            read -p "press 'Enter' to continue ..."
            return
        fi
    fi

    # node check
    node -v >/dev/null 2>&1
    if [ 0 -ne $? ]; then
        echo "Nodejs is NOT installed! Please install it first." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi

    # npm check
    local cmdnpm="n"
    npm -v >/dev/null 2>&1
    if [ 0 -eq $? ]; then
        cmdnpm="y"
    fi

    # yarn check
    local cmdyarn="n"
    yarn -v >/dev/null 2>&1
    if [ 0 -eq $? ]; then
        cmdyarn="y"
    fi

    local npcmd=""
    if [ "$cmdyarn" = "y" ]; then
        npcmd="yarn"
    elif [ "$cmdnpm" = "y" ]; then
        npcmd="npm"
    fi

    if [ -z "$npcmd" ]; then
        echo "npm/yarn is NOT available! Please install it first." >&2
        read -p "press 'Enter' to continue ..."
        return
    fi
    
    # install hexo
    hexo >/dev/null 2>&1
    if [ 0 -ne $? ]; then
        if [ `id -u` -eq 0 ]; then
            # do as root
            if [ "$npcmd"="yarn" ]; then
                $npcmd global add hexo-cli
            else
                $npcmd install hexo-cli -g
            fi
        else
            # no root
            if [ "$npcmd"="yarn" ]; then
                sudo $npcmd global add hexo-cli
            else
                sudo $npcmd install hexo-cli -g
            fi
        fi

        if [ 0 -ne $? ]; then
            echo "Can NOT install hexo. Be sure to run with root privileges." >&2
            read -p "press 'Enter' to continue ..."
            return
        fi
    fi

    echo "Installing hexo server ..., please wait!"
    hexo init "$CFGHEXOBLOGPATH" && cd "$CFGHEXOBLOGPATH" && $npcmd install
    if [ 0 -ne $? ]; then
        echo "Installation failed!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    # It's in the very directory, mv source .defsource
    mv source .defsource 2>/dev/null
    if [ 0 -ne $? ]; then
      echo "Can NOT mv files, please check user permissions!"
    fi

    # create symlink to 'source/'
    ln -s .defsource source 2>/dev/null
    if [ 0 -ne $? ]; then
      echo "Can NOT create symlink to 'source/', please check user permissions!"
    fi

    echo "Installation succeeded!"
    echo "You should relink hexo server to your blog files in up menu => 'Mysouce manage'."
    read -p "press 'Enter' to continue ..."
}

# install my theme
do_install_mytheme()
{
    # check if theme repo/name is set
    if [ 0 -eq ${#CFGMYTHEMEREPO} ]; then
        echo "Theme repo is NOT set! Do Nothing!"
        read -p "press 'Enter' to continue ..."
        return
    fi
    if [ 0 -eq ${#CFGMYTHEMENAME} ]; then
        echo "Theme name is NOT set! Do Nothing!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    # change dir to basepath
    cd $BASEPATH > /dev/null

    if [ ! -d "$CFGHEXOBLOGPATH" ]; then
        echo "Hexo server is not proper installed 1. Please install it first!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    local hepath=`pathfix $(cd $CFGHEXOBLOGPATH; pwd)`
    if [ ! -d "${hepath}themes" ]; then
        echo "Hexo server is not proper installed 2. Please install it first!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    # check git installation
    git version >/dev/null 2>&1
    if [ 0 -ne $? ]; then
        echo "Git is not proper installed. Please install it first!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    # check installed theme
    if [ -d "${hepath}themes/${CFGMYTHEMENAME}" ]; then
        echo "Your theme Exists! Action will remove it!"
        read -p "Are you sure to reinstall it?: (no)" MYLINE
        if [ ! "${MYLINE,,}" = "y" ] && [ ! "${MYLINE,,}" = "yes" ]; then
            return
        fi
        rm -rf "${hepath}themes/${CFGMYTHEMENAME}" 2>/dev/null
        if [ 0 -ne $? ]; then
            echo "rm failed. Please check user permissions."
            read -p "press 'Enter' to continue ..."
            return
        fi
    fi

    # do git clone
    echo "Installing your theme, please wait..."
    git clone "$CFGMYTHEMEREPO" "${hepath}themes/${CFGMYTHEMENAME}"
    if [ 0 -ne $? ]; then
        echo "Can NOT git clone from $CFGMYTHEMEREPO, please check your theme settings!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    echo "Installation of Hexo theme succeeded"
    read -p "press 'Enter' to continue ..."
}

# show hexo server status
show_hexosever_status()
{
    # check hexo_server_info existence
    local hsinfo
    if [ -f .hexo_server_info ]; then
        hsinfo=(`cat .hexo_server_info`)
    fi
    
    if [ -n "${hsinfo[0]}" ]; then
        echo "Hexo server status: IS runing! PID: ${hsinfo[0]}"
    else
        echo "Hexo server status: NOT running!"
    fi
}

do_start_hexoserver()
{
    # change dir to basepath
    cd $BASEPATH > /dev/null

    # hexo server folder check
    if [ ! -d "$CFGHEXOBLOGPATH" ]; then
        echo "Your Hexo server folder is missing. Please reinstall hexo server!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    # hexo and hexo server check
    hexo >/dev/null 2>&1
    if [ 0 -ne $? ]; then
        echo "Hexo is NOT installed! Please reinstall hexo server!"
        read -p "press 'Enter' to continue ..."
        return
    fi

    local hepath=`pathfix $(cd $CFGHEXOBLOGPATH; pwd)`

    # check symlink source/'s existence
    local tmpstr=`ls -l "$hepath" | grep "^l.*[[:space:]]source[[:space:]]->"`
    if [ -z "$tmpstr" ]; then
        echo "Hexo server does NOT link to any blog files!"
        echo "Link hexo server to your blog files in up menu => 'Mysouce manage'."
        read -p "press 'Enter' to continue ..."
        return
    fi

    local hsinfo
    # read out hexo server info(pid, fdin, fdout) from .hexo_server_info
    if [ -f .hexo_server_info ]; then
        hsinfo=(`cat .hexo_server_info`)
    fi

    if [ -n "${hsinfo[0]}" ]; then
        echo "Stopping the existing server..."
        kill ${hsinfo[0]}
        sleep 3s
    fi
    echo "Staring hexo server, please wait..."
    coproc hexo server --cwd=$hepath
    sleep 3s
    if [ -z "$COPROC_PID" ]; then
        cat /dev/null > .hexo_server_info
        echo "Can't start hexo server in 3 seconds!"
    else
        echo $COPROC_PID ${COPROC[0]} ${COPROC[1]} > .hexo_server_info
        echo "Hexo server started!"
    fi

    read -p "press 'Enter' to continue ..."
}

do_stop_hexoserver()
{
    local hsinfo
    # read out hexo server info(pid, fdin, fdout) from .hexo_server_info
    if [ -f .hexo_server_info ]; then
        hsinfo=(`cat .hexo_server_info`)
    fi

    if [ -n "${hsinfo[0]}" ]; then
        echo "Stopping the existing server..."
        kill ${hsinfo[0]} 2>/dev/null
        sleep 3s
        cat /dev/null > .hexo_server_info
        echo "Hexo server stopped!"
    else
        echo "No hexo server is running, do nothing!"
    fi

    read -p "press 'Enter' to continue ..."
}

# Menu 1
menu_hexomg()
{
    while [ : ]; do
        clear
        show_hexosever_status
        echo "You can manage your hexo server here."
        echo "1) (Re)Install Hexo Server"
        echo "2) (Re)Install My Theme"
        echo "3) (Re)Start Hexo Server"
        echo "4) Stop Hexo Server"
        echo "5) Refresh Hexo Sever Status"
        echo "6) Back"
        read -p "Your choice: " MYLINE
        case $MYLINE in
            1) do_install_hserver ;;
            2) do_install_mytheme ;;
            3) do_start_hexoserver ;;
            4) do_stop_hexoserver ;;
            5) : ;;
            6) break ;;
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
        "Hexo server" \
        "Mysouce manage" \
        "Blog edit" \
        "Exit" \
    ; do
        case $REPLY in
            1) menu_hexomg ;;
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


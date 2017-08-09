#!/bin/bash

# init hexo, get upstream hexo themes, create symbolic links to make hexo work properly with user's source files and config files

# user settings --- begin --- #
tfolder='themes'
: ${trepos:="
	next|https://github.com/yijing1998/hexo-theme-next.git|master
	landscape|https://github.com/hexojs/hexo-theme-landscape.git|master
"}
ufolder='ufiles'
urepo='https://github.com/yijing1998/hexo-ufiles.git|master'
hfolder='hexofolder'
tasktimer="50 * * * *"
# task debug flag: on / off
taskdf="on"

# ssh or https
git_deploy_type="ssh"

# ssh pub key location
sshkey=$HOME/.ssh/id_rsa

# user settings --- end --- #

# calculate some usable variables
rfolder=`pwd`
urepo_url=${urepo%|*}
urepo_branch=${urepo#*|}
osname=`uname -o`
taskcmd="cd $rfolder && ./recipe.sh task deploy"

# set task debug log path
if [ $taskdf = "on" ]; then
	tasklog="$rfolder/logs"
else
	tasklog="/dev/null"
fi

# prepare authentication info
# do deploy without authentication prompt
if [ $git_deploy_type = "ssh" ]; then
	export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
	# ssh-agent check and run
	tmp=`ps -ef | grep "[s]sh-agent" | wc -l`
	if [ $tmp -eq 0 ]; then
		eval "$(ssh-agent -s)" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			ssh-add $sshkey > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "Error: Failed to add ssh-key to ssh-agent." 1>&2
				exit 1
			fi
		else
			echo "Error: Failed to run ssh-agent." 1>&2
			exit 1
		fi
	fi
else
	:
fi

# alias git='LANGUAGE=en_US:en git'
# ensure git produce English message (tested in ubuntu17)
export LANGUAGE="en_US:en"

# enable native symbolic link for mingw in windows
if [ $osname = "Msys" ]; then
	export MSYS=winsymlinks:native
fi

# check and change to approot if needed
chch_approot()
{
	if [ ! "$rfolder" = "`pwd`" ]; then
		cd $rfolder > /dev/null
	fi
}

# $1: target folder
# $2: repo url
# $3: repo branch
# return:
# 0 params error
# 1 folder not exist
# 2 no git repo in the folder
# 3 current branch is not clean
# 4 can't change to target branch
# 5 given url not match any git remote url
# 6 can't fetch remote branch
# 7 is ahead of
# 8 is behind
# 9 is up-to-date
# 10 unknown status
# side effect: current dir perhaps changed, checkout local branch and fetched remote branch
check_repo_status()
{
	chch_approot

	# params check
	if [ $# -ne 3 ]; then
		echo 0
		return
	fi

	# folder existance check
	if [ ! -d $1 ]; then
		echo 1
		return
	fi

	# git status check
	cd $1 > /dev/null; gstatus=`git status -s`
	# folder exist but no git repo
	if [ $? -ne 0 ]; then
		echo 2
		return
	fi

	# now it's still in the path of $1
	# check if current branch is clean
	if [ ! "$gstatus" = "" ]; then
		echo 3
		return
	fi

	# can't change to target branch: perhaps wrong branch name
	git checkout $urepo_branch &> /dev/null
	if [ $? -ne 0 ]; then
		echo 4
		return
	fi

	flag=0
	rname=""
	while read line; do
		tmp=`echo $line | grep -o "[[:space:]].*[[:space:]]"`
		if [ `echo $tmp` = $urepo_url ]; then
			rname=${line%%[[:space:]]*}
			flag=1
		fi
	done <<E_O_F
`git remote -v`
E_O_F

	# wrong remote url
	if [ $flag -eq 0 ]; then
		echo 5
		return
	fi

	# check remote repo's commit
	# git remote error: perhaps network
	# echo 1>&2 `pwd`
	git fetch $rname $urepo_branch &> /dev/null
	if [ $? -ne 0 ]; then
		echo 6
		return
	fi

	# get commits difference between local repo and remote repo
	gstatus=`git status`
	tmp=`echo "$gstatus" | grep -o "is ahead of"`
	if [ "$tmp" = "is ahead of" ]; then
		# is ahead of
		echo 7
		return
	fi

	tmp=`echo "$gstatus" | grep -o "is behind"`
	if [ "$tmp" = "is behind" ]; then
		# is behind
		echo 8
		return
	fi

	tmp=`echo "$gstatus" | grep -o "is up-to-date"`
	if [ "$tmp" = "is up-to-date" ]; then
		# is up-to-date
		echo 9
		return
	fi

	# can be here
	echo 10
}

# install crontab task for current user
# task: auto fire task_deploy
task_install()
{
	if [ $osname = "Msys" ]; then
		echo "can't support msys, please run in *unix"
		return
	fi
	tsklist=`crontab -l 2> /dev/null`

	# check if is installed
	tmp=`echo "$tsklist" | grep -o "recipe.sh task deploy"`
	if [ "$tmp" = "recipe.sh task deploy" ]; then
		echo "do nothing: task was installed"
		return
	fi

	tmp=`echo $tsklist`
	# install crontab
	if [ "$tmp" = "" ]; then
		echo "task installed."
		crontab <<E_O_F
$tasktimer $taskcmd
E_O_F
	else
		echo "task installed with other tasks"
		crontab <<E_O_F
`echo "$tsklist"`
$tasktimer $taskcmd
E_O_F
	fi
}

# remove crontab task for current user
task_uninstall()
{
	if [ $osname = "Msys" ]; then
		echo "can't support msys, please run in *unix"
		return
	fi
	tsklist=`crontab -l 2> /dev/null`

	# check empty list
	tmp=`echo $tsklist`
	if [ "$tmp" = "" ]; then
		echo "do nothing: empty task list"
		return
	fi

	# remove crontab task
	tmp=`echo "$tsklist" | sed '/recipe.sh task deploy/d'`
	if [ "$tmp" = "" ]; then
		echo "task removed: only one"
		crontab -r
		return
	fi
	echo "task removed: side by side"
	crontab <<E_O_F
`echo "$tmp"`
E_O_F
}

# deploy according to remote ufiles changes
task_deploy()
{
	gcode=`check_repo_status $ufolder $urepo_url $urepo_branch`
	if [ $gcode -ne 8 ]; then
		echo "do nothing: gcode is $gcode"
		return
	fi

	# do merge since FETCH_HEAD is updated
	chch_approot; cd $ufolder 1> /dev/null
	git merge FETCH_HEAD &> /dev/null
	if [ $? -ne 0 ]; then
		echo "git merge error: perhaps local branch is not clean"
		return
	fi

	# do deploy
	hexo_deploy
}

get_git_themes()
{
	for i in `echo ${trepos}`; do
		arr=(${i//|/ })
		tar=$tfolder/${arr[0]}
		#check theme repo folder's existance
		if [ -d $tar ]; then
			echo "Can't overwrite local folder: $tar, please remove it manually."
		else
			git clone ${arr[1]} $tar
			if [ $? -eq 0 ]; then
				cd $tar
				git checkout ${arr[2]}
				cd $rfolder
			fi
		fi
	done
}

get_git_ufiles()
{
	arr=(${urepo//|/ })
	#check user repo folder's existance
	if [ -d $ufolder ]; then
		echo "Can't overwrite local folder: $ufolder, please remove it manually. Or use other command."
	else
		git clone ${arr[0]} $ufolder
		if [ $? -eq 0 ]; then
			cd $ufolder
			git checkout ${arr[1]}
			cd $rfolder
		fi
	fi
}

init_hexo()
{
	if [ -d $hfolder ]; then
		echo "Can't init hexo in local folder: $hfolder, it's already exist, please remove it manually."
	else
		hexo init $hfolder
		#plugin
		cd $hfolder
		npm install hexo-deployer-git --save
		cd $rfolder
	fi
}

link_things()
{
	rm -f $hfolder/_config.yml
	rm -rf $hfolder/themes
	rm -rf $hfolder/source
	cd $hfolder
	ln -s ../$ufolder/_config.yml _config.yml
	ln -s ../$tfolder themes
	ln -s ../$ufolder source
	cd $rfolder
}

# init the working place from a fresh git clone
init_all()
{
	get_git_ufiles
	get_git_themes
	init_hexo
	link_things
}

# create a new post in folder _posts
# yyyyMM/yyyy-MM-dd.###.md with hexo format: title date tags
hexo_new_post()
{
	# existance check
	if [ ! -d $ufolder ]; then
		echo "No user repo files found! Try \'recipe git urepo\'".
		return
	fi

	drpath="$ufolder/_drafts"
	popath="$ufolder/_posts"
	ymname=`date "+%Y%m"`
	if [ ! -d "$drpath/$ymname" ]; then
		mkdir "$drpath/$ymname"
	fi
	if [ ! -d "$popath/$ymname" ]; then
		mkdir "$popath/$ymname"
	fi

  fn=""
	tmpstr=`ls $popath/$ymname $drpath/$ymname 2> /dev/null | grep .*\.md | sort -r | head -1`
	if [ "$tmpstr" = "" ]; then
		# first post of current month
		fn=`date "+%Y-%m-%d.001.md"`
	else
		tmpstr=${tmpstr#*.}
		tmpstr=${tmpstr%.*}
		((tmpnum=10#$tmpstr))
		if [ $tmpnum -eq 999 ]; then
			echo "Error: Too many posts a month! 999 is the max." 1>&2
			return
		fi
		tmpnum=$[tmpnum+1]
		if [ $tmpnum -lt 10 ]; then
			fn=`date "+%Y-%m-%d.00${tmpnum}.md"`
		elif [ $tmpnum -lt 100 ]; then
			fn=`date "+%Y-%m-%d.0${tmpnum}.md"`
		else
			fn=`date "+%Y-%m-%d.${tmpnum}.md"`
		fi
	fi

	# create the post
	cat > $popath/$ymname/$fn <<E_O_F
---
title: title place for you!
date: `date "+%Y-%m-%d %H:%M:%S"`
tags:
---
E_O_F
  echo "Info: New post created! File Name: $fn"
}

# create a new draft in folder _drafts
# yyyyMM/yyyy-MM-dd.###.md with hexo format: title date tags
hexo_new_draft()
{
	# existance test
	if [ ! -d "$ufolder" ]; then
		echo "Error: No user repo files found! Try \'recipe git urepo\'" 1>&2
		return
	fi

	drpath="$ufolder/_drafts"
	popath="$ufolder/_posts"
	ymname=`date "+%Y%m"`
	if [ ! -d "$drpath/$ymname" ]; then
		mkdir "$drpath/$ymname"
	fi
	if [ ! -d "$popath/$ymname" ]; then
		mkdir "$popath/$ymname"
	fi

  fn=""
	tmpstr=`ls $popath/$ymname $drpath/$ymname 2> /dev/null | grep .*\.md | sort -r | head -1`
	if [ "$tmpstr" = "" ]; then
		# first post of current month
		fn=`date "+%Y-%m-%d.001.md"`
	else
		tmpstr=${tmpstr#*.}
		tmpstr=${tmpstr%.*}
		((tmpnum=10#$tmpstr))
		if [ $tmpnum -eq 999 ]; then
			echo "Error: Too many posts a month! 999 is the max." 1>&2
			return
		fi
		tmpnum=$[tmpnum+1]
		if [ $tmpnum -lt 10 ]; then
			fn=`date "+%Y-%m-%d.00${tmpnum}.md"`
		elif [ $tmpnum -lt 100 ]; then
			fn=`date "+%Y-%m-%d.0${tmpnum}.md"`
		else
			fn=`date "+%Y-%m-%d.${tmpnum}.md"`
		fi
	fi

	# create the post
	cat > $drpath/$ymname/$fn <<E_O_F
---
title: title place for you!
date: `date "+%Y-%m-%d %H:%M:%S"`
tags:
---
E_O_F
  echo "Info: New draft created! File Name: $fn"
}

# move post from folder _drafts to folder _posts
hexo_draft2post()
{
	# existance test
	if [ ! -d "$ufolder" ]; then
		echo "Error: No user repo files found! Try \'recipe git urepo\'" 1>&2
		return
	fi

  # waiting for user input
  while [ 1 -eq 1 ]; do
		# find last 5 posts in _drafts
		drpath="$ufolder/_drafts"
		popath="$ufolder/_posts"
	  fdarr=()
		for sf in `ls -lr $drpath | grep "^d.*[[:digit:]]\{6\}$" | awk '{print $9}' `; do
	    for pf in `ls -r $drpath/$sf`; do
				fdarr[${#fdarr[@]}]=$sf/$pf
				if [ ${#fdarr[@]} -eq 5 ]; then
					break
				fi
			done

			if [ ${#fdarr[@]} -eq 5 ]; then
				break
			fi
		done

		if [ ${#fdarr[@]} -eq 0 ]; then
			echo "Info: No posts in folder _drafts."
			break
		fi

		#list top 5 posts in folder _drafts
		((tmpnum=10#0))
		for item in ${fdarr[*]}; do
			tmpnum=$[tmpnum+1]
			tt=`sed -n '0,/^title: /s/^title: //p' $drpath/$item`
			dt=`sed -n '0,/^date: /s/^date: //p' $drpath/$item`
			echo $tmpnum [$dt] $tt
		done
		read -p "Please enter your choice (type 'x' to exit): " cmd
		if [ $cmd = "x" ]; then
			break
		fi
		((tmpnum=10#$cmd)) 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi

		if [ $tmpnum -lt 1 -o $tmpnum -gt 5 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi
		tmpstr=${fdarr[(($tmpnum-1))]}
		ymname=${tmpstr%/*}

		if [ ! -d "$popath/$ymname" ]; then
			mkdir "$popath/$ymname"
		fi

		mv $drpath/$tmpstr $popath/$tmpstr 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Failed to move file, please check user permission." 1>&2
		else
			echo "Info: A post moved from _drafts to _posts."
		fi
	done
}

# move post from folder _posts to folder _drafts
hexo_post2draft()
{
	# existance test
	if [ ! -d "$ufolder" ]; then
		echo "Error: No user repo files found! Try \'recipe git urepo\'" 1>&2
		return
	fi

  # waiting for user input
  while [ 1 -eq 1 ]; do
		# find last 5 posts in _posts
		drpath="$ufolder/_drafts"
		popath="$ufolder/_posts"
	  fdarr=()
		for sf in `ls -lr $popath | grep "^d.*[[:digit:]]\{6\}$" | awk '{print $9}' `; do
	    for pf in `ls -r $popath/$sf`; do
				fdarr[${#fdarr[@]}]=$sf/$pf
				if [ ${#fdarr[@]} -eq 5 ]; then
					break
				fi
			done

			if [ ${#fdarr[@]} -eq 5 ]; then
				break
			fi
		done

		if [ ${#fdarr[@]} -eq 0 ]; then
			echo "Info: No posts in folder _posts."
			break
		fi

		#list top 5 posts in folder _drafts
		((tmpnum=10#0))
		for item in ${fdarr[*]}; do
			tmpnum=$[tmpnum+1]
			tt=`sed -n '0,/^title: /s/^title: //p' $popath/$item`
			dt=`sed -n '0,/^date: /s/^date: //p' $popath/$item`
			echo $tmpnum [$dt] $tt
		done
		read -p "Please enter your choice (type 'x' to exit): " cmd
		if [ $cmd = "x" ]; then
			break
		fi
		((tmpnum=10#$cmd)) 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi

		if [ $tmpnum -lt 1 -o $tmpnum -gt 5 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi
		tmpstr=${fdarr[(($tmpnum-1))]}
		ymname=${tmpstr%/*}

		if [ ! -d "$drpath/$ymname" ]; then
			mkdir "$drpath/$ymname"
		fi

		mv $popath/$tmpstr $drpath/$tmpstr 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Failed to move file, please check user permission." 1>&2
		else
			echo "Info: A post moved from _posts to _drafts."
		fi
	done
}

# remove posts in folder _drafts (to folder .rbs)
hexo_remove_draft()
{
	# existance test
	if [ ! -d "$ufolder" ]; then
		echo "Error: No user repo files found! Try \'recipe git urepo\'" 1>&2
		return
	fi

	if [ ! -d "$ufolder/.rbs" ]; then
		mkdir "$ufolder/.rbs"
	fi

	# waiting for user input
  while [ 1 -eq 1 ]; do
		# find last 5 posts in _drafts
		drpath="$ufolder/_drafts"
		rbpath="$ufolder/.rbs"
	  fdarr=()
		for sf in `ls -lr $drpath | grep "^d.*[[:digit:]]\{6\}$" | awk '{print $9}' `; do
	    for pf in `ls -r $drpath/$sf`; do
				fdarr[${#fdarr[@]}]=$sf/$pf
				if [ ${#fdarr[@]} -eq 5 ]; then
					break
				fi
			done

			if [ ${#fdarr[@]} -eq 5 ]; then
				break
			fi
		done

		if [ ${#fdarr[@]} -eq 0 ]; then
			echo "Info: No posts in folder _drafts."
			break
		fi

		#list top 5 posts in folder _drafts
		((tmpnum=10#0))
		for item in ${fdarr[*]}; do
			tmpnum=$[tmpnum+1]
			tt=`sed -n '0,/^title: /s/^title: //p' $drpath/$item`
			dt=`sed -n '0,/^date: /s/^date: //p' $drpath/$item`
			echo $tmpnum [$dt] $tt
		done
		read -p "Please enter your choice (type 'x' to exit): " cmd
		if [ $cmd = "x" ]; then
			break
		fi
		((tmpnum=10#$cmd)) 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi

		if [ $tmpnum -lt 1 -o $tmpnum -gt 5 ]; then
			echo "Error: Please input number 1~5 or 'x'" 1>&2
			continue
		fi
		tmpstr=${fdarr[(($tmpnum-1))]}
		ymname=${tmpstr%/*}

		if [ ! -d "$rbpath/$ymname" ]; then
			mkdir "$rbpath/$ymname"
		fi

		mv $drpath/$tmpstr $rbpath/$tmpstr 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Error: Failed to move file, please check user permission." 1>&2
		else
			echo "Info: A post moved from _drafts to .rbs."
		fi
	done
}

# check hexo installation and initialization
# do check under current folder: pwd
# return
# 0: not installed
# 1: installed but not initialized
# 2: installed and initialized
hexo_check()
{
	msg=`hexo 2> /dev/null`
	# not installed
	if [ $? -ne 0 ]; then
		echo 0
		return
	fi

	tmp=`echo $msg | grep -o "clean"`
	if [ ! "$tmp" = "clean" ]; then
		# not initialized
		echo 1
	else
		# initialized
		echo 2
	fi
}

hexo_server()
{
	cd $hfolder && hexo server --draft
}

hexo_deploy()
{
	cd $rfolder &> /dev/null && cd $hfolder &> /dev/null
	if [ $? -ne 0 ]; then
		echo "error: hexo working folder do not exist, forgot to run 'recipe.sh init' or some other recipes?"
		return
	fi

	# check if /usr/local/bin is in $PATH
	# in crontab task, /usr/local/bin is not in $PATH
	tmp=`echo $PATH | grep "/usr/local/bin"`
	if [ ! "$tmp" = "/usr/local/bin" ]; then
		export PATH="$PATH:/usr/local/bin"
	fi

	tmp=`hexo_check`
	case $tmp in
		0 )
			echo "error: hexo is not installed"
			return
			;;
		1 )
			echo "error: hexo is not initialized, run 'hexo init' or some recipes"
			return
			;;
	esac

	echo "cleaning hexo cache"; hexo clean &> /dev/null
	if [ $? -ne 0 ]; then
		echo "error: hexo clean is not ok"
		return
	fi

	echo "begin hexo deploy"; hexo deploy > $tasklog 2>&1 && echo "end hexo deploy"
	if [ $? -ne 0 ]; then
		echo "error: hexo deploy failed, perhaps network problems"
	fi
}

usage()
{
	echo 'Entering usage()'
}

# really do sth
if [ $# -eq 1 ]; then
	case $1 in
		init )
			# init
			init_all
			;;
		server )
			# start hexo server
			hexo_server
			;;
		deploy )
			hexo_deploy
			;;
		d2p )
		  hexo_draft2post
		  ;;
		p2d )
		  hexo_post2draft
			;;
		rmd )
		  hexo_remove_draft
			;;
		nd )
		  hexo_new_draft
			;;
		* )
			usage
			;;
	esac
elif [ $# -eq 2 ]; then
	case $1 in
		new )
			case $2 in
				post )
					# new post
					hexo_new_post
					;;
				draft )
					hexo_new_draft
					;;
				* )
					usage
					;;
			esac
			;;
		task )
			case $2 in
				install )
					task_install
					;;
				deploy )
					task_deploy
					;;
				uninstall )
					task_uninstall
					;;
				* )
					usage
					;;
			esac
			;;
		* )
			usage
			;;
	esac
else
	usage
fi

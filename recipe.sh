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
tasktimer="30 * * * *"
# ssh or https
git_deploy_type="ssh"
# user settings --- end --- #

# calculate some usable variables
rfolder=`pwd`
urepo_url=${urepo%|*}
urepo_branch=${urepo#*|}
osname=`uname -o`
taskcmd="cd $rfolder && ./recipe.sh task deploy"
# do deploy without authentication prompt
if [ $git_deploy_type = "ssh" ]; then
	export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa"
else
	:
fi

# enable native symbolic link for mingw in windows
if [ $osname = "Msys" ]; then
	export MSYS=winsymlinks:native
fi

# check and change to approot if needed
chch_approot()
{
	if [ ! $rfolder = "`pwd`" ]; then
		cd $rfolder $1 > /dev/null
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

# create a new post according to the last post's name
new_post()
{
	# existance check
	if [ ! -d $ufolder ]; then
		echo No user repo files found! Try \'recipe git urepo\'.
		return
	fi

	popath="$ufolder/_posts"
	daystr=`date "+%Y-%m-%d"`

	tmpcnt=`find $popath -maxdepth 1 -name "$daystr*" | wc -w`

	pname=''
	if [ $tmpcnt -eq 0 ]; then
		pname="o01"
	else
		# find the max number and calculate the new post file name
		tmpstr=`find $popath -maxdepth 1 -name "$daystr*" | sort -r | head -1 | grep -o "o[[:digit:]]\{2\}"`
		mnum=${tmpstr#*o0}
		if [ "$mnum" = "$tmpstr" ]; then
			mnum=${tmpstr#*o}
		fi
		mnum=$[mnum+1]
		if [ $mnum -lt 10 ]; then
			pname="o0"${mnum}
		elif [ $mnum -lt 100 ]; then
			pname="o"${mnum}
		else
			echo "Too many posts a day! 99 is the max."
			return
		fi
	fi

	cd $hfolder
	hexo new $pname
	cd $rfolder
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
	cd $hfolder
	hexo server
	cd $rfolder
}

hexo_deploy()
{
	cd $rfolder &> /dev/null && cd $hfolder &> /dev/null
	if [ $? -ne 0 ]; then
		echo "error: hexo working folder do not exist, forgot to run 'recipe.sh init' or some other recipes?"
		return
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

	echo "begin hexo deploy"; hexo deploy &> /dev/null && echo "end hexo deploy"
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
					new_post
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

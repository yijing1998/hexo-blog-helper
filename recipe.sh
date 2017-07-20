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
# user settings --- end --- #

# calculate some usable variables
rfolder=`pwd`
urepo_url=${urepo%|*}
urepo_branch=${urepo#*|}
osname=`uname -o`

# enable native symbolic link for mingw in windows
if [ $osname = "Msys" ]; then
	export MSYS=winsymlinks:native
fi

# $1: target folder
# $2: repo url
# $3: repo branch
# return:
check_repo_status()
{
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
	# bad substitution, anyone tell me why
	cd $1 > /dev/null; gstatus=`git status -s`
	# folder exist but no git repo
	if [ ! $? -eq 0 ]; then
		echo 2
		return
	fi

	# now it's still in the path of $1
  # get remote name and check if working place is clean
	flag=0
	rname=""

	while read line; do
		tmp=`echo $line | grep -o "[[:space:]].*[[:space:]]"`
		if [ `echo $tmp` = $urepo_url ]; then
			rname=${line%%[[:space:]]*}
			flag=1
		fi
	done <<EOF
	`git remote -v`
EOF

	# wrong remote url
  if [ $flag -eq 0 ]; then
		echo 3
		return
	fi
	echo $rname
	echo $urepo_url
  echo $flag
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
	ln -s ../$ufolder/.hexo_config.yml _config.yml
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

hexo_server()
{
	cd $hfolder
	hexo server
	cd $rfolder
}

hexo_deploy()
{
	cd $hfolder
	hexo deploy
	cd $rfolder
}

usage()
{
	echo 'Entering usage()'
	# test
	check_repo_status $ufolder $urepo_url $urepo_branch
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
		* )
			usage
			;;
	esac
else
	usage
fi

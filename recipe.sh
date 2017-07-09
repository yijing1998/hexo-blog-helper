#!/bin/bash

# init hexo, get upstream hexo themes, create symbolic links to make hexo work properly with user's source files and config files

rfolder=`pwd`
tfolder='themes'
: ${trepos:="
	next|https://github.com/yijing1998/hexo-theme-next.git|privateblog
	landscape|https://github.com/hexojs/hexo-theme-landscape.git|master
"}
ufolder='ufiles'
urepo='urepo|https://github.com/yijing1998/hexo-ufiles.git|master'
urepopath=$ufolder/${urepo%%|*}
hfolder='hexofolder'

check_git_repo()
{
	:
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
	tar=$ufolder/${arr[0]}
	#check user repo folder's existance
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
	ln -s ../_config.yml _config.yml
	ln -s ../$tfolder themes
	ln -s ../$urepopath source
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

new_post()
{
	# existance check
	if [ ! -d $urepopath ]; then
		echo No user repo files found! Try \'recipe git urepo\'.
		return
	fi

	popath="$urepopath/_posts"
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
		echo $mnum;
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

last_post()
{
	:
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

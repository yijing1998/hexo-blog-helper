#!/bin/bash

# Set hexo working environment, including hexo platform, user blog souce file,
# varity setting files, symbolic files to tie hexo platform with existing user 
# files

rfolder=`pwd`
tfolder='themes'
: ${trepos:="
	next|https://github.com/yijing1998.abc.git|branch
	test|https://a.b.c|xyz
"}
ufolder='ufiles'
urepo='urepo|https://github.com/yijing1998|branch'
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

hexo_init()
{
	if [ -d $hfolder ]; then
		echo "Can't init hexo in local folder: $hfolder, it's already exist, please remove it manually."
	else
		hexo init $hfolder
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

# try the recipe
get_git_ufiles
get_git_themes
init_hexo
link_things

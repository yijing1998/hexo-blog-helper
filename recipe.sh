#!/bin/bash

# Set hexo working environment, including hexo platform, user blog souce file,
# varity setting files, symbolic files to tie hexo platform with existing user 
# files

hfolder='hexofolder'
tfolder='themes'
: ${tlist:="
	next|https://github.com/yijing1998.abc.git|branch
	test|https://a.b.c|xyz
"}

get_git_themes()
{
	for i in `echo ${tlist}`; do
		arr=(${i//|/ })
		if [ -d themes/${arr[0]} ]; then
			rm -rf themes/${arr[0]}
		fi
		git clone ${arr[1]} themes/${arr[0]}
		if [ $? -eq 0 ]; then
			git checkout ${arr[2]}	
		fi
	done
}

get_git_themes

echo end it

#!/usr/bin/env sh

# 确保脚本抛出遇到的错误
set -e

# 生成静态文件
echo "======begin to build======="
npm run docs:build

# 进入生成的文件夹
echo "======begin to push======="
cd docs/.vuepress/dist

# git变更及推送

git init
git add -A
git commit -m 'deploy'
git config http.sslVerify "false"

git push -f https://github.com/chenmingkong/chenmingkong.github.io.git master

cd -

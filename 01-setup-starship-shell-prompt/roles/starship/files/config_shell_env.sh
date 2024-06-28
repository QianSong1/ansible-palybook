#!/bin/bash
#
#******************************************************************************************
#Author:                QianSong
#QQ:                    xxxxxxxxxx
#Date:                  2024-06-28
#FileName:              config_shell_env.sh
#URL:                   https://github.com
#Description:           The test script
#Copyright (C):         QianSong 2024 All rights reserved
#******************************************************************************************

#######################################
# 准备 starship 环境变量配置
# Globals:
#   none
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function config_starship_env_path() {

	local shell_type
	shell_type="$(echo "${SHELL}" | awk -F "/" '{print $NF}')"
	case "${shell_type}" in
	"zsh")
		replace_shell_file "zsh"
		;;
	"bash" | "sh")
		replace_shell_file "bash"
		;;
	*)
		echo -e "ERROR"
		exit 1
		;;
	esac
}

#######################################
# 替换 starship 提示符配置
# Globals:
#   none
# Arguments:
#   $1: 传入shell类型，zsh，bash等
# Outputs:
#   none
# Returns:
#   none
#######################################
function replace_shell_file() {

	local env_file
	local shell_type

	if [ "$1" == "zsh" ]; then
		shell_type="zsh"
		env_file="${HOME}/.zshrc"
	elif [ "$1" == "bash" ]; then
		shell_type="bash"
		env_file="${HOME}/.bashrc"
	fi

	sed -ri '/(# config starship PROMPT)/d' "${env_file:?}"
	sed -ri '/(eval)(.*)(starship init)/d' "${env_file:?}"

	{
		echo "# config starship PROMPT"
		echo "eval \"\$(starship init ${shell_type})\""
	} >>"${env_file:?}"
}

#######################################
# 主函数
# Globals:
#   "$@"
# Arguments:
#   none
# Outputs:
#   none
# Returns:
#   none
#######################################
function main() {

	config_starship_env_path
}

main "$@"

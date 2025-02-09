set -x
_which_version_id ()
{
    lsb_release -a 2>/dev/null | grep Code | awk -F' ' '{print $2}' | tr -d '\n'
}

install_important_softwares()
{
    # coreutils: for realpath
    base=( tree apt-file git ranger tmux )
    shell=( zsh )
    editor=( vim neovim emacs dos2unix)
    connect=( openssh-server curl wget net-tools )
    compiler=( clang llvm clangd gcc gdb make cmake binutils autoconf automake build-essential flex bison)
    libs=( libelf-dev libssl-dev )
    search=( fd-find ripgrep silversearcher-ag )
    sudo apt-get install -y ${base[@]}\
	    ${shell[@]} \
	    ${editor[@]} \
	    ${connect[@]} \
	    ${compiler[@]} \
	    ${libs[@]} \
	    ${search[@]}
}


main() {
    echo "1. 正在替换ustc ubuntu镜像源文件"
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%d%H%M%S)
    sudo cp ustc/$(_which_version_id).sources.list /etc/apt/sources.list
    echo y | sudo apt-get update

    echo "2. 正在下载必要的软件"
    install_important_softwares
}

main


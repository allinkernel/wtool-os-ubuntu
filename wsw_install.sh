set -x
_which_version_id ()
{
    lsb_release -a 2>/dev/null | grep Code | awk -F' ' '{print $2}' | tr -d '\n'
}

install_important_softwares()
{
    # coreutils: for realpath
    base=( tree apt-file git ranger tmux bat )
    shell=( zsh )
    editor=( vim neovim emacs dos2unix)
    connect=( openssh-server curl wget net-tools )
    compiler=( clang llvm clangd gcc gdb make cmake binutils autoconf automake build-essential flex bison nasm texinfo )
    doctool=( assiidoc )
    libs=( libelf-dev libssl-dev libcurl4-openssl-dev gcc-multilib libc6-dev-i386 )
    funny=( sl neofetch )
    search=( fd-find ripgrep silversearcher-ag )
    graph=( graphviz )
    sudo apt-get install -y ${base[@]}\
        ${shell[@]} \
        ${editor[@]} \
        ${connect[@]} \
        ${compiler[@]} \
        ${libs[@]} \
        ${search[@]} \
        ${graph[@]} 
}

main() {
    echo "${step}. 正在替换ustc ubuntu镜像源文件"
    step=$((step + 1))
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%d%H%M%S)
    sudo cp ustc/$(_which_version_id).sources.list /etc/apt/sources.list
    echo y | sudo apt-get update

    echo "${step}. 正在下载必要的软件"
    step=$((step + 2))
    install_important_softwares
}

main


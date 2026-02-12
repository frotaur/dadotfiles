#!/bin/bash
set -euo pipefail
USAGE=$(cat <<-END
    Usage: ./install.sh [OPTION]
    Install dotfile dependencies on linux


    If OPTIONS are passed they will be installed
    with apt if on linux or brew if on OSX
END
)

force="false"
while (( "$#" )); do
    case "$1" in
        -h|--help)
            echo "$USAGE" && exit 1 ;;
        --f|--force)
            force="true"
            shift ;;
        --) # end argument parsing
            shift && break ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2 && exit 1 ;;
        *) # positional arguments - stop parsing flags
            break ;;
    esac
done

operating_system="$(uname -s)"
case "${operating_system}" in
    Linux*)     machine=Linux;;
    *)          machine="UNKNOWN:${operating_system}"
                echo "Error: Unsupported operating system ${operating_system}" && exit 1
esac

# Installing on linux with apt
if [ $machine == "Linux" ]; then
    DOT_DIR=$(dirname $(realpath $0))
    sudo apt-get update -y
    sudo apt-get install -y zsh
    sudo apt-get install -y tmux
    sudo apt-get install -y less nano htop ncdu nvtop lsof rsync jq pkg-config
    curl -LsSf https://astral.sh/uv/install.sh | sh

    sudo apt-get install -y ripgrep
    sudo apt-get install -y direnv

    if [ -x ~/.linuxbrew/bin/brew ]; then
        echo "Homebrew already installed, skipping..."
    else
        git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew
        mkdir -p ~/.linuxbrew/bin
        ln -s ../Homebrew/bin/brew ~/.linuxbrew/bin/brew
        ~/.linuxbrew/bin/brew update --force --quiet
    fi

    eval "$(~/.linuxbrew/bin/brew shellenv zsh)"
    
    brew install dust jless

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env" 
    cargo install code2prompt
    brew install peco

    # sudo apt-get install -y nodejs For now cluster already has node and npm, so no need
    # npm comes bundled with nodejs from nodesource, no separate installation needed
fi
# Setting up oh my zsh and oh my zsh plugins
ZSH=~/.oh-my-zsh
ZSH_CUSTOM=$ZSH/custom
if [ -d "$ZSH" ] && [ "$force" = "false" ]; then
    echo "oh-my-zsh already installed. Skipping download. Pass --force to reinstall."
else
    echo " --------- INSTALLING DEPENDENCIES ⏳ ----------- "
    rm -rf $ZSH
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    git clone https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k

    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    git clone https://github.com/zsh-users/zsh-completions \
        ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions

    git clone https://github.com/zsh-users/zsh-history-substring-search \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
    git clone https://github.com/jimeh/tmux-themepack.git ~/.tmux-themepack

    # git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    # yes | ~/.fzf/install

    echo " --------- INSTALLED SUCCESSFULLY ✅ ----------- "
    echo " --------- NOW RUN ./deploy.sh [OPTION] -------- "
fi


echo " --------- INSTALLING EXTRAS ⏳ ----------- "
if command -v cargo &> /dev/null; then
    NO_ASK_OPENAI_API_KEY=1 zsh -c "$(curl -fsSL https://raw.githubusercontent.com/hmirin/ask.sh/main/install.sh)"
fi

echo "Setting up git"
email=${1:-"frotaur@hotmail.co.uk"}
name=${2:-"Vassilis Papadopoulos"}
github_url=${3:-""}

# 0) Setup git
git config --global user.email "$email"
git config --global user.name "$name"

echo "Installing claude cli"
curl -fsSL https://claude.ai/install.sh | bash
#!/bin/bash
set -euo pipefail
USAGE=$(cat <<-END
    Usage: ./deploy.sh
END
)

export DOT_DIR=$(dirname $(realpath $0))

while (( "$#" )); do
    case "$1" in
        -h|--help)
            echo "$USAGE" && exit 1 ;;
        --) # end argument parsing
            shift && break ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2 && exit 1 ;;
    esac
done

echo "deploying on machine..."

# Tmux setup
echo "source $DOT_DIR/config/tmux.conf" > $HOME/.tmux.conf

# zshrc setup
echo "source $DOT_DIR/config/zshrc.sh" > $HOME/.zshrc

echo "changing default shell to zsh"
sudo chsh -s $(which zsh)

cp -r $DOT_DIR/.claude $HOME/
zsh

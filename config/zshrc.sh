CONFIG_DIR=$(dirname $(realpath ${(%):-%x}))
DOT_DIR=$CONFIG_DIR/..

if [ ! -f "$HOME/.anthropic_key" ]; then
  echo "Warning: $HOME/.anthropic_key file not found, please create and put your Anthropic API key in it to use related features."
fi
if [ -f "$HOME/.anthropic_key" ]; then
  export ANTHROPIC_API_KEY=$(cat $HOME/.anthropic_key)
  if command -v ask-sh &> /dev/null; then
    export ASK_SH_ANTHROPIC_API_KEY=$(cat $HOME/.anthropic_key)
    export ASK_SH_LLM_PROVIDER=anthropic
    export ASK_SH_ANTHROPIC_MODEL=claude-haiku-4-5-20251001
    eval "$(ask-sh --init)"
  fi
fi

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ss -a | grep -q "$SSH_AUTH_SOCK"; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK" -s)" > /dev/null
fi
ssh-add -q ~/.ssh/id_ed25519 2>/dev/null

# Instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export TERM="xterm-256color"

ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH=$HOME/.oh-my-zsh

plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)

source $ZSH/oh-my-zsh.sh
source $CONFIG_DIR/aliases.sh
source $CONFIG_DIR/p10k.zsh
source $CONFIG_DIR/extras.sh

# for uv
if [ -d "$HOME/.local/bin" ]; then
  source $HOME/.local/bin/env
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
if [ -d "$HOME/.cargo" ]; then
  . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi


if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi

eval "$(~/.linuxbrew/bin/brew shellenv zsh)"

# direnv hook for automatic .env loading
eval "$(direnv hook zsh)"
eval "$(ask-sh --init)"
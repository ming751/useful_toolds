# Useful Toolds interactive defaults. Later user .zshrc settings take precedence.
[[ -o interactive ]] || return
[[ -z ${_USEFUL_TOOLDS_SHELL_LOADED:-} ]] || return
typeset -g _USEFUL_TOOLDS_SHELL_LOADED=1
typeset -U path
path=("$HOME/.local/bin" $path)
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE HIST_REDUCE_BLANKS AUTO_CD INTERACTIVE_COMMENTS
unsetopt BEEP
bindkey -e
zmodload zsh/complist
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
[[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
[[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alh --color=auto'
alias la='ls -A --color=auto'
(( $+commands[eza] )) && alias ll='eza -lah --group-directories-first' tree='eza --tree'
(( $+commands[batcat] )) && alias bat='batcat'
(( $+commands[fdfind] )) && alias fd='fdfind'
mkcd() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1"; }

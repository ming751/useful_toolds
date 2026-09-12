[[ -o interactive ]] || return
if (( ! $+functions[_zsh_autosuggest_start] )) && [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
# Load after widget definitions; do not load again when Oh My Zsh already did.
if (( ! $+functions[_zsh_highlight] )) && [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

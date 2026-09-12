[[ -o interactive ]] || return
if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
else
    PROMPT='%F{cyan}%2~%f %(?.%F{green}.%F{red})❯%f '
fi

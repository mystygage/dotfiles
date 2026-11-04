# Setup fzf
# ---------
(( $+commands[fzf] )) || return 0

# Auto-completion and key bindings
# --------------------------------
for _fzf_dir in "${HOMEBREW_PREFIX}/opt/fzf/shell" /usr/share/doc/fzf/examples /usr/share/fzf; do
  if [[ -r "${_fzf_dir}/key-bindings.zsh" ]]; then
    [[ $- == *i* ]] && source "${_fzf_dir}/completion.zsh" 2> /dev/null
    source "${_fzf_dir}/key-bindings.zsh"
    break
  fi
done
unset _fzf_dir

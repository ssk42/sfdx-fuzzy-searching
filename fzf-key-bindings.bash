#!/usr/bin/env bash
#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/ key-bindings.bash
#
# - $FZF_TMUX_OPTS
# - $FZF_CTRL_T_COMMAND
# - $FZF_CTRL_T_OPTS
# - $FZF_CTRL_R_OPTS
# - $FZF_ALT_C_COMMAND
# - $FZF_ALT_C_OPTS

# Key bindings
# ------------
__fzf_select__() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" $(__fzfcmd) -m "$@" | while read -r item; do
    printf '%q ' "$item"
  done
  echo
}

if [[ $- =~ i ]]; then

__fzfcmd() {
  [ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

fzf-file-widget() {
  local selected="$(__fzf_select__)"
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
}

__fzf_cd__() {
  local cmd dir
  cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m) && printf 'cd %q' "$dir"
}

__fzf_history__() {
  local output
  output=$(
    builtin fc -lnr -2147483648 |
      last_hist=$(HISTTIMEFORMAT='' builtin history 1) perl -n -l0 -e 'BEGIN { getc; $/ = "\n\t"; $HISTCMD = $ENV{last_hist} + 1 } s/^[ *]//; print $HISTCMD - $. . "\t$_" if !$seen{$_}++' |
      FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort,ctrl-z:ignore $FZF_CTRL_R_OPTS +m --read0" $(__fzfcmd) --query "$READLINE_LINE"
  ) || return
  READLINE_LINE=${output#*$'\t'}
  if [ -z "$READLINE_POINT" ]; then
    echo "$READLINE_LINE"
  else
    READLINE_POINT=0x7fffffff
  fi
}

__fzf_sfdx_flags__(){
  local selected="$1"
  local fullcmd=""
  for i in "${@:2}"
  do fullcmd+=" ${i//\"/\\\\\\\"}" #we have to triple escape the double quotes here as it will be used within double quotes again in the command below
  done
  local ret=`cat ~/.sfdxcommands.json | jq -r ".[] | select(.id==\"$selected\") | .flags | keys[]" | $(__fzfcmd) -m --bind 'ctrl-z:ignore,alt-j:preview-down,alt-k:preview-up' --preview='cat ~/.sfdxcommands.json | jq -r ".[] | select(.id==\"'$selected'\") | .flags | to_entries[] | select (.key==\""{}"\") | [\"Command:\n'"$fullcmd"'\n\",\"Flag Description:\",.value][]"' --preview-window='right:wrap'`
  echo "${ret//$'\n'/ --}"
}

fzf-sfdx(){
  local fullcmd="$READLINE_LINE"
  local cmd="$(echo $fullcmd | awk '{print $1}')"
  local subcmd="$(echo $fullcmd | awk '{print $2}')"
  local match="$(cat ~/.sfdxcommands.json | jq -r '.[] | select(.id=="'$subcmd'")')"
  if [[ "$cmd" = "sfdx" && "$match" != "" ]]
  then
    local flag="$(__fzf_sfdx_flags__ $subcmd $fullcmd)"
    if [[ "$flag" != "" ]]
    then
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}--$flag${READLINE_LINE:$READLINE_POINT}"
      READLINE_POINT=$(( READLINE_POINT + ${#flag} + 3 ))
      #READLINE_LINE="$fullcmd --$flag"
      #READLINE_POINT=$(( ${#fullcmd} + ${#flag} + 3 ))
    fi
  elif [[ "$cmd" == "sfdx" || "$cmd" == "" ]]
  then
    local querystr=""
    if [[ "$subcmd" != "" ]]; then
     querystr="--query $subcmd" 
    fi
    local selected="$(cat ~/.sfdxcommands.json | jq -r '.[].id' | $(__fzfcmd) +m --bind 'ctrl-z:ignore,alt-j:preview-down,alt-k:preview-up' --preview='cat ~/.sfdxcommands.json | jq -r ".[] | select (.id==\""{}"\") | [\"\nDescription:\n \"+.description,\"\nUsage:\n \"+select(has(\"usage\")).usage, \"\nExamples:\n \"+(select(has(\"examples\")).examples|join(\"\n\"))][]"' --preview-window='right:wrap' $querystr)"
    if [[ "$selected" != "" ]]; then
      READLINE_LINE="sfdx $selected"
      READLINE_POINT=$(( 5 + ${#selected} ))
    fi
  fi
}

fzf-sfdx-alias(){                                                                                                                                                            
  local selected="$(cat ~/.sfdxaliases | $(__fzfcmd) | awk '{print $2}')"                                                   
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"                               
  READLINE_POINT=$(( READLINE_POINT + ${#selected} ))                                                                       
}	

# Required to refresh the prompt after fzf
bind -m emacs-standard '"\er": redraw-current-line'

bind -m vi-command '"\C-z": emacs-editing-mode'
bind -m vi-insert '"\C-z": emacs-editing-mode'
bind -m emacs-standard '"\C-z": vi-editing-mode'

if (( BASH_VERSINFO[0] < 4 )); then
  # CTRL-T - Paste the selected file path into the command line
  bind -m emacs-standard '"\C-t": " \C-b\C-k \C-u`__fzf_select__`\e\C-e\er\C-a\C-y\C-h\C-e\e \C-y\ey\C-x\C-x\C-f"'
  bind -m vi-command '"\C-t": "\C-z\C-t\C-z"'
  bind -m vi-insert '"\C-t": "\C-z\C-t\C-z"'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard '"\C-r": "\C-e \C-u\C-y\ey\C-u"$(__fzf_history__)"\e\C-e\er"'
  bind -m vi-command '"\C-r": "\C-z\C-r\C-z"'
  bind -m vi-insert '"\C-r": "\C-z\C-r\C-z"'
else
  # CTRL-T - Paste the selected file path into the command line
  bind -m emacs-standard -x '"\C-f": fzf-file-widget'
  bind -m vi-command -x '"\C-f": fzf-file-widget'
  bind -m vi-insert -x '"\C-f": fzf-file-widget'

  # CTRL-R - Paste the selected command from history into the command line
  bind -m emacs-standard -x '"\C-r": __fzf_history__'
  bind -m vi-command -x '"\C-r": __fzf_history__'
  bind -m vi-insert -x '"\C-r": __fzf_history__'

  # CTRL-e - Search for and paste the selected sfdx command onto the command line
  bind -m emacs-standard -x '"\C-e": fzf-sfdx'
  bind -m vi-command -x '"\C-e": fzf-sfdx'
  bind -m vi-insert -x '"\C-e": fzf-sfdx'

fi

# ALT-C - cd into the selected directory
bind -m emacs-standard '"\ec": " \C-b\C-k \C-u`__fzf_cd__`\e\C-e\er\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d"'
bind -m vi-command '"\ec": "\C-z\ec\C-z"'
bind -m vi-insert '"\ec": "\C-z\ec\C-z"'

fi

# CTRL-n - Search for and paste the selected sfdx org from the authorized orglist onto the command line               
  bind -m emacs-standard -x '"\C-n": fzf-sfdx-alias'                                                                    
  bind -m vi-command -x '"\C-n": fzf-sfdx-alias'                                                                        
  bind -m vi-insert -x '"\C-n": fzf-sfdx-alias'






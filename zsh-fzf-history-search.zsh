# do nothing if fzf is not installed
(( ! $+commands[fzf] )) && return

# Bind for fzf history search
(( ! ${+ZSH_FZF_HISTORY_SEARCH_BIND} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_BIND='^r'

# Args for fzf
(( ! ${+ZSH_FZF_HISTORY_SEARCH_FZF_ARGS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_FZF_ARGS='+s +m -x -e'

# Extra args for fzf
(( ! ${+ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS=''

# Cursor to end-of-line
(( ! ${+ZSH_FZF_HISTORY_SEARCH_END_OF_LINE} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_END_OF_LINE=''

# Include event numbers
(( ! ${+ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS=1

# Include full date timestamps in ISO8601 `yyyy-mm-dd hh:mm' format
(( ! ${+ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH=1

# Remove duplicate entries in history
(( ! ${+ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES=''

# Define fzf query, when $BUFFER is not empty
(( ! ${+ZSH_FZF_HISTORY_SEARCH_FZF_QUERY_PREFIX} )) &&
typeset -g ZSH_FZF_HISTORY_SEARCH_FZF_QUERY_PREFIX=''
fzf_history_search() {
  setopt extendedglob

  # $history maps event numbers to the complete history entry,
  # including embedded newlines.
  zmodload -F zsh/parameter p:history 2>/dev/null || return 1

  local selected selected_event
  local raw_event event date time rest command display
  local -A seen
  local -a query_args

  if (( $#BUFFER )); then
    query_args=(
      -q "${ZSH_FZF_HISTORY_SEARCH_FZF_QUERY_PREFIX}${BUFFER}"
    )
  fi

  selected="$(
    {
      #
      # Keep using fc:
      #   - preserves the plugin's ordering
      #   - gives us event numbers
      #   - gives us the ISO8601 timestamp
      #
      # But do NOT use fc's command text. It is not safe for
      # distinguishing multiline history entries.
      #
      fc -li -1 0 |
      while IFS=' ' read -r raw_event date time rest; do
        # SHARE_HISTORY can display foreign events as "123*".
        event="${raw_event%\*}"

        # Ignore continuation lines from fc output.
        [[ "$event" == <-> ]] || continue
        [[ "$date" == <->-<->-<-> ]] || continue
        [[ "$time" == <->:<-> ]] || continue

        # The actual complete command comes from zsh.
        (( ${+history[$event]} )) || continue
        command="${history[$event]}"

        display=''

        if (( ZSH_FZF_HISTORY_SEARCH_EVENT_NUMBERS )); then
          display+="${event} "
        fi

        if (( ZSH_FZF_HISTORY_SEARCH_DATES_IN_SEARCH )); then
          display+="${date} ${time} "
        fi

        display+="${command}"

        #
        # Match the plugin's existing duplicate-removal semantics:
        # deduplicate exactly what would be displayed/searched.
        #
        if [[ -n "$ZSH_FZF_HISTORY_SEARCH_REMOVE_DUPLICATES" ]]; then
          (( ${+seen[$display]} )) && continue
          seen[$display]=1
        fi

        #
        # Internal format:
        #
        #   event-number<TAB>display text<NUL>
        #
        # NUL is important: embedded newlines belong to the command,
        # rather than separating fzf entries.
        #
        printf '%s\0' "${event}"$'\t'"${display}"
      done
    } |
      fzf \
        ${=ZSH_FZF_HISTORY_SEARCH_FZF_ARGS} \
        ${=ZSH_FZF_HISTORY_SEARCH_FZF_EXTRA_ARGS} \
        --read0 \
        "${query_args[@]}"
  )"

  local ret=$?

  if [[ -n "$selected" ]]; then
    #
    # fzf returns:
    #
    #   event-number<TAB>...
    #
    # We only need the event number. Let ZLE retrieve the original
    # history event itself, so multiline commands are restored exactly.
    #
    selected_event="${selected%%$'\t'*}"

    if [[ "$selected_event" == <-> ]]; then
      zle vi-fetch-history -n "$selected_event"

      if [[ -n "$ZSH_FZF_HISTORY_SEARCH_END_OF_LINE" ]]; then
        zle end-of-line
      fi
    fi
  fi

  zle reset-prompt
  return $ret
}

autoload fzf_history_search
zle -N fzf_history_search

bindkey $ZSH_FZF_HISTORY_SEARCH_BIND fzf_history_search
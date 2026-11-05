# glyph Glyph Progress: long terminal commands light the bottom Glyph bar while they run; when one ends the bar
# flashes (red on failure), and commands of 10 s or more also land in the island. glyph decides the timing; this only
# reports start/end over Quickshell IPC, in the background so the prompt never waits.
# Turn on:  ln -s ~/.config/quickshell/glyph/term/glyph-progress.fish ~/.config/fish/conf.d/   (off: delete the link)
status is-interactive; or return

# full-screen and interactive tools: their "duration" is just how long you used them
set -g __glyph_progress_skip nvim vim vi hx helix nano micro less more man htop btop top ssh mosh claude tmux zellij \
    yazi lazygit fzf watch tig ranger nnn lf strata

function __glyph_progress_start --on-event fish_preexec
    set -l words (string split -n ' ' -- $argv[1])
    set -l cmd $words[1]
    test "$cmd" = sudo; and set cmd $words[2]
    contains -- "$cmd" $__glyph_progress_skip; and return
    set -g __glyph_progress_on 1
    command qs ipc -p ~/.config/quickshell/glyph call progress start $fish_pid (string shorten -m 60 -- $argv[1]) >/dev/null 2>&1 &
    disown 2>/dev/null
end

function __glyph_progress_end --on-event fish_postexec
    set -l code $status
    set -q __glyph_progress_on; or return
    set -e __glyph_progress_on
    command qs ipc -p ~/.config/quickshell/glyph call progress end $fish_pid $code >/dev/null 2>&1 &
    disown 2>/dev/null
end

#!/bin/bash
# the update window from System → about: the rice first, then the system. Sudo locks the account after repeated failures and then rejects even the right password with
# «Sorry, try again», so say that plainly instead of asking.
# shortcut: assumes faillock's defaults (deny=3, unlock_time=600), read /etc/security/faillock.conf if someone needs other limits
since=$(date -d '-10 min' '+%F %T')
failed=$(faillock --user "$USER" 2>/dev/null | awk -v since="$since" '$NF == "V" && $1 " " $2 >= since' | wc -l)
if [ "$failed" -ge 3 ]; then
    printf 'Sudo is locked after %s failed password attempts in the last 10 minutes.\n' "$failed"
    printf 'Your password is fine, but any attempt fails until the lock ends. It ends by itself within 10 minutes.\nThen press update again.\n'
else
    here=$(dirname "$(readlink -f "$0")")
    repo=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$repo" ]; then
        printf '== the rice\n'
        "$repo/install.sh" --update || printf 'The rice did not update, see above. Carrying on with the system.\n'
        printf '\n== the system\n'
    fi
    helper=$(command -v yay || command -v paru)
    if [ -n "$helper" ]; then "$helper" -Syu; else sudo pacman -Syu; fi
fi
printf '\ndone · press enter '
read -r _

#!/bin/bash

echo ""
echo "=== Environment Info for Normal Users, 'sshd', and 'root' ==="
echo ""

# Read all users from /etc/passwd
while IFS=: read -r username _ uid gid _ home _; do
    # Include normal users (UID >= 1000), 'sshd', and 'root'
    if [ "$uid" -ge 1000 ] || [ "$username" == "sshd" ] || [ "$username" == "root" ]; then
        echo "User: $username"
        echo "USER_ID: $uid"
        echo "USER_GROUP: $(getent group $gid | cut -d: -f1)"
        echo "USER_GROUP_ID: $gid"

        # Git configuration, if available
        if [ -f "$home/.gitconfig" ]; then
            git_user=$(git config --global --file "$home/.gitconfig" user.name 2>/dev/null)
            git_email=$(git config --global --file "$home/.gitconfig" user.email 2>/dev/null)
            echo "GIT_USER: ${git_user:-Not configured}"
            echo "GIT_EMAIL: ${git_email:-Not configured}"
        fi

        # Timezone, Locale, PATH, DISPLAY, and TERM
        echo "TIMEZONE: $(cat /etc/timezone)"
        
        if [ -d "$home" ]; then
            locale_lang=$(LANG=$LANG HOME=$home bash -c 'echo $LANG' 2>/dev/null)
            user_path=$(HOME=$home bash -c 'echo $PATH' 2>/dev/null)
            display_var=$(HOME=$home bash -c 'echo $DISPLAY' 2>/dev/null)
            term_var=$(HOME=$home bash -c 'echo $TERM' 2>/dev/null)
            echo "LOCALE_LANG: ${locale_lang:-Not set}"
            echo "PATH: ${user_path:-Not set}"
            echo "DISPLAY: ${display_var:-Not set}"
            echo "TERM: ${term_var:-Not set}"
            echo "USER_HOME:"
            # Limit tree output to 6 levels, max 3 directories per level
            tree -L 6 -d "$home" | awk '{count[$1]++; if (count[$1] <= 3) print}'
        fi
        echo "-------------"
    fi
done < /etc/passwd

echo "=== End of Environment Info ==="

#!/usr/bin/env bash
# drive_setup.sh <name> <cols> <rows> <mode: piped|interactive>
# Runs `bin/fm-telegram.py setup` as an operator would, in a fresh bash pane of the
# given size on the lab's private tmux socket, then captures ONLY the visible screen
# (capture-pane -e keeps the SGR colours), renders it on a light and a dark theme,
# and decodes each render with zbarimg the way a phone camera reads the screen.
set -u
# PROMPT_PS1 overrides the pane's shell prompt (e.g. a two-line prompt); it must end in 'operator$ '.
name=$1 cols=$2 rows=$3 mode=$4
LAB=$(cat /tmp/fm-round3-lab-path)
E=/home/nathanjgaul/.no-mistakes/evidence/01M4VEQBXY5E40EYNFHPFTNPK8/round3
T() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab "$@"; }
T kill-session -t "$name" 2>/dev/null
T new-session -d -s "$name" -x "$cols" -y "$rows" -c "$PWD" "env -i HOME=\$HOME PATH=\$PATH TERM=tmux-256color PS1=\"${PROMPT_PS1:-operator\$ }\" bash --norc --noprofile"
T set-option -t "$name" window-size manual >/dev/null
T resize-window -t "$name" -x "$cols" -y "$rows"
sleep 0.5
T send-keys -t "$name" "clear" Enter
sleep 0.3
if [ "$mode" = piped ]; then
  T send-keys -t "$name" "$E/lab-tools/fm bin/fm-telegram.py setup < $LAB/api/token" Enter
else
  T send-keys -t "$name" "$E/lab-tools/fm bin/fm-telegram.py setup" Enter
  for _ in $(seq 50); do T capture-pane -p -t "$name" | grep -q 'Telegram bot token:' && break; sleep 0.1; done
  T capture-pane -p -t "$name" > "$E/$name-prompt-before-token.txt"
  # Type the token at the non-echoing getpass prompt, as the operator would.
  T send-keys -t "$name" -l "$(cat "$LAB/api/token")"
  sleep 0.3
  T capture-pane -p -t "$name" > "$E/$name-prompt-after-typing-token.txt"
  T send-keys -t "$name" Enter
fi
for _ in $(seq 100); do T capture-pane -p -t "$name" | tail -n 1 | grep -q '^operator\$ $' && T capture-pane -p -t "$name" | grep -q '▀' && break; sleep 0.1; done
sleep 0.3
T display-message -p -t "$name" 'pane size #{pane_width}x#{pane_height}' > "$E/$name-pane-size.txt"
T capture-pane -e -p -t "$name" > "$E/$name-visible.ansi"
T capture-pane -p -t "$name" > "$E/$name-visible.txt"
for theme in light dark; do
  python3 -I "$E/lab-tools/render_ansi.py" "$E/$name-visible.ansi" "$E/$name-$theme.png" "$theme"
  if out=$(zbarimg -q --raw "$E/$name-$theme.png" 2>&1); then echo "$name $theme DECODED $out"; else echo "$name $theme NO DECODE (zbarimg exit $?)"; fi
done

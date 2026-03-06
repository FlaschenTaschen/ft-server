#!/bin/zsh

send-text -g45x5 -l1 -f "$HOME/ft/fonts/5x5.bdf" "One" &
sleep 1
send-text -g45x25 -l2 -f "$HOME/ft/fonts/5x5.bdf" "Two" &
sleep 1
send-text -g45x35 -l3 -f "$HOME/ft/fonts/5x5.bdf" "Three" &
sleep 1
send-text -g45x45 -l4 -f "$HOME/ft/fonts/5x5.bdf" "Four" &
sleep 1
send-text -g45x55 -l5 -f "$HOME/ft/fonts/5x5.bdf" "Five" &

sleep 3; echo "kill send-text"; pkill -9 send-text

# echo "clear all"
sleep 2; black -g45x35 all

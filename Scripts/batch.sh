#!/bin/zsh

./perftest.sh phase5-pass1
sleep 3

./perftest.sh phase5-pass2
sleep 3

./perftest.sh phase5-pass3
sleep 3

echo "Done with baseline collection"

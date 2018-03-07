#!/bin/bash

# Make sure there isn't a Claymore session already running
tmux kill-session -t Claymore

# Run it
tmux new-session -d -s Claymore ~/claymore/ethdcrminer64

# Wait until the session gets killed
while tmux has-session -t Claymore; do
    sleep 1
done

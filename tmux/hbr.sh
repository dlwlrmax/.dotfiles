#!/bin/bash

SESH="background"

tmux has-session -t $SESH 2>/dev/null

if [ $? != 0 ]; then
  tmux new-session -d -s $SESH -n "vuejs"
  # cd to vuejs project and run npm run dev
  tmux send-keys -t $SESH:vuejs "z vuejs" C-m
  tmux send-keys -t $SESH:vuejs "npm run dev" C-m

  # cd to laravel project and run php artisan serve --port=8888
  tmux new-window -t $SESH: -n "laravel"
  tmux send-keys -t $SESH:laravel "z api" C-m
  tmux send-keys -t $SESH:laravel "php artisan serve --port=8888" C-m
fi

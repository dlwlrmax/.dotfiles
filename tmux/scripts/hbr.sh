
#!/bin/bash
SESH="BACKGROUND"

tmux has-session -t $SESH 2>/dev/null

if [ $? != 0 ]; then
  # create a new session
  tmux new-session -d -s $SESH -n "vuejs"
  # Check if 'z' command is available
  if command -v z &>/dev/null; then
    # cd to vuejs project and run npm run dev
    tmux send-keys -t $SESH:vuejs "z vuejs" C-m
  else
    tmux send-keys -t $SESH:vuejs "cd ~/gitlab/reload/daotao.binggo.vn.vuejs" C-m
  fi
  tmux send-keys -t $SESH:vuejs "clear" C-m
  tmux send-keys -t $SESH:vuejs "npm run dev" C-m
  tmux select-pane -T "Vue.js Dev" -t $SESH:vuejs

  # cd to laravel project and run php artisan serve --port=8888
  tmux new-window -t $SESH: -n "laravel"
  if command -v z &>/dev/null; then
    tmux send-keys -t $SESH:laravel "z api" C-m
  else
    tmux send-keys -t $SESH:laravel "cd ~/gitlab/reload/api-daotao.binggo.vn" C-m
  fi
  tmux send-keys -t $SESH:laravel "clear" C-m
  tmux send-keys -t $SESH:laravel "php artisan serve --port=8888" C-m
  tmux select-pane -T "Laravel Dev" -t $SESH:laravel
fi

CODE="CODE"

tmux has-session -t $CODE 2>/dev/null
if [ $? != 0 ]; then
  tmux new-session -d -s $CODE -n "vuejs"
  tmux send-keys -t $CODE:vuejs "cd ~/gitlab/reload/daotao.binggo.vn.vuejs" C-m
  tmux send-keys -t $CODE:vuejs "clear" C-m
  tmux select-pane -T "Vue.js Code" -t $CODE:vuejs

  tmux new-window -t $CODE: -n "api"
  tmux send-keys -t $CODE:api "cd ~/gitlab/reload/api-daotao.binggo.vn" C-m
  tmux send-keys -t $CODE:api "clear" C-m
  tmux select-pane -T "API Code" -t $CODE:api

  tmux new-window -t $CODE: -n "erp"
  tmux send-keys -t $CODE:erp "cd ~/gitlab/erp.langmaster.vn" C-m
  tmux send-keys -t $CODE:erp "clear" C-m
  tmux select-pane -T "ERP Code" -t $CODE:erp

  tmux select-window -t $CODE:vuejs
  tmux attach-session -t $CODE
fi

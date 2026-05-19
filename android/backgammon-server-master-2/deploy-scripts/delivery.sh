branch="dev"
export -a "$(cat ../.env)"
ssh "$SERVER_HOST" "
  rm -rf ~/backend_server
  mkdir -p ~/backend_server && cd ~/backend_server
  echo '---- cloning repo ----'
  git clone git@github.com:haleen24/backgammon-server.git
  echo '---- repo cloned ----'
  cd backgammon-server
  git checkout $branch
  git status
  git pull
  sleep 5
"
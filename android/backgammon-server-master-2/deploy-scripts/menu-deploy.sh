label=narde-menu
export -a "$(cat ../.env)"
ssh "$SERVER_HOST" "
  echo '---- cd in folder'
  cd ~/backend_server/backgammon-server/menu
  echo '---- build jar'
  sudo chmod +x gradlew
  ./gradlew clean build -x test --no-daemon
  echo '---- jar built'
  echo '---- deploy'
  bash ./../deploy-scripts/deploy.sh $label
  echo '---- deployed'
"
exec $SHELL
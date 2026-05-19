export -a "$(cat ../.env)"
ssh "$SERVER_HOST" "
  docker run -d -p 5000:5000 --name local-registry registry:2
"

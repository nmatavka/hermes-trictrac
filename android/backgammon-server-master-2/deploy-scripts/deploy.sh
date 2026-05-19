kubectl delete deploy "$1"
sudo docker image rm "$1" --force
sudo docker build -t "$1" .
sudo docker tag "$1":latest localhost:5000/"$1":latest
sudo docker push localhost:5000/"$1":latest
kubectl apply -f "../k8s/$1".yaml
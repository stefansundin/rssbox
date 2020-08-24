First create a namespace and switch to it:
```
# you can skip this if you want to use the default namespace
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/namespace.yml
kubectl config set-context --current --namespace=rssbox
```

Then create the redis service:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/redis.yml
```

Then create the configmap:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/configmap.yml

# to update, run:
kubectl edit configmap/rssbox
```

Then create the app itself:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/rssbox.yml
```

If you want to use an ingress:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/service.yml

# ingress without tls:
wget https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/ingress.yml
vim ingress.yml
kubectl apply -f ingress.yml

# ingress with tls:
wget https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/ingress-tls.yml
vim ingress-tls.yml
kubectl apply -f ingress-tls.yml
```

If you want to use a NodePort instead:
```
# NodePort 3000
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/service-nodeport.yml
```

You can access the app using `kubectl proxy` at http://localhost:8001/api/v1/namespaces/rssbox/services/rssbox:/proxy/.

# Misc

To force pods to be recreated, e.g. after updating the configmap, or to deploy the latest docker image, run:
```
kubectl patch deployment rssbox -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"force-restart\":\"$(date +%s)\"}}}}}"
```

# Minikube

```
minikube addons enable ingress
```

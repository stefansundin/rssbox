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

Then use `configmap.yml` to create the configmap:
```
kubectl create --edit -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/configmap.yml

# to update later, run:
kubectl edit configmap/rssbox
```

Finally create the app itself:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/rssbox.yml
```

It should then be available on NodePort 30000.

You can access the app using `kubectl proxy` at http://localhost:8001/api/v1/namespaces/rssbox/services/rssbox:/proxy/.

You can use `ingress.yml` (or `ingress-tls.yml`) to create an nginx ingress:
```
kubectl create --edit -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/ingress.yml

# or:
kubectl create --edit -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/ingress-tls.yml
```

# Misc

To force pods to be recreated, e.g. after updating the configmap, or to deploy the latest docker image, run:
```
kubectl patch deployment rssbox -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"force-restart\":\"$(date +%s)\"}}}}}"
```

# Minikube

```
minikube addons enable ingress
```

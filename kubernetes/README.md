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

Then update `configmap.yml` and create the configmap:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/configmap.yml
```

Finally create the app itself:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/rssbox.yml
```

It should then be available on NodePort 30000.

Alternatively, you can access the app using `kubectl proxy` at http://localhost:8001/api/v1/namespaces/rssbox/services/rssbox:/proxy/.

You can also update `ingress.yml` and create an nginx ingress:
```
kubectl apply -f https://raw.githubusercontent.com/stefansundin/rssbox/master/kubernetes/ingress.yml
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

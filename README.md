# experimental-argocd

Deploy ArgoCD on a Kind cluster and enable it to deploy applications from a local Git repository.

## Usage

Create a [Kind](https://kind.sigs.k8s.io/) cluster, deploy [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) and [Gitea](https://about.gitea.com/):

``` shell
make
```

Login to Gitea:  http://localhost:3000/ (username and password are giteaadmin).

Login to ArgoCD: http://localhost:3010/ (username is admin, get password with `./argocd.sh init`).

### Push changes

The application repository is `tmp/test-repo`.

``` shell
cd tmp/test-repo
# modify, commit changes
../../gitea.sh git push
```

### Change `Application`

To apply [Application](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/):

``` shell
make apply-repo
```

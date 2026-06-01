CLUSTER := experimental-argocd
KIND_IMAGE := kindest/node:v1.35.0
GITEA_NAMESPACE := gitea
GITEA_REPO := test-repo
GITEA_REPO_LOCAL := tmp/test-repo
GITEA_ADMIN_USERNAME := admin
GITEA_ADMIN_PASSWORD := admin
GITEA_ADMIN_EMAIL := admin@example.com
ARGOCD_VERSION := v3.4.2
ARGOCD_NAMESPACE := argocd

.PHONY: default
default: create-cluster gitea argocd

.PHONY: recreate
recreate: delete-cluster default

.PHONY: create-cluster
create-cluster:
	kind create cluster --name "$(CLUSTER)" --config cluster.yml --image "$(KIND_IMAGE)"

.PHONY: delete-cluster
delete-cluster:
	kind delete cluster --name "$(CLUSTER)" || true

.PHONY: recreate-gitea
redeploy-gitea: delete-gitea gitea

.PHONY: gitea
gitea: deploy-gitea init-gitea create-repo

.PHONY: delete-gitea
delete-gitea:
	kubectl delete -n "$(GITEA_NAMESPACE)" -k gitea

.PHONY: deploy-gitea
deploy-gitea:
	kubectl create namespace "$(GITEA_NAMESPACE)" || true
	kubectl -n "$(GITEA_NAMESPACE)" apply -k gitea
	kubectl -n "$(GITEA_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/gitea
	kubectl -n "$(GITEA_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/tea
	@echo Login to http://localhost:3000/ with username $(GITEA_ADMIN_USERNAME) and password $(GITEA_ADMIN_PASSWORD)

KEY := tmp/admin.key
PUBKEY := tmp/admin.key.pub

.PHONY: gitea-init
init-gitea:
	mkdir -p tmp
	rm -f "$(KEY)" "$(PUBKEY)"
	ssh-keygen -t ed25519 -C "$(GITEA_ADMIN_EMAIL)" -f "$(KEY)" -N ""
	kubectl cp "$(PUBKEY)" "gitea/$(shell ./gitea.sh pod):/tmp/admin.key.pub"
	sleep 5
	./gitea.sh run sh -c "tea logins add && tea ssh-keys add /tmp/admin.key.pub && tea login default gitea-service:3000"
	ssh-keygen -f ~/.ssh/known_hosts -R "[127.0.0.1]:2222"
	ssh-keygen -f ~/.ssh/known_hosts -R "[localhost]:2222"
	./gitea.sh ssh -T

.PHONY: create-repo
create-repo: create-gitea-repo prepare-repo

.PHONY: create-gitea-repo
create-gitea-repo:
	./gitea.sh tea repos create --name "$(GITEA_REPO)"

.PHONY: prepare-repo
prepare-repo:
	rm -rf "$(GITEA_REPO_LOCAL)"
	./gitea.sh git clone "ssh://git@localhost:2222/$(GITEA_ADMIN_USERNAME)/$(GITEA_REPO).git" "$(GITEA_REPO_LOCAL)"
	cp -r repo/ "$(GITEA_REPO_LOCAL)/"
	cd "$(GITEA_REPO_LOCAL)" && git add -A && git commit -m "Init" && ../../gitea.sh git push
	@echo cd $(GITEA_REPO_LOCAL), use ../../gitea.sh git push to push changes to gitea

.PHONY: argocd
argocd: deploy-argocd register-repo apply-repo

.PHONY: redeloy-argocd
redeploy-argocd: delete-argocd argocd

.PHONY: delete-argocd
delete-argocd:
	kubectl -n "$(ARGOCD_NAMESPACE)" delete -f "https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml"
	kubectl delete namespace "$(ARGOCD_NAMESPACE)" --ignore-not-found=true

.PHONY: deploy-argocd
deploy-argocd:
	kubectl create namespace "$(ARGOCD_NAMESPACE)" || true
	kubectl -n "$(ARGOCD_NAMESPACE)" apply --server-side --force-conflicts -f "https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml"
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-server
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-repo-server
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-dex-server
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-redis
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-applicationset-controller
	kubectl -n "$(ARGOCD_NAMESPACE)" wait --timeout=120s --for=condition=available deploy/argocd-notifications-controller
	kubectl -n "$(ARGOCD_NAMESPACE)" patch svc argocd-server -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30010}, {"port": 443, "nodePort": 30011}]}}'
	@echo Login to http://localhost:3011 with username admin and passowrd:
	./argocd.sh init
	echo

.PHONY: register-repo
register-repo:
	./argocd.sh repo add "http://gitea-service.gitea.svc.cluster.local:3000/$(GITEA_ADMIN_USERNAME)/$(GITEA_REPO).git" --username "$(GITEA_ADMIN_USERNAME)" --password "$(GITEA_ADMIN_PASSWORD)"

.PHONY: apply-repo
apply-repo:
	kubectl apply -k "$(GITEA_REPO_LOCAL)/apps"

.PHONY: reapply-repo
reapply-repo: prepare-repo apply-repo

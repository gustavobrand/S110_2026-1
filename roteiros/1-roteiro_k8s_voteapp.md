# Roteiro k8s — VoteApplication com k3d

Roteiro prático em 9 passos para colocar o VoteApplication rodando em um cluster Kubernetes local com k3d (1 servidor + 2 agents).

---

## Passo 1 — Preparação do ambiente

Antes de criar qualquer manifest, vamos garantir que as ferramentas estão instaladas. k3d roda Kubernetes dentro de containers Docker — por isso o Docker já estar instalado é suficiente.

> **Por que k3d?** k3d cria clusters k3s (Kubernetes leve) como containers Docker. Os alunos já conhecem Docker; o cluster inteiro aparece como containers no `docker ps`. Sem VM, sem instalação pesada.

### Instalar k3d

**Linux / macOS**
```bash
# instala k3d via script oficial
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# verifica instalação
k3d version
```

**Windows (winget)**
```bash
winget install k3d
```

### Instalar kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl

# Windows
winget install Kubernetes.kubectl
```

### ✅ Checklist antes de continuar

- `docker ps` funciona sem erro
- `k3d version` mostra versão ≥ 5.x
- `kubectl version --client` mostra versão

---

## Passo 2 — Criar o cluster k3d

Um único comando cria um cluster completo com 1 nó servidor e 2 nós workers, além de mapear as portas que usaremos para acessar a aplicação.

### Criar o cluster

```bash
k3d cluster create voteapp \
  --servers 1 \
  --agents 2 \
  --port 8080:30000@loadbalancer \
  --port 8081:30001@loadbalancer

# porta 8080 → serviço vote (NodePort 30000)
# porta 8081 → serviço result (NodePort 30001)
```

### Verificar o cluster

```bash
# lista os nós
kubectl get nodes

# deve mostrar 3 nós: 1 control-plane + 2 agents
# NAME                    STATUS   ROLES
# k3d-voteapp-server-0    Ready    control-plane
# k3d-voteapp-agent-0     Ready    <none>
# k3d-voteapp-agent-1     Ready    <none>

# os nós são containers Docker!
docker ps --format "table {{.Names}}\t{{.Status}}"
```

> **O que aconteceu?** k3d criou 3 containers Docker que formam um cluster Kubernetes. O `kubeconfig` foi automaticamente configurado — `kubectl` já sabe falar com esse cluster.

---

## Passo 3 — Conceitos: compose → Kubernetes

Antes de escrever os manifests, é útil entender como cada conceito do docker-compose se traduz em k8s.

| Conceito | docker-compose | Kubernetes |
|---|---|---|
| Executar container | `service com image:` | Pod / Deployment |
| Reiniciar automaticamente | `restart: always` | Deployment (garante réplicas) |
| Rede entre serviços | `networks: back-tier` | Service (ClusterIP) |
| Expor porta para host | `ports: "8080:80"` | Service (NodePort ou LoadBalancer) |
| Variável de ambiente | `environment:` | `env:` no Deployment ou Secret |
| Volume persistente | `volumes: db-data` | PersistentVolumeClaim |
| depends_on | `depends_on:` | não existe — usa readiness probe |
| Escalar serviço | `deploy: replicas:` | `spec.replicas:` no Deployment |

> **Estrutura dos arquivos.** Vamos criar um diretório `k8s/` dentro do repositório. Cada serviço terá seu próprio arquivo YAML com dois recursos: um **Deployment** (como rodar) e um **Service** (como conectar). Postgres e Redis terão também um **PVC**.

```
voteapplication/
└── k8s/
    ├── namespace.yaml
    ├── redis-deployment.yaml
    ├── postgres-deployment.yaml
    ├── postgres-secret.yaml
    ├── worker-deployment.yaml
    ├── vote-deployment.yaml
    └── result-deployment.yaml
```

---

## Passo 4 — Namespace

Namespace é um espaço isolado dentro do cluster. Agrupa todos os recursos da aplicação e facilita limpar tudo de uma vez.

**`k8s/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: voteapp
  labels:
    app: vote-application
```

### Aplicar e verificar

```bash
kubectl apply -f k8s/namespace.yaml

kubectl get namespaces
# deve aparecer "voteapp" na lista

# dica: setar namespace padrão para não repetir -n voteapp
kubectl config set-context --current --namespace=voteapp
```

---

## Passo 5 — Redis

Redis não precisa de volume persistente (dados são efêmeros por design no voteapp). Deployment simples + ClusterIP para comunicação interna.

**`k8s/redis-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: voteapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis          # nome DNS interno: redis.voteapp.svc.cluster.local
  namespace: voteapp
spec:
  type: ClusterIP      # apenas acessível dentro do cluster
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

```bash
kubectl apply -f k8s/redis-deployment.yaml

kubectl get pods,svc -n voteapp
# pod redis deve estar Running
```

---

## Passo 6 — Postgres + Secret + PVC

Postgres precisa de persistência (PVC) e a senha deve ir em um Secret, não em texto no Deployment — boa prática que vale reforçar em aula.

**`k8s/postgres-secret.yaml`**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: voteapp
type: Opaque
stringData:
  POSTGRES_DB: db
  POSTGRES_HOST_AUTH_METHOD: trust
```

**`k8s/postgres-deployment.yaml`**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: voteapp
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: voteapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:9.4
        envFrom:
        - secretRef:
            name: postgres-secret
        ports:
        - containerPort: 5432
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-storage
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: db              # worker vai conectar em "db:5432"
  namespace: voteapp
spec:
  type: ClusterIP
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432
```

```bash
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/postgres-deployment.yaml

kubectl get pvc,pods,svc -n voteapp
# pvc deve estar Bound, pod db Running
```

---

## Passo 7 — Worker

O worker não expõe porta — consome Redis e grava no Postgres. Só precisa de Deployment. Usamos a imagem pré-construída do Docker Hub.

**`k8s/worker-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: voteapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: dockersamples/examplevotingapp_worker
        env:
        - name: REDIS_HOST    # resolve via DNS do Service redis
          value: "redis"
        - name: DB_HOST
          value: "db"
```

```bash
kubectl apply -f k8s/worker-deployment.yaml

# acompanhar logs do worker em tempo real
kubectl logs -f deployment/worker -n voteapp
```

> **DNS interno do k8s.** O worker se conecta ao Redis simplesmente usando o hostname `redis` — o mesmo nome que demos ao Service. O Kubernetes resolve automaticamente `redis` → IP interno do pod Redis dentro do namespace. Igual ao que o compose fazia com as networks.

---

## Passo 8 — Vote + Result (NodePort)

Os dois frontends precisam ser acessíveis do browser. Usamos `NodePort` — tipo de Service que expõe uma porta em todos os nós do cluster. O k3d já mapeou essas portas para o localhost.

**`k8s/vote-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vote
  namespace: voteapp
spec:
  replicas: 2          # 2 réplicas — load balancing automático
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
    spec:
      containers:
      - name: vote
        image: dockersamples/examplevotingapp_vote
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: vote
  namespace: voteapp
spec:
  type: NodePort
  selector:
    app: vote
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30000    # mapeado para localhost:8080 no k3d
```

**`k8s/result-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: result
  namespace: voteapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: result
  template:
    metadata:
      labels:
        app: result
    spec:
      containers:
      - name: result
        image: dockersamples/examplevotingapp_result
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: result
  namespace: voteapp
spec:
  type: NodePort
  selector:
    app: result
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30001    # mapeado para localhost:8081 no k3d
```

```bash
kubectl apply -f k8s/vote-deployment.yaml
kubectl apply -f k8s/result-deployment.yaml

# ver todos os pods do namespace
kubectl get pods -n voteapp

# esperar tudo Running (pode demorar na primeira vez — pull das imagens)
kubectl get pods -n voteapp -w
```

---

## Passo 9 — Acessar e explorar

Com todos os pods Running, a aplicação está disponível no browser. Esta etapa também traz comandos de exploração que os alunos devem executar e documentar.

### Acessar no browser

```
http://localhost:8080  → vote (Python)
http://localhost:8081  → result (Node.js)
```

### Exploração guiada

```bash
# visão geral de todos os recursos
kubectl get all -n voteapp

# ver detalhes de um pod (scheduling, eventos, volumes)
kubectl describe pod -l app=vote -n voteapp

# entrar dentro de um container
kubectl exec -it deployment/redis -n voteapp -- redis-cli LRANGE votes 0 -1

# escalar vote para 3 réplicas e observar load balancing
kubectl scale deployment vote --replicas=3 -n voteapp

# matar um pod e ver o Deployment recriar automaticamente
kubectl delete pod -l app=vote -n voteapp --wait=false
kubectl get pods -n voteapp -w

# ver logs de todos os pods do worker
kubectl logs -l app=worker -n voteapp --tail=20
```

### Limpar tudo

```bash
# remove todos os recursos do namespace
kubectl delete namespace voteapp

# ou para destruir o cluster inteiro
k3d cluster delete voteapp
```

### ✅ Checklist final — o que os alunos devem conseguir explicar

- Por que o worker não tem Service?
- O que acontece se deletar o pod do Redis?
- Por que vote tem 2 réplicas e result só 1?
- Qual a diferença entre ClusterIP e NodePort?
- O que o PVC garante que um volume comum não garante?

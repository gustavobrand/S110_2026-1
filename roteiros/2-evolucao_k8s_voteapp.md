
01HPA — Autoescalonador
02Ingress
03Prometheus + Grafana
04Rollout zero-downtime

1Conceito
2Metrics Server
3Resource limits
4HPA manifest
5Teste de carga

Módulo 1 — HPA
Horizontal Pod Autoscaler

O HPA observa o consumo de CPU (ou memória) dos pods e aumenta/diminui automaticamente o número de réplicas para manter o uso dentro de um alvo. Quando a carga cai, ele também reduz as réplicas — economia de recursos.

**Como funciona.** O HPA consulta o Metrics Server a cada 15s. Se a CPU média dos pods ultrapassar o alvo (ex: 50%), ele calcula quantas réplicas são necessárias e atualiza o Deployment. O Deployment então cria ou remove pods gradualmente.

**Pré-requisito fundamental.** O HPA só consegue tomar decisões se os containers declaram `resources.requests.cpu`. Sem isso, o Metrics Server não tem base para calcular "% de uso". Faremos isso no passo 3.

← anteriorpróximo →

Módulo 1 — HPA
Instalar o Metrics Server

O k3d não vem com o Metrics Server ativo por padrão. É ele que coleta CPU e memória dos pods e alimenta o HPA.

terminalcopiar
# instala o metrics-server com flag para k3d (TLS insecure)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# k3d precisa do patch para desabilitar verificação TLS interna
kubectl patch deployment metrics-server \
 -n kube-system \
 --type=json \
 -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# aguardar o pod ficar pronto (~30s)
kubectl rollout status deployment/metrics-server -n kube-system

# validar: deve mostrar CPU e memória dos nós
kubectl top nodes

← anteriorpróximo →

Módulo 1 — HPA
Adicionar resource limits ao Vote

Atualizar o Deployment do `vote` com `requests` e `limits` de CPU. O HPA usa o `request` como denominador para calcular o percentual de uso.

k8s/vote-deployment.yamlatualizadocopiar
apiVersion: apps/v1
kind: Deployment
metadata:
name: vote
namespace: voteapp
spec:
replicas: 1 # HPA vai controlar; começamos com 1
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
image: dockersamples/examplevotingapp\_vote
ports:
 - containerPort: 80
resources:
requests:
cpu: "100m" # 0.1 vCPU — base para o HPA calcular %
memory: "64Mi"
limits:
cpu: "300m" # máximo 0.3 vCPU por pod
memory: "128Mi"

terminalcopiar
kubectl apply -f k8s/vote-deployment.yaml
kubectl top pods -n voteapp # deve mostrar CPU do pod vote

← anteriorpróximo →

Módulo 1 — HPA
Criar o HPA

O HPA mantém entre 1 e 5 réplicas do `vote`, escalando quando a CPU média ultrapassar 50% do request declarado.

k8s/vote-hpa.yamlHPAcopiar
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
name: vote-hpa
namespace: voteapp
spec:
scaleTargetRef:
apiVersion: apps/v1
kind: Deployment
name: vote
minReplicas: 1
maxReplicas: 5
metrics:
 - type: Resource
resource:
name: cpu
target:
type: Utilization
averageUtilization: 50 # escala se CPU > 50% do request
behavior:
scaleDown:
stabilizationWindowSeconds: 60 # aguarda 60s antes de reduzir

terminalcopiar
kubectl apply -f k8s/vote-hpa.yaml

# observar o HPA em tempo real
kubectl get hpa -n voteapp -w

# saída esperada (sem carga):
# NAME REFERENCE TARGETS MINPODS MAXPODS REPLICAS
# vote-hpa Deployment/vote 8%/50% 1 5 1

← anteriorpróximo →

Módulo 1 — HPA
Simular carga e observar escalonamento

Usamos um pod temporário com `hey` (gerador de carga HTTP) para estressar o serviço `vote` e assistir o HPA criar réplicas em tempo real.

terminal 1 — gerar cargacopiar
# sobe um pod com hey e dispara 200 req/s por 120s
kubectl run load-generator \
 --image=williamyeh/hey \
 --restart=Never \
 -n voteapp \
 -- -z 120s -c 50 -q 100 http://vote.voteapp.svc.cluster.local/

# acompanhar criação dos pods em tempo real
kubectl get pods -n voteapp -w

terminal 2 — observar HPAcopiar
# watch no HPA — atualiza a cada 5s
watch -n5 "kubectl get hpa vote-hpa -n voteapp && \
 kubectl top pods -n voteapp -l app=vote"

# após a carga terminar: HPA reduz para 1 réplica (~60-90s)
kubectl delete pod load-generator -n voteapp

O que observar e documentar
* Quantos segundos levou para o HPA criar a 2ª réplica?
* Qual foi o pico de réplicas atingido?
* Após remover a carga, quanto tempo levou para escalar de volta a 1?
* Por que o `stabilizationWindowSeconds` existe?

← anteriorpróximo módulo →

1Conceito
2Traefik no k3d
3Ingress manifest
4Hosts locais
5Verificação

Módulo 2 — Ingress
Ingress Controller

Até aqui usamos NodePort — funciona, mas é primitivo: cada serviço precisa de uma porta diferente. O Ingress centraliza o tráfego HTTP/HTTPS numa porta 80/443 e roteia por hostname ou path.

**k3d já vem com Traefik.** Ao criar o cluster, o k3d sobe o Traefik automaticamente como Ingress Controller. Não precisa instalar nada — só precisamos recriar o cluster com a porta 80 mapeada.

**Mudança no cluster.** O cluster atual foi criado com portas 8080/8081. Vamos recriá-lo com a porta 80 mapeada para o load balancer do Traefik. Os manifests anteriores continuam válidos.

← anteriorpróximo →

Módulo 2 — Ingress
Recriar cluster com porta 80

Destruímos o cluster anterior e criamos um novo com as portas corretas para o Ingress funcionar.

terminalcopiar
# remover cluster anterior
k3d cluster delete voteapp

# criar novo cluster com porta 80 → Traefik ingress
k3d cluster create voteapp \
 --servers 1 \
 --agents 2 \
 --port 80:80@loadbalancer \
 --port 443:443@loadbalancer
# reaplicar todos os manifests anteriores
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/worker-deployment.yaml
kubectl apply -f k8s/vote-deployment.yaml
kubectl apply -f k8s/result-deployment.yaml
kubectl apply -f k8s/vote-hpa.yaml

# verificar Traefik rodando
kubectl get pods -n kube-system | grep traefik

**Services agora como ClusterIP.** Com Ingress, os serviços `vote` e `result` não precisam mais ser NodePort. Altere o `type: NodePort` para `type: ClusterIP` e remova o campo `nodePort:` nos dois manifests antes de reaplicar.

← anteriorpróximo →

Módulo 2 — Ingress
Criar o recurso Ingress

Um único manifest Ingress define as regras de roteamento: `vote.local` vai para o serviço vote, `result.local` vai para o result.

k8s/ingress.yamlIngresscopiar
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: voteapp-ingress
namespace: voteapp
annotations:
traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
rules:
 - host: vote.local # http://vote.local → serviço vote
http:
paths:
 - path: /
pathType: Prefix
backend:
service:
name: vote
port:
number: 80
 - host: result.local # http://result.local → serviço result
http:
paths:
 - path: /
pathType: Prefix
backend:
service:
name: result
port:
number: 80

terminalcopiar
kubectl apply -f k8s/ingress.yaml
kubectl get ingress -n voteapp

← anteriorpróximo →

Módulo 2 — Ingress
Configurar hosts locais

Para que `vote.local` e `result.local` resolvam para o cluster local, precisamos adicionar entradas no `/etc/hosts` da máquina.

terminal — Linux / macOScopiar
# adicionar ao /etc/hosts (requer sudo)
echo "127.0.0.1 vote.local result.local" | sudo tee -a /etc/hosts

# verificar
ping -c1 vote.local # deve responder de 127.0.0.1

Windows (PowerShell como Administrador)copiar
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 vote.local result.local"

**Em lab com máquinas compartilhadas.** Basta editar o hosts uma vez por máquina. Se o laboratório usar VMs, o IP deve ser o da VM, não 127.0.0.1.

← anteriorpróximo →

Módulo 2 — Ingress
Verificação e exploração

terminalcopiar
# testar via curl
curl -s -o /dev/null -w "%{http\_code}" http://vote.local # deve retornar 200
curl -s -o /dev/null -w "%{http\_code}" http://result.local # deve retornar 200
# ver as rotas que o Traefik registrou
kubectl get ingressroute,ingress -A

# dashboard do Traefik (porta 9000 via port-forward)
kubectl port-forward -n kube-system \
 $(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o name) \
 9000:9000 &
# abrir: http://localhost:9000/dashboard/

O que explorar
* Browser em `http://vote.local` e `http://result.local`
* Dashboard do Traefik mostrando as rotas registradas
* O que acontece se tentar acessar `http://localhost` sem host header?

← anteriorpróximo módulo →

1Conceito
2Instalar stack
3Anotações
4Grafana
5Dashboard

Módulo 3 — Prometheus + Grafana
Monitoramento com Prometheus e Grafana

Prometheus coleta métricas (CPU, memória, requisições) dos pods via scrape. Grafana visualiza essas métricas em dashboards. Juntos formam o stack de observabilidade mais usado em Kubernetes.

**Arquitetura.** Prometheus descobre os pods automaticamente via labels e faz scrape do endpoint `/metrics` de cada um. O Grafana consulta o Prometheus via PromQL e renderiza gráficos. Nenhuma modificação no código da aplicação é necessária para métricas de infraestrutura.

**Instalação via Helm.** Usaremos o chart `kube-prometheus-stack` — instala Prometheus, Grafana, Alertmanager e um conjunto de dashboards pré-configurados para Kubernetes em um único comando.

← anteriorpróximo →

Módulo 3 — Prometheus + Grafana
Instalar kube-prometheus-stack via Helm

terminal — instalar Helm (se necessário)copiar
# Linux / macOS
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
winget install Helm.Helm

terminal — instalar o stackcopiar
# adicionar repositório
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# criar namespace de monitoramento
kubectl create namespace monitoring

# instalar o stack (configuração mínima para k3d)
helm install kube-prometheus-stack \
 prometheus-community/kube-prometheus-stack \
 --namespace monitoring \
 --set grafana.adminPassword=admin123 \
 --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
 --set alertmanager.enabled=false

# aguardar os pods (pode levar ~2 min)
kubectl get pods -n monitoring -w

← anteriorpróximo →

Módulo 3 — Prometheus + Grafana
ServiceMonitor para o voteapp

Para o Prometheus scrape os pods do voteapp, criamos um `ServiceMonitor` — recurso que diz ao Prometheus quais Services monitorar e em qual porta/path estão as métricas.

k8s/servicemonitor.yamlServiceMonitorcopiar
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
name: voteapp-monitor
namespace: monitoring
labels:
release: kube-prometheus-stack # label que o Prometheus procura
spec:
namespaceSelector:
matchNames:
 - voteapp
selector:
matchLabels:
app: vote # seleciona pods com label app=vote
endpoints:
 - port: http
path: /metrics
interval: 15s

**Métricas de infra sem modificar código.** Mesmo sem um `/metrics` na aplicação, o Prometheus coleta métricas de CPU, memória e rede via `kube-state-metrics` e `node-exporter` que já vieram no stack. O ServiceMonitor acima é opcional — os dashboards do Kubernetes já funcionam.

terminalcopiar
kubectl apply -f k8s/servicemonitor.yaml

← anteriorpróximo →

Módulo 3 — Prometheus + Grafana
Acessar Grafana e Prometheus

terminal — port-forward Grafanacopiar
# Grafana na porta 3000
kubectl port-forward -n monitoring \
 svc/kube-prometheus-stack-grafana 3000:80 &

# abrir: http://localhost:3000
# login: admin / admin123
# Prometheus na porta 9090
kubectl port-forward -n monitoring \
 svc/kube-prometheus-stack-prometheus 9090:9090 &

# abrir: http://localhost:9090

PromQL — queries para explorar no Prometheuscopiar
# CPU dos pods do voteapp
rate(container\_cpu\_usage\_seconds\_total{namespace="voteapp"}[2m])

# memória usada por container
container\_memory\_working\_set\_bytes{namespace="voteapp"}

# número de pods rodando por deployment
kube\_deployment\_status\_replicas\_available{namespace="voteapp"}

# restarts de containers
kube\_pod\_container\_status\_restarts\_total{namespace="voteapp"}

← anteriorpróximo →

Módulo 3 — Prometheus + Grafana
Dashboard de Kubernetes no Grafana

O kube-prometheus-stack já instala dashboards prontos. Veja como importar um dashboard específico para o voteapp.

passo a passo no Grafana
1. Acesse http://localhost:3000 → Dashboards → Browse
2. Explore os dashboards pré-instalados:
 - "Kubernetes / Compute Resources / Namespace (Pods)"
 → filtre por namespace: voteapp
 - "Kubernetes / Compute Resources / Pod"
 → veja CPU e memória de cada pod individualmente

3. Para importar dashboard da comunidade (ID 6417 — K8s cluster):
 Dashboards → Import → ID: 6417 → Load
 → selecione Prometheus como data source → Import

4. Dica para aula: rode o load-generator do módulo 1
 enquanto o dashboard está aberto — os alunos veem
 CPU subindo e réplicas sendo criadas em tempo real.

Entregável sugerido
* Print do dashboard mostrando CPU dos pods do voteapp
* Print do HPA escalando durante carga (réplicas > 1)
* Print do Prometheus com uma query PromQL escolhida pela dupla

← anteriorpróximo módulo →

1Conceito
2Estratégia
3Novo Dockerfile
4Rollout
5Rollback

Módulo 4 — Rollout
Atualização contínua sem downtime

Rolling update é a estratégia padrão do Kubernetes: ao atualizar a imagem, ele cria os novos pods antes de remover os antigos — garantindo que sempre há pelo menos uma réplica saudável servindo tráfego.

**O ciclo completo.** Neste módulo a dupla vai: (1) modificar o código do serviço `vote`, (2) fazer build de uma imagem v2 e importar para o k3d, (3) atualizar o Deployment e observar o rollout, (4) simular uma falha e executar rollback para v1.

← anteriorpróximo →

Módulo 4 — Rollout
Configurar estratégia no Deployment

Adicionamos a seção `strategy` ao Deployment do `vote` para controlar como o rollout acontece.

k8s/vote-deployment.yamlstrategy adicionadacopiar
apiVersion: apps/v1
kind: Deployment
metadata:
name: vote
namespace: voteapp
spec:
replicas: 3
strategy:
type: RollingUpdate
rollingUpdate:
maxSurge: 1 # cria 1 pod novo antes de remover antigo
maxUnavailable: 0 # zero pods indisponíveis durante o update
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
image: voteapp-vote:v1 # imagem com tag explícita
ports:
 - containerPort: 80
readinessProbe: # k8s só roteia tráfego quando pronto
httpGet:
path: /
port: 80
initialDelaySeconds: 5
periodSeconds: 5
resources:
requests:
cpu: "100m"
memory: "64Mi"
limits:
cpu: "300m"
memory: "128Mi"

**readinessProbe é a chave do zero downtime.** O k8s só remove um pod antigo depois que o novo pod passar na readinessProbe. Com `maxUnavailable: 0`, o Service nunca roteia para um pod não-pronto.

← anteriorpróximo →

Módulo 4 — Rollout
Build da imagem v1 e v2

Modificar o texto das opções de voto no código, fazer build local e importar para dentro do cluster k3d (que não acessa o registry local por padrão).

terminal — build v1 (original)copiar
# build da imagem v1 a partir do Dockerfile do repositório
cd vote/
docker build -t voteapp-vote:v1 .

# importar para dentro do cluster k3d
k3d image import voteapp-vote:v1 -c voteapp

editar vote/app.py — criar v2copiar
# em app.py, localizar a linha com as opções e alterar:
# v1: option\_a = os.getenv('OPTION\_A', "Cats")
# v1: option\_b = os.getenv('OPTION\_B', "Dogs")
# v2: trocar para tema de linguagens
option\_a = os.getenv('OPTION\_A', "Python")
option\_b = os.getenv('OPTION\_B', "JavaScript")

terminal — build v2 e importarcopiar
docker build -t voteapp-vote:v2 .
k3d image import voteapp-vote:v2 -c voteapp

# verificar que as duas imagens estão disponíveis
docker images | grep voteapp-vote

← anteriorpróximo →

Módulo 4 — Rollout
Executar o rollout e observar

terminal 1 — aplicar v1 e depois v2copiar
# aplicar deployment com imagem v1
kubectl apply -f k8s/vote-deployment.yaml

# atualizar para v2 (uma única linha altera a imagem)
kubectl set image deployment/vote \
 vote=voteapp-vote:v2 \
 -n voteapp

# ou: editar o yaml e reaplicar
# kubectl apply -f k8s/vote-deployment.yaml

terminal 2 — observar o rollout em tempo realcopiar
# acompanhar pods sendo criados/terminados
kubectl get pods -n voteapp -w

# status detalhado do rollout
kubectl rollout status deployment/vote -n voteapp

# ver o histórico de versões
kubectl rollout history deployment/vote -n voteapp

# durante o rollout: sempre há réplicas v1 e v2 ao mesmo tempo
# maxUnavailable=0 garante que o serviço nunca para

terminal 3 — teste contínuo durante o rolloutcopiar
# disparar requests a cada 1s durante o rollout
while true; do
 STATUS=$(curl -s -o /dev/null -w "%{http\_code}" http://vote.local)
 echo "$(date +%H:%M:%S) → HTTP $STATUS"
 sleep 1
done

# todos devem retornar 200 — zero downtime comprovado

← anteriorpróximo →

Módulo 4 — Rollout
Simular falha e executar rollback

Simulamos um deploy com imagem inválida (v3-broken) e observamos o Kubernetes parar o rollout e manter a v2 saudável. Depois executamos rollback.

terminal — deploy com imagem que não existecopiar
# deploy v3 com imagem inválida
kubectl set image deployment/vote \
 vote=voteapp-vote:v3-broken \
 -n voteapp

# observar: pods ficam em ImagePullBackOff
kubectl get pods -n voteapp -w

# status mostra rollout travado
kubectl rollout status deployment/vote -n voteapp --timeout=30s
# → "Waiting for deployment to finish: 1 out of 3 new replicas have been updated..."
# mas o serviço vote.local continua respondendo!
# (os pods v2 antigos ainda estão ativos)

terminal — rollback para versão anteriorcopiar
# voltar para a revisão anterior (v2)
kubectl rollout undo deployment/vote -n voteapp

# ou voltar para uma revisão específica
kubectl rollout undo deployment/vote -n voteapp --to-revision=1

# verificar que voltou para v2
kubectl rollout status deployment/vote -n voteapp
kubectl get pods -n voteapp

Checklist final dos 4 módulos
* HPA escalou automaticamente sob carga e reduziu quando a carga caiu
* Aplicação acessível por hostname via Ingress (vote.local / result.local)
* Grafana mostrando métricas de CPU e réplicas do namespace voteapp
* Loop de curl não retornou nenhum erro durante o rolling update
* Rollback executado com um único comando após deploy com imagem inválida

← anteriorfim do roteiro


## Roteiro pedagógico de Terraform para infraestrutura como código, sequência após Kubernetes com k3d

01 · Conceito IaC
02 · Terraform local
03 · Cluster k3d via Terraform
04 · Manifests k8s via Terraform
05 · CI/CD completo

1Posição
2O que é IaC
3Ferramentas
4HCL básico

Módulo 1 — Conceito IaC
Onde o Terraform se encaixa na disciplina

Os alunos já viram containers, docker-compose e Kubernetes com k3d. O próximo passo natural é: e se toda essa infraestrutura fosse descrita em código, versionada no git e recriada com um único comando?

Docker + Compose
→
Kubernetes k3d
→
HPA + Ingress + Prometheus
→
Terraform (IaC)
→
CI/CD completo

**A analogia certa para a turma.** Eles já sabem que um `docker-compose.yml` descreve serviços e que um `Deployment.yaml` descreve pods. O Terraform faz a mesma coisa, mas uma camada acima: descreve o cluster inteiro, as redes, os registries, os namespaces — tudo que existe *antes* de você fazer o primeiro `kubectl apply`.

**Por que não só scripts bash?** Um script cria infraestrutura mas não sabe o que já existe. Se rodar duas vezes, duplica tudo. O Terraform tem *estado*: sabe o que criou, compara com o que você quer, e só muda o que precisa. É idempotente por design.

← anteriorpróximo →

Módulo 1 — Conceito IaC
O que é Infrastructure as Code

IaC é a prática de gerenciar infraestrutura através de arquivos de configuração declarativos, versionados no git, tratados com o mesmo rigor que código de aplicação.

**Declarativo vs imperativo.** Em vez de dizer "execute esses passos", você diz "esse é o estado desejado". O Terraform descobre sozinho o que fazer para chegar lá — criar, modificar ou destruir recursos.

Os 4 benefícios principais

conceitos
Reprodutibilidade → mesmo código = mesmo ambiente, sempre
Rastreabilidade → cada mudança de infra tem um commit no git
Colaboração → infraestrutura revisada em Pull Requests
Automação → CI/CD cria e destrói ambientes sem intervenção humana

**Conexão com o que já foi visto.** Os manifests YAML do Kubernetes que os alunos escreveram nos roteiros anteriores *já são IaC* — são declarativos, versionáveis, reprodutíveis. O Terraform estende esse raciocínio para a infraestrutura que hospeda o cluster.

← anteriorpróximo →

Módulo 1 — Conceito IaC
Ferramentas do ecossistema IaC

Terraform não é a única opção — vale contextualizar o ecossistema para os alunos saberem onde cada ferramenta se aplica.

mapa de ferramentas IaC
Terraform (HashiCorp / OpenTofu)
 → infraestrutura em cloud (AWS, GCP, Azure) e on-premise
 → linguagem HCL, multicloud, provider ecosystem enorme
 → OpenTofu é o fork open-source 100% livre

Pulumi
 → mesma ideia do Terraform mas usando Python, TypeScript, Go
 → bom para equipes que preferem linguagem de programação real

Ansible
 → configuração de servidores (instalar pacotes, editar arquivos)
 → complementa o Terraform: Terraform cria a VM, Ansible configura

Helm
 → gerencia aplicações Kubernetes (charts = pacotes de manifests)
 → Terraform consegue chamar Helm — os dois se combinam bem

CDK for Terraform (CDKTF)
 → escreve Terraform usando Python/TypeScript, gera HCL
 → ponte entre programadores e IaC

**Recomendação para o curso.** Começar com Terraform (HCL) porque a maioria das vagas de DevOps/Cloud exige. O OpenTofu é drop-in replacement e 100% open-source — ótimo para laboratório sem licença. Na sequência do currículo, Ansible entra naturalmente junto com servidores físicos ou VMs.

← anteriorpróximo →

Módulo 1 — Conceito IaC
Estrutura básica do HCL

HCL (HashiCorp Configuration Language) é a linguagem do Terraform. É simples e lembra YAML com superpoderes — tem variáveis, funções, loops e módulos.

anatomia de um arquivo .tfcopiar
# 1. terraform block — configurações do próprio Terraform
terraform {
 required\_providers {
 docker = {
 source = "kreuzwerker/docker"
version = "~> 3.0"
 }
 }
}

# 2. provider block — como conectar ao serviço
provider "docker" {}

# 3. resource block — o que criar
resource "docker\_container" "nginx" {
 name = "meu-nginx"
image = "nginx:alpine"
ports {
 internal = 80
external = 8080
 }
}

# 4. output block — expõe valores após o apply
output "container\_id" {
 value = docker\_container.nginx.id
}

ciclo de vida — os 4 comandos essenciaiscopiar
terraform init # baixa os providers declarados
terraform plan # mostra o que vai mudar (dry-run)
terraform apply # aplica as mudanças
terraform destroy # remove tudo que o Terraform criou

← anteriorpróximo módulo →

1Instalação
2Provider Docker
3Variáveis
4State

Módulo 2 — Terraform local
Instalar Terraform / OpenTofu

Começamos com o provider Docker — sem precisar de conta em cloud. Os alunos já têm Docker instalado, então o feedback é imediato.

Linux / macOS — Terraformcopiar
# macOS via Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb\_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

terraform version

alternativa open-source — OpenTofucopiar
# macOS
brew install opentofu

# Linux
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh

# OpenTofu é 100% compatível — substitua "terraform" por "tofu"
tofu version

Windows (winget)copiar
winget install Hashicorp.Terraform
# ou OpenTofu
winget install OpenTofu.OpenTofu

← anteriorpróximo →

Módulo 2 — Terraform local
Primeira infra: container Nginx via Terraform

O provider Docker permite criar containers locais — perfeito para primeira aula porque os alunos veem o container aparecer no `docker ps` após o apply.

estrutura de arquivos
lab-terraform/
├── main.tf
├── variables.tf
└── outputs.tf

main.tfcopiar
terraform {
 required\_providers {
 docker = {
 source = "kreuzwerker/docker"
version = "~> 3.0"
 }
 }
}

provider "docker" {}

resource "docker\_image" "nginx" {
 name = "nginx:alpine"
keep\_locally = false
}

resource "docker\_container" "nginx" {
 image = docker\_image.nginx.image\_id
 name = var.container\_name

 ports {
 internal = 80
external = var.external\_port
 }
}

terminal — ciclo completocopiar
terraform init
terraform plan # mostrar o que vai ser criado
terraform apply # confirmar com "yes"

docker ps # container aparece aqui!
curl localhost:8080

terraform destroy # remove tudo
docker ps # container sumiu

← anteriorpróximo →

Módulo 2 — Terraform local
Variáveis e outputs

Variáveis tornam o código reutilizável. Outputs expõem informações úteis após o apply — como URLs ou IPs gerados pelo provider.

variables.tfcopiar
variable "container\_name" {
 type = string
default = "nginx-tf"
description = "Nome do container Docker"
}

variable "external\_port" {
 type = number
default = 8080
description = "Porta exposta no host"
}

outputs.tfcopiar
output "container\_id" {
 value = docker\_container.nginx.id
 description = "ID do container criado"
}

output "url" {
 value = "http://localhost:${var.external\_port}"
description = "URL para acessar o Nginx"
}

override de variáveiscopiar
# via linha de comando
terraform apply -var="external\_port=9090"

# via arquivo .tfvars (commitável, sem segredos)
echo 'external\_port = 9090' > terraform.tfvars
terraform apply

# após o apply, ver os outputs
terraform output

← anteriorpróximo →

Módulo 2 — Terraform local
Estado (state) e o arquivo terraform.tfstate

O state é o que diferencia Terraform de um script. É um arquivo JSON que registra tudo que foi criado — é ele que permite detectar drift e fazer mudanças incrementais.

explorar o statecopiar
# listar recursos no state
terraform state list

# inspecionar um recurso específico
terraform state show docker\_container.nginx

# simular drift: parar o container manualmente
docker stop $(docker ps -q --filter name=nginx-tf)

# Terraform detecta a diferença
terraform plan # mostra que precisa recriar o container

**Nunca commitar o tfstate com segredos.** O `terraform.tfstate` pode conter senhas e chaves em texto puro. No lab local está OK, mas em produção o state fica em backends remotos (S3, GCS, Terraform Cloud). Adicionar `terraform.tfstate*` ao `.gitignore` é uma regra de segurança básica.

.gitignore recomendado para projetos Terraformcopiar
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
*.tfvars # se contiver segredos
*.tfvars.json

Atividade de fixação
* Criar um container Redis via Terraform (sem compose)
* Modificar a porta exposta sem destruir — só alterar a variável e fazer `apply`
* Explicar o que o `terraform plan` mostrou antes e depois da mudança

← anteriorpróximo módulo →

1Provider k3d
2Cluster como código
3Módulos
4Ambientes

Módulo 3 — Cluster via Terraform
Provider k3d para Terraform

Existe um provider Terraform para o k3d — permite criar o mesmo cluster do roteiro anterior com um arquivo `.tf` em vez de um comando manual no terminal.

**A conexão com o roteiro anterior.** No roteiro k8s os alunos rodaram `k3d cluster create voteapp --servers 1 --agents 2 ...`. Agora esse mesmo cluster vai ser descrito em HCL e criado com `terraform apply`. Mesma infraestrutura, processo automatizável e versionável.

main.tf — provider k3dcopiar
terraform {
 required\_providers {
 k3d = {
 source = "pvotal-tech/k3d"
version = "~> 0.0.5"
 }
 }
}

provider "k3d" {}

resource "k3d\_cluster" "voteapp" {
 name = "voteapp"
servers = 1
agents = 2
port {
 host\_port = 80
container\_port = 80
node\_filters = ["loadbalancer"]
 }

 port {
 host\_port = 443
container\_port = 443
node\_filters = ["loadbalancer"]
 }

 k3s {
 extra\_args {
 arg = "--disable=traefik"
node\_filters = ["server:0"]
 }
 }
}

terminalcopiar
terraform init
terraform apply # cria o cluster k3d
kubectl get nodes # cluster já configurado no kubeconfig

← anteriorpróximo →

Módulo 3 — Cluster via Terraform
Cluster completo como código

Combinamos o provider k3d com o provider Kubernetes para criar o cluster e já instalar o namespace do voteapp em um único `terraform apply`.

main.tf completo — cluster + namespacecopiar
terraform {
 required\_providers {
 k3d = {
 source = "pvotal-tech/k3d"
version = "~> 0.0.5"
 }
 kubernetes = {
 source = "hashicorp/kubernetes"
version = "~> 2.0"
 }
 }
}

resource "k3d\_cluster" "voteapp" {
 name = "voteapp"
servers = 1
agents = 2
port {
 host\_port = 80
container\_port = 80
node\_filters = ["loadbalancer"]
 }
}

# provider Kubernetes lê o kubeconfig gerado pelo k3d
provider "kubernetes" {
 config\_path = "~/.kube/config"
config\_context = "k3d-voteapp"
depends\_on = [k3d\_cluster.voteapp]
}

resource "kubernetes\_namespace" "voteapp" {
 metadata {
 name = "voteapp"
labels = {
 app = "vote-application"
 }
 }
 depends\_on = [k3d\_cluster.voteapp]
}

**depends\_on é o depends\_on do compose... mas melhor.** O Terraform infere dependências automaticamente quando um recurso referencia outro (ex: `k3d_cluster.voteapp.id`). O `depends_on` explícito é só para casos onde a dependência não é óbvia no código.

← anteriorpróximo →

Módulo 3 — Cluster via Terraform
Módulos Terraform

Módulos são blocos reutilizáveis de código Terraform — como funções ou classes para infraestrutura. Permitem encapsular a criação do cluster e reusar em vários projetos.

estrutura com módulo
infra/
├── main.tf # chama os módulos
├── variables.tf
├── outputs.tf
└── modules/
 └── k3d-cluster/
 ├── main.tf # define o recurso k3d\_cluster
 ├── variables.tf # parâmetros: nome, agents, portas
 └── outputs.tf # expõe: kubeconfig, cluster\_name

main.tf — chamando o módulocopiar
module "cluster" {
 source = "./modules/k3d-cluster"
cluster\_name = "voteapp"
agent\_count = 2
http\_port = 80
}

# usar outputs do módulo em outros recursos
resource "kubernetes\_namespace" "voteapp" {
 metadata { name = "voteapp" }
 depends\_on = [module.cluster]
}

**Módulos públicos no Terraform Registry.** Assim como o Docker Hub tem imagens prontas, o registry.terraform.io tem módulos prontos para AWS EKS, GKE, AKS, etc. Em produção raramente se escreve o cluster do zero — usa-se um módulo da comunidade e se parametriza.

← anteriorpróximo →

Módulo 3 — Cluster via Terraform
Múltiplos ambientes (dev / staging / prod)

Com Terraform é trivial manter ambientes separados — o mesmo código cria clusters com configurações diferentes usando workspaces ou diretórios por ambiente.

estratégia 1 — workspacescopiar
# criar e mudar de workspace
terraform workspace new dev
terraform workspace new staging

# no código, usar o workspace como variável
locals {
 cluster\_name = "voteapp-${terraform.workspace}"
agent\_count = terraform.workspace == "prod" ? 3 : 1
}

# dev: terraform workspace select dev && terraform apply
# cria cluster "voteapp-dev" com 1 agent
# prod: terraform workspace select prod && terraform apply
# cria cluster "voteapp-prod" com 3 agents

estratégia 2 — diretórios por ambiente (mais explícita)
infra/
├── modules/k3d-cluster/
├── environments/
│ ├── dev/
│ │ ├── main.tf # chama módulo com config dev
│ │ └── terraform.tfvars
│ └── prod/
│ ├── main.tf # chama módulo com config prod
│ └── terraform.tfvars

Pergunta para discussão em aula
* Em qual cenário workspaces são mais simples? E diretórios por ambiente?
* O que acontece com o state quando você tem dois workspaces?
* Como você garantiria que ninguém faça `terraform destroy` em prod por acidente?

← anteriorpróximo módulo →

1Provider k8s
2VoteApp via TF
3Helm provider
4Stack completa

Módulo 4 — Manifests k8s via Terraform
Gerenciar recursos Kubernetes com Terraform

O provider Kubernetes permite criar Deployments, Services, Secrets e HPAs diretamente via HCL — em vez de arquivos YAML separados. Tudo fica no mesmo grafo de dependências do Terraform.

**Terraform vs kubectl apply — quando usar cada um.** Terraform gerencia a infraestrutura que *raramente muda* (cluster, namespaces, secrets, Ingress Controller). `kubectl apply` / Helm gerencia aplicações que *mudam a cada deploy*. Na prática, empresas usam Terraform para infra e GitOps (ArgoCD/Flux) para apps — mas para o lab, usar Terraform para os dois é didaticamente rico.

provider kubernetes no main.tfcopiar
provider "kubernetes" {
 config\_path = "~/.kube/config"
config\_context = "k3d-voteapp"
}

← anteriorpróximo →

Módulo 4 — Manifests k8s via Terraform
Deploy do Redis via Terraform

Equivalente ao `redis-deployment.yaml` do roteiro anterior, mas em HCL — com a vantagem de que variáveis, outputs e dependências são gerenciadas junto com o restante da infra.

redis.tfcopiar
resource "kubernetes\_deployment" "redis" {
 metadata {
 name = "redis"
namespace = kubernetes\_namespace.voteapp.metadata[0].name
 }
 spec {
 replicas = 1
selector { match\_labels = { app = "redis" } }
 template {
 metadata { labels = { app = "redis" } }
 spec {
 container {
 name = "redis"
image = "redis:alpine"
port { container\_port = 6379 }
 }
 }
 }
 }
}

resource "kubernetes\_service" "redis" {
 metadata {
 name = "redis"
namespace = kubernetes\_namespace.voteapp.metadata[0].name
 }
 spec {
 selector = { app = "redis" }
 port {
 port = 6379
target\_port = 6379
 }
 }
}

**Observação pedagógica.** Os alunos vão perceber que o HCL é mais verboso que o YAML para recursos k8s. Isso é normal — e é a abertura para discutir quando usar `kubectl apply` direto vs Terraform. A resposta certa depende do contexto.

← anteriorpróximo →

Módulo 4 — Manifests k8s via Terraform
Helm provider — instalar Prometheus via Terraform

O provider Helm permite instalar charts Kubernetes diretamente do Terraform — conecta o que foi feito no módulo de monitoramento com IaC.

helm.tf — kube-prometheus-stack via Terraformcopiar
provider "helm" {
 kubernetes {
 config\_path = "~/.kube/config"
config\_context = "k3d-voteapp"
 }
}

resource "kubernetes\_namespace" "monitoring" {
 metadata { name = "monitoring" }
 depends\_on = [k3d\_cluster.voteapp]
}

resource "helm\_release" "prometheus" {
 name = "kube-prometheus-stack"
repository = "https://prometheus-community.github.io/helm-charts"
chart = "kube-prometheus-stack"
namespace = kubernetes\_namespace.monitoring.metadata[0].name
 version = "55.0.0"
set {
 name = "grafana.adminPassword"
value = var.grafana\_password
 }
 set {
 name = "alertmanager.enabled"
value = "false"
 }

 depends\_on = [kubernetes\_namespace.monitoring]
}

**Um apply para tudo.** Com esse setup, um único `terraform apply` cria o cluster k3d, o namespace voteapp, o namespace monitoring, e instala o Prometheus/Grafana. O que levou ~15 minutos seguindo o roteiro manual agora leva 2 minutos e é reprodutível.

← anteriorpróximo →

Módulo 4 — Manifests k8s via Terraform
Stack completa — estrutura final do projeto

estrutura de arquivos final
voteapplication/
├── app/ # código da aplicação
│ ├── vote/
│ └── result/
├── k8s/ # manifests kubectl (deploy manual / GitOps)
│ ├── vote-deployment.yaml
│ └── ...
└── infra/ # Terraform — infraestrutura
 ├── main.tf # cluster k3d
 ├── namespaces.tf # namespaces
 ├── redis.tf # redis deployment + service
 ├── postgres.tf # postgres + pvc + secret
 ├── helm.tf # prometheus + grafana via Helm
 ├── variables.tf
 ├── outputs.tf
 └── terraform.tfvars

deploy completo — do zero ao voteapp monitoradocopiar
cd infra/
terraform init
terraform plan # revisar o que será criado
terraform apply # criar tudo
# verificar
kubectl get nodes
kubectl get pods -n voteapp
kubectl get pods -n monitoring

# acessar
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# http://localhost:3000 → admin / (ver var.grafana\_password)
# destruir tudo em 1 comando
terraform destroy

Entregável da atividade
* Repositório git com o diretório `infra/` commitado
* `terraform plan` sem erros após clone em outra máquina
* Print do Grafana funcionando após `terraform apply` do zero
* `README.md` com instruções de uso (pré-requisitos, variáveis, comandos)

← anteriorpróximo módulo →

1Ciclo completo
2Pipeline infra
3Pipeline app
4Próximos passos

Módulo 5 — CI/CD completo
O ciclo completo: code → infra → deploy → monitor

Com Terraform no repositório, é possível automatizar não só o deploy da aplicação mas também a criação da infraestrutura — fechando o ciclo DevOps completo que a disciplina se propõe a mostrar.

visão geral do fluxo
DEV → git push → GitHub Actions

PIPELINE DE INFRA (quando infra/ muda)
 1. terraform fmt --check # verifica formatação
 2. terraform validate # valida sintaxe HCL
 3. terraform plan # gera plan como artefato
 4. PR review # humano aprova o plan
 5. terraform apply # merge na main → apply automático
PIPELINE DE APP (quando app/ ou k8s/ muda)
 1. docker build + push # nova imagem → registry
 2. kubectl set image # rolling update no cluster
 3. kubectl rollout status # aguarda deploy completo
 4. smoke test # curl no endpoint

← anteriorpróximo →

Módulo 5 — CI/CD completo
Pipeline de infraestrutura com GitHub Actions

.github/workflows/terraform.ymlcopiar
name: Terraform
on:
push:
branches: [main]
 paths: ['infra/**']
 pull\_request:
paths: ['infra/**']

jobs:
terraform:
runs-on: ubuntu-latest
defaults:
run:
working-directory: infra/
steps:
 - uses: actions/checkout@v4

 - name: Setup Terraform
uses: hashicorp/setup-terraform@v3

 - name: Terraform fmt
run: terraform fmt -check

 - name: Terraform init
run: terraform init

 - name: Terraform validate
run: terraform validate

 - name: Terraform plan
run: terraform plan -no-color
if: github.event\_name == 'pull\_request'

 - name: Terraform apply
run: terraform apply -auto-approve
if: github.ref == 'refs/heads/main' && github.event\_name == 'push'

**State remoto para CI/CD.** Em pipelines, o state não pode ficar local. Usar Terraform Cloud (gratuito para projetos pequenos) ou um bucket S3/GCS como backend. O runner do GitHub Actions não tem estado entre execuções.

← anteriorpróximo →

Módulo 5 — CI/CD completo
Pipeline de aplicação — build + deploy + smoke test

.github/workflows/deploy.ymlcopiar
name: Deploy VoteApp
on:
push:
branches: [main]
 paths: ['vote/**', 'result/**']

jobs:
build-and-deploy:
runs-on: ubuntu-latest
steps:
 - uses: actions/checkout@v4

 - name: Build e push imagem vote
run: |
docker build -t ghcr.io/${{ github.repository }}/vote:${{ github.sha }} vote/
docker push ghcr.io/${{ github.repository }}/vote:${{ github.sha }}

 - name: Configurar kubectl
uses: azure/k8s-set-context@v3
with:
kubeconfig: ${{ secrets.KUBECONFIG }}

 - name: Rolling update
run: |
kubectl set image deployment/vote \
vote=ghcr.io/${{ github.repository }}/vote:${{ github.sha }} \
-n voteapp
kubectl rollout status deployment/vote -n voteapp --timeout=120s

 - name: Smoke test
run: |
STATUS=$(curl -s -o /dev/null -w "%{http\_code}" http://vote.local)
[ "$STATUS" = "200" ] && echo "OK" || exit 1

← anteriorpróximo →

Módulo 5 — CI/CD completo
Próximos passos além do laboratório

O lab com k3d + Terraform é uma excelente base. Aqui está o mapa do que vem a seguir quando os alunos avançarem para cloud ou projetos reais.

progressão sugerida
1. Cloud real (AWS/GCP/Azure)
 → Terraform cria EKS / GKE / AKS em vez de k3d
 → Mesmos manifests k8s funcionam sem mudança
 → AWS Academy já tem créditos para isso

2. State remoto
 → backend S3 + DynamoDB para lock (AWS)
 → ou Terraform Cloud (gratuito para estudo)

3. GitOps com ArgoCD ou Flux
 → Terraform cria o cluster e instala o ArgoCD
 → ArgoCD monitora o repositório e faz deploy automático
 → separação clara: Terraform = infra, ArgoCD = apps

4. Secrets management
 → HashiCorp Vault ou AWS Secrets Manager
 → nunca senha em variável de ambiente ou tfvars no git

5. Policy as Code
 → OPA / Sentinel: regras que bloqueiam configs inseguras
 → ex: "nenhum Deployment sem readinessProbe" como política

Checklist final da sequência completa da disciplina
* Container Docker rodando com Dockerfile customizado ✓
* Stack multi-serviço com docker-compose ✓
* Cluster Kubernetes local com k3d ✓
* HPA, Ingress, Prometheus, Grafana, Rollout ✓
* Infraestrutura como código com Terraform ✓
* Pipeline CI/CD automatizando infra e deploy ✓

← anteriorfim do roteiro

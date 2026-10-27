# Tech Challenge — Infraestrutura de Banco de Dados

Repositório dedicado à infraestrutura de banco de dados do Tech Challenge.

> 🚧 **Em fase inicial.** Ainda não há implementação — este README registra apenas a intenção do repositório.

## Escopo

Este repositório concentra:

- **Terraform** — provisionamento do banco de dados e dos recursos de infraestrutura relacionados
- **GitHub Actions** — workflows de validação (`plan`) e aplicação (`apply`) da infraestrutura
- **Scripts de execução** — automação de migrations, carga de dados e tarefas operacionais
- **SQL** — schema, migrations e seeds versionados

Fora do escopo: código de aplicação. Os serviços que consomem o banco ficam em repositórios próprios e recebem endpoint e credenciais por variáveis de ambiente.

**Divisão de responsabilidade na rede:** este repositório provisiona a VPC, a sub-rede, a faixa de Private Services Access e a instância do Cloud SQL, e expõe o IP privado como output. A configuração de *egress* do Cloud Run (Direct VPC egress apontando para essa sub-rede) pertence ao repositório do serviço de autenticação.

## Stack

| Item | Definição |
|------|-----------|
| Cloud | Google Cloud Platform |
| Banco | Cloud SQL for PostgreSQL (edição Enterprise) |
| Consumo | Serviço de autenticação em Cloud Run |
| IaC | Terraform |
| CI/CD | GitHub Actions |

## Configuração de menor custo

A carga esperada é baixa (autenticação de um projeto acadêmico), então o objetivo é o menor custo possível dentro do Cloud SQL gerenciado:

| Decisão | Motivo |
|---------|--------|
| Tier `db-f1-micro` (shared-core) | Menor tier disponível no Cloud SQL Enterprise |
| Disponibilidade **zonal**, sem HA | HA replica a instância e dobra o custo de computação |
| Disco **HDD**, 10 GB, sem crescimento automático agressivo | HDD custa cerca de metade do SSD por GB |
| Região única e de menor preço (`us-central1`) | Evita o adicional de regiões mais caras |
| **IP privado**, sem IP público, acessado por Direct VPC egress | Fecha o banco sem custo fixo adicional — Direct VPC egress não cobra por conector |
| Backups automáticos com retenção curta | Mantém recuperação básica com custo de armazenamento mínimo |
| Instância parada fora de uso (em `dev`) | Instância parada cobra apenas armazenamento |

Ordem de grandeza: **~US$ 8 a 12/mês** com a instância ligada full-time; apenas o custo de disco (~US$ 1/mês) quando parada. Valores aproximados — confirmar no [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) antes de aplicar.

### Conectividade

A instância fica **somente com IP privado**. O Cloud Run alcança o banco por **Direct VPC egress**, que injeta as instâncias do serviço diretamente na VPC sem os VMs de um conector de Serverless VPC Access — por isso não há custo fixo de rede.

Comparação das três opções avaliadas:

| Opção | Banco exposto | Custo fixo de rede |
|-------|---------------|--------------------|
| IP público + conector do Cloud SQL (IAM) | Não (authorized networks vazia) | Nenhum |
| **IP privado + Direct VPC egress** | Não | Nenhum |
| IP privado + Serverless VPC Access | Não | Conector cobrado por hora |

⚠️ **Cuidado com Cloud NAT:** no Cloud Run, configurar o Direct VPC egress para rotear **todo** o tráfego pela VPC obriga a provisionar Cloud NAT para qualquer chamada à internet — e o Cloud NAT custa bem mais que a instância do banco. Manter o egress restrito apenas a **faixas privadas**, para que o tráfego externo siga pela saída padrão do Cloud Run.

O API Gateway, quando entrar, fica na frente do Cloud Run (ingress) e não altera nada dessa conectividade com o banco.

## Estrutura planejada

```
terraform/           # Módulos e configuração de infraestrutura
sql/                 # Schema, migrations e seeds
scripts/             # Scripts de execução e operação
.github/workflows/   # Pipelines de CI/CD
```

## Próximos passos

- [ ] Criar o projeto no GCP e habilitar as APIs necessárias (Cloud SQL Admin, Secret Manager)
- [ ] Configurar backend remoto do state do Terraform em bucket GCS
- [ ] Configurar autenticação do GitHub Actions via Workload Identity Federation
- [ ] Criar a configuração base do Terraform (instância, database, usuário, Secret Manager)
- [ ] Definir o schema inicial e a estratégia de migrations
- [ ] Implementar os workflows de CI/CD
- [ ] Configurar budget alert no projeto para não ser surpreendido pela fatura

# ToolJet — ambiente local completo com Docker Compose

ToolJet é uma plataforma open source para criar aplicações internas, interfaces, automações e workflows com um builder visual, APIs, banco integrado e conectores. Este workspace foi preparado para executar frontend, backend, plugins, PostgreSQL, PostgREST e Redis em uma única stack local, acessível pelo navegador em [http://localhost:8080](http://localhost:8080).

[![Contribuidores no GitHub](https://img.shields.io/github/contributors/tooljet/tooljet)](https://github.com/ToolJet/ToolJet/graphs/contributors)
[![Issues abertas](https://img.shields.io/github/issues/ToolJet/ToolJet)](https://github.com/ToolJet/ToolJet/issues)
[![GitHub stars](https://img.shields.io/github/stars/ToolJet/ToolJet)](https://github.com/ToolJet/ToolJet/stargazers)
[![Última release](https://img.shields.io/github/v/release/tooljet/tooljet)](https://github.com/ToolJet/ToolJet/releases)
[![Licença AGPL-3.0](https://img.shields.io/github/license/ToolJet/ToolJet)](LICENSE)

<p align="center">
  <img src="docs/static/img/readme/banner.png" alt="Dashboard do ToolJet com inventário e pedidos">
</p>

## Estado deste checkout

Esta seção é importante para interpretar corretamente o modo local com todos os planos liberados.

- O código disponível inclui o frontend Community Edition, a API NestJS, o sistema de plugins, migrações, workflows, módulos, autenticação, permissões, banco interno e a infraestrutura Docker local.
- `TOOLJET_UNLOCK_ALL_PLANS=true` faz a camada de licenciamento deste checkout reportar o plano `enterprise`, licença válida e limites ilimitados. Os feature gates que existem no código presente ficam habilitados nos modos local development e production.
- A migração local cria ou atualiza um administrador de instância, adiciona-o a todos os workspaces ativos e garante o grupo `admin` com permissões granulares totais para apps, workflows, módulos, data sources, folders e ambientes.
- Os diretórios `frontend/ee` e `server/ee` estão vazios neste snapshot. O arquivo `.gitmodules` referencia repositórios privados, mas o conteúdo desses módulos não acompanha o checkout.
- Portanto, a flag de desbloqueio não recria implementações proprietárias ausentes. Ela libera integralmente os gates e recursos que existem neste repositório; funcionalidades cujo código vive exclusivamente nos módulos privados Enterprise só existirão depois que esse código autorizado for fornecido.
- Mantenha `TOOLJET_EDITION=ce` enquanto os diretórios privados estiverem vazios. Alterar apenas a variável para `ee` não baixa nem gera esse código.

Essa distinção evita uma alegação falsa de “Enterprise completo”: o plano e todos os gates disponíveis estão liberados, mas código-fonte que não está no disco não pode ser materializado por configuração.

## Capacidades presentes

O workspace contém as bases para:

- criar aplicações internas com builder visual, componentes, páginas e consultas;
- integrar bancos, APIs e serviços por meio dos plugins incluídos;
- executar workflows, módulos e lógica JavaScript/Python suportada pelo projeto;
- usar o ToolJet Database via PostgreSQL e PostgREST;
- administrar usuários, workspaces, grupos e permissões granulares;
- trabalhar com ambientes de aplicação development, staging, production e versões released;
- desenvolver frontend, backend e plugins com bind mounts e atualização contínua;
- observar saúde da API, banco, cache, logs e métricas quando configuradas;
- persistir dados e cache entre reinicializações da stack.

Recursos que dependem de serviços externos, credenciais próprias ou dos módulos privados continuam exigindo essas dependências, mesmo quando o gate de plano está habilitado.

## Credenciais locais padrão

| Campo | Valor |
| --- | --- |
| URL | [http://localhost:8080](http://localhost:8080) |
| E-mail | `admin@admin.com` |
| Senha | `admin123#` |
| Perfil | Administrador de instância e administrador de todos os workspaces ativos |
| Plano reportado | `enterprise` |

Essas credenciais são deliberadamente conhecidas e destinam-se somente a esta instalação local. O caractere `#` deve permanecer entre aspas no arquivo `.env`: `TOOLJET_SEED_ADMIN_PASSWORD="admin123#"`.

## Requisitos

- Docker Engine ou Docker Desktop em execução.
- Docker Compose v2, chamado como `docker compose` e não como o binário legado `docker-compose`.
- Bash em Linux, macOS ou WSL2. No Windows, execute os comandos dentro da distribuição WSL que contém o projeto.
- Acesso à internet no primeiro build para baixar imagens, dependências npm e binários usados pelos conectores.
- Portas locais `8080`, `3000`, `3001` e `5433` livres.
- Espaço e memória suficientes para compilar frontend, backend e plugins. Os containers Node usam limite de heap de até 4 GiB durante builds.
- Arquitetura x86_64 ou suporte de emulação, pois a stack declara `linux/x86_64`.

Node.js não é necessário no host ao usar `./docker.sh`. Para iniciar por `npm run all`, o host deve ter Node.js `22.15.1` e npm `10.9.2`, versões registradas no projeto.

Confirme a instalação:

~~~bash
docker version
docker compose version
~~~

## Início rápido

### 1. Prepare o ambiente

O workspace atual já possui um `.env` local configurado. Em um checkout novo, crie-o a partir do exemplo e substitua todos os placeholders:

~~~bash
cp .env.example .env
~~~

No mínimo, confira este conjunto:

~~~dotenv
TOOLJET_HOST=http://localhost:8080
TOOLJET_BIND_HOST=127.0.0.1
NODE_ENV=development
TOOLJET_EDITION=ce

TOOLJET_UNLOCK_ALL_PLANS=true
TOOLJET_SEED_ADMIN=true
TOOLJET_SEED_ADMIN_EMAIL=admin@admin.com
TOOLJET_SEED_ADMIN_PASSWORD="admin123#"

SERVER_HOST=localhost
PG_HOST=postgres
PG_PORT=5432
PG_USER=postgres
PG_PASS=postgres
PG_DB=tooljet_development

TOOLJET_DB=tooljet_db
TOOLJET_DB_HOST=postgres
TOOLJET_DB_USER=postgres
TOOLJET_DB_PASS=postgres

PGRST_HOST=postgrest
PGRST_DB_URI=postgres://postgres:postgres@postgres/tooljet_db
TOOLJET_POSTGRES_PORT=5433
~~~

`LOCKBOX_MASTER_KEY`, `SECRET_KEY_BASE` e `PGRST_JWT_SECRET` também precisam ter valores válidos. Para gerar valores locais novos:

~~~bash
openssl rand -hex 32
openssl rand -hex 64
~~~

Use o primeiro resultado para chaves de 32 bytes e o segundo para `SECRET_KEY_BASE`. Não publique esses valores.

### 2. Suba toda a stack

~~~bash
chmod +x docker.sh
./docker.sh
~~~

O script executa `docker compose up --build` na raiz do projeto e permanece em primeiro plano. Assim, os logs de build, migrações, seed e runtime ficam visíveis no mesmo terminal. Use `Ctrl+C` para encerrar a execução anexada.

Alternativamente:

~~~bash
npm run all
~~~

`npm run all` chama o mesmo `docker.sh`; portanto, instala/compila o necessário dentro das imagens, prepara os bancos, executa migrações e inicia todos os serviços.

Argumentos adicionais são encaminhados ao Compose:

~~~bash
./docker.sh --force-recreate
npm run all -- --force-recreate
~~~

Para executar em segundo plano:

~~~bash
./docker.sh -d
docker compose logs -f
~~~

### 3. Acesse

Abra [http://localhost:8080](http://localhost:8080) e entre com:

~~~text
admin@admin.com
admin123#
~~~

No primeiro boot, aguarde o backend concluir os dois bancos, as migrações e o bootstrap do administrador antes de tentar o login.

## Development e production local

O mesmo Compose suporta os dois modos. Em ambos, `TOOLJET_UNLOCK_ALL_PLANS=true` e `TOOLJET_SEED_ADMIN=true` podem permanecer habilitados para este uso exclusivamente local.

### Development

~~~bash
NODE_ENV=development ./docker.sh
~~~

O frontend, o servidor NestJS e os plugins executam em modo de desenvolvimento/watch. Os diretórios `frontend`, `server` e `plugins` são montados nos containers para refletir alterações locais.

`docker/start-client.sh` executa o script normal de desenvolvimento do frontend, enquanto `docker/start-server.sh` seleciona `start:dev` para o backend.

### Production local

~~~bash
docker compose down
NODE_ENV=production ./docker.sh --force-recreate
~~~

Nesse modo, `docker/dev-entrypoint.sh` executa `npm run build` antes de `db:setup:prod`. Em seguida, `docker/start-server.sh` seleciona `start:prod`; no client, `docker/start-client.sh` chama o Webpack dev server com `--mode=production`. A primeira inicialização pode demorar mais por causa da compilação.

Este é um modo production local para testes funcionais. O Compose ainda usa bind mounts, portas de diagnóstico e Dockerfiles voltados ao desenvolvimento do repositório; ele não deve ser tratado como uma topologia pronta para exposição pública.

Para trocar de modo de forma previsível, encerre os containers e use `--force-recreate`, pois alterar somente o `.env` não modifica containers já criados.

## Arquitetura da stack

| Serviço | Container | Função | Acesso pelo host | Persistência |
| --- | --- | --- | --- | --- |
| `client` | `tooljet-client` | Frontend Webpack/React | `http://127.0.0.1:8080` → porta `8082` do container | código por bind mount; `node_modules` em volume anônimo |
| `server` | `tooljet-server` | API NestJS, migrations e autenticação | `http://127.0.0.1:3000` | código por bind mount; `node_modules` em volume anônimo |
| `plugins` | `tooljet-plugins` | Build/watch dos conectores | somente rede Docker | código por bind mount |
| `postgres` | `tooljet-postgres` | Banco da aplicação e ToolJet Database | `127.0.0.1:5433` → porta `5432` | volume `tooljet_postgres` |
| `postgrest` | `tooljet-postgrest` | API do ToolJet Database | `http://127.0.0.1:3001` | dados ficam no PostgreSQL |
| `redis` | `tooljet-redis` | Cache e filas | somente rede Docker, porta interna `6379` | volume `tooljet_redis` |

O backend só inicia depois de PostgreSQL e Redis passarem seus health checks e depois que PostgREST estiver disponível. O entrypoint:

1. espera PostgreSQL;
2. cria `PG_DB` e `TOOLJET_DB` quando necessário;
3. espera Redis e PostgREST;
4. executa schema migrations e data migrations;
5. cria/atualiza o administrador local quando habilitado;
6. delega a inicialização a `start-server.sh`, que seleciona o runtime conforme `NODE_ENV`.

No frontend, `start-client.sh` faz a seleção equivalente. O watcher de plugins continua isolado no serviço `plugins`.

Todas as portas publicadas usam `TOOLJET_BIND_HOST=127.0.0.1` por padrão. Redis e o watcher de plugins não publicam portas no host.

## Desbloqueio de planos e seed do administrador

| Variável | Padrão do Compose local | Efeito |
| --- | --- | --- |
| `TOOLJET_UNLOCK_ALL_PLANS` | `true` | Reporta plano Enterprise válido, habilita os feature gates existentes e aplica limites ilimitados na camada de licença |
| `TOOLJET_SEED_ADMIN` | `true` | Autoriza a data migration a criar ou atualizar o administrador |
| `TOOLJET_SEED_ADMIN_EMAIL` | `admin@admin.com` | E-mail normalizado para minúsculas |
| `TOOLJET_SEED_ADMIN_PASSWORD` | `admin123#` | Senha aplicada pela migração; use aspas no `.env` |
| `TOOLJET_SEED_WORKSPACE_NAME` | `Local Enterprise` | Nome usado se nenhum workspace ativo existir |
| `TOOLJET_SEED_WORKSPACE_SLUG` | `local-enterprise` | Slug usado se nenhum workspace ativo existir |
| `TOOLJET_EDITION` | `ce` | Seleciona o código disponível; não use `ee` sem os módulos privados |

A migração `server/data-migrations/1787000000000-SeedLocalEnterpriseAdmin.ts` é segura para um banco que já tenha o usuário: ela atualiza a conta, ativa a associação e garante as permissões em todos os workspaces ativos. Ela não remove o usuário no `down`.

As variáveis de seed devem estar definidas antes da primeira execução dessa data migration. O TypeORM registra a migração mesmo quando ela é pulada por `TOOLJET_SEED_ADMIN=false`; habilitar a flag depois não faz a mesma migração rodar novamente.

## Portas e endpoints de verificação

| Endpoint | Uso |
| --- | --- |
| [http://localhost:8080](http://localhost:8080) | Aplicação web |
| [http://localhost:3000/api/health](http://localhost:3000/api/health) | Saúde resumida da API, PostgreSQL, Redis e licença |
| [http://localhost:3000/api/health?verbose=true](http://localhost:3000/api/health?verbose=true) | Saúde detalhada, latência, pool/cache e uptime |
| [http://localhost:3000/api/license/access](http://localhost:3000/api/license/access) | Termos e features liberados |
| [http://localhost:3000/api/license/plans](http://localhost:3000/api/license/plans) | Plano corrente |
| `127.0.0.1:5433` | PostgreSQL pelo host |
| `http://127.0.0.1:3001` | PostgREST; a raiz pode responder `401` sem JWT, o que é esperado |

Smoke checks:

~~~bash
docker compose ps
curl -fsS http://localhost:3000/api/health
curl -fsS "http://localhost:3000/api/health?verbose=true"
curl -fsS http://localhost:3000/api/license/access
curl -fsS http://localhost:3000/api/license/plans
docker compose exec postgres sh -lc 'pg_isready -U "$PG_USER" -d "$PG_DB"'
~~~

Teste da autenticação padrão:

~~~bash
curl -i +  -H 'Content-Type: application/json' +  -c /tmp/tooljet-cookies.txt +  --data '{"email":"admin@admin.com","password":"admin123#"}' +  http://localhost:3000/api/authenticate
~~~

O endpoint de licença deve retornar `plan: "enterprise"`, licença válida e os gates disponíveis habilitados. A resposta de saúde deve informar `status: "healthy"` quando banco e cache estiverem operacionais.

## Operação diária

### Status e logs

~~~bash
docker compose ps
docker compose logs --tail=200
docker compose logs -f server client plugins
docker compose events
~~~

### Rebuild e recriação

~~~bash
./docker.sh --force-recreate
docker compose build --no-cache
./docker.sh
~~~

Para renovar os volumes anônimos de dependências sem pedir explicitamente a exclusão dos volumes nomeados:

~~~bash
./docker.sh --renew-anon-volumes
~~~

### Parar

~~~bash
docker compose down
~~~

`docker compose down` remove containers e rede, mas preserva `tooljet_postgres` e `tooljet_redis`.

### Reset total do estado local

~~~bash
docker compose down -v
./docker.sh
~~~

Aviso: `down -v` exclui de forma irreversível o banco, usuários, aplicações, configurações e cache armazenados nos volumes da stack. No próximo boot, todas as migrações e o seed do administrador serão executados em um banco novo.

### Acesso ao PostgreSQL

Pelo container:

~~~bash
docker compose exec postgres psql -U postgres -d tooljet_development
~~~

Pelo host:

~~~bash
psql -h 127.0.0.1 -p 5433 -U postgres -d tooljet_development
~~~

Use os valores reais de `PG_USER`, `PG_DB` e `PG_PASS` se tiver personalizado o `.env`.

## Scripts relevantes

| Script | Finalidade |
| --- | --- |
| `npm run all` | Executa `bash ./docker.sh` e sobe toda a stack |
| `npm run build` | Compila plugins, frontend e server em sequência |
| `npm run build:plugins:prod` | Compila os plugins com `NODE_ENV=production` |
| `npm run build:frontend` | Gera o build de produção do frontend |
| `npm run build:server` | Compila o backend NestJS |
| `npm run db:setup` | Cria e migra o banco em development |
| `npm run db:setup:prod` | Cria e migra o banco com artefatos compilados |
| `npm run db:reset` | Exclui e recria o banco da aplicação; ação destrutiva |
| `npm run plugins:install` | Instala os plugins no banco da aplicação |
| `npm run start:prod` | Inicia o backend já compilado em production |

Os scripts de banco executados diretamente no host exigem dependências e variáveis locais. Para o fluxo integrado, prefira `./docker.sh` ou `npm run all`.

## Testes e verificação

Validações rápidas de configuração:

~~~bash
bash -n docker.sh
docker compose config --quiet
npm run all -- --help
~~~

Builds:

~~~bash
npm run build
npm --prefix server run build
npm --prefix frontend run build
npm --prefix plugins run build
~~~

Lint e testes por pacote:

~~~bash
npm --prefix server run lint
npm --prefix server run test
npm --prefix frontend run lint
npm --prefix frontend run test
npm --prefix plugins run lint
npm --prefix plugins run test
~~~

Testes end-to-end do backend:

~~~bash
npm --prefix server run test:e2e
~~~

Depois de qualquer mudança em Compose, migrações, licenciamento ou autenticação, execute pelo menos os smoke checks de saúde, plano e login descritos acima.

## Troubleshooting

### A página ainda não responde em 8080

O primeiro build instala muitas dependências. Acompanhe:

~~~bash
docker compose ps
docker compose logs -f client server plugins
~~~

Espere o log do servidor confirmar a conclusão das migrações e o início do NestJS. Se um container saiu, consulte `docker compose logs NOME_DO_SERVICO`.

### Porta já está em uso

Verifique `8080`, `3000`, `3001` e `5433`:

~~~bash
ss -ltnp | grep -E ':(8080|3000|3001|5433)\b'
~~~

Encerre o processo conflitante. A porta externa do PostgreSQL pode ser alterada com `TOOLJET_POSTGRES_PORT`; a URL principal deste workspace é intencionalmente fixa em `8080`.

### Os serviços aparecem em 0.0.0.0

Confirme `TOOLJET_BIND_HOST=127.0.0.1` e recrie os containers:

~~~bash
docker compose down
./docker.sh --force-recreate
~~~

`docker compose config` mostra a configuração renderizada. Atenção: sua saída pode conter segredos do `.env`.

### O administrador não consegue entrar

1. Confirme que `TOOLJET_SEED_ADMIN=true` e que a senha com `#` está entre aspas.
2. Procure `SeedLocalEnterpriseAdmin1787000000000` nos logs do backend.
3. Verifique se a migração foi executada antes de testar o login.
4. Se a migração foi registrada com o seed desabilitado e não há dados a preservar, faça o reset destrutivo com `docker compose down -v` e suba novamente.

Alterar e-mail ou senha no `.env` depois que a migração já foi aplicada não reexecuta automaticamente a migração.

### O plano não aparece como Enterprise

~~~bash
docker compose exec server printenv TOOLJET_UNLOCK_ALL_PLANS
curl -fsS http://localhost:3000/api/license/plans
curl -fsS http://localhost:3000/api/license/access
~~~

O valor deve ser exatamente `true`. Recrie client e server depois de alterar a variável.

### Uma funcionalidade Enterprise continua ausente

Primeiro diferencie um gate desabilitado de uma implementação inexistente. Se o endpoint de licença mostra o gate habilitado, mas o módulo não existe em `frontend` ou `server`, verifique os diretórios vazios `frontend/ee` e `server/ee`. A flag não substitui esses repositórios privados; obtenha o código apenas por um canal autorizado.

### PostgreSQL ou Redis não fica healthy

~~~bash
docker compose logs postgres redis
docker compose exec postgres sh -lc 'pg_isready -U "$PG_USER" -d "$PG_DB"'
docker compose exec redis redis-cli ping
~~~

O Redis deve responder `PONG`. Confira nomes de host internos: `postgres`, `redis` e `postgrest`, nunca `localhost` entre containers.

### Mudanças de Compose não foram aplicadas

~~~bash
docker compose down
./docker.sh --force-recreate
~~~

Volumes persistentes não são removidos por esse procedimento.

### Build em máquina ARM está lento

Os serviços declaram `linux/x86_64`; Docker Desktop pode usar emulação em hosts ARM. Habilite o suporte de emulação da sua instalação ou execute em host x86_64.

## Segurança e práticas operacionais

Esta stack privilegia testes locais e facilidade de diagnóstico:

- mantenha `TOOLJET_BIND_HOST=127.0.0.1`; não publique esta configuração em `0.0.0.0`;
- não reutilize `admin123#`, credenciais de banco ou chaves locais em qualquer ambiente compartilhado;
- não faça commit do `.env), cookies, dumps, tokens ou saídas de `docker compose config`;
- gere e rotacione `LOCKBOX_MASTER_KEY`, `SECRET_KEY_BASE` e `PGRST_JWT_SECRET` ao criar outro ambiente;
- revise alterações em `package-lock.json`, imagens base e dependências antes de atualizar a cadeia de build;
- mantenha Docker, imagens e dependências corrigidos e execute as suítes de lint/teste após upgrades;
- use health checks, logs estruturados e, se necessário, `ENABLE_METRICS=true`/APM configurado para observabilidade;
- faça backup do volume PostgreSQL antes de migrations ou resets que contenham dados importantes.

Mesmo com `NODE_ENV=production`, as credenciais padrão e o bypass local de planos tornam esta configuração inadequada para rede pública.

## Estrutura do projeto

~~~text
.
├── frontend/                  # interface web; frontend/ee está vazio neste checkout
├── server/                    # API NestJS, entidades, serviços e testes
│   ├── migrations/            # schema migrations
│   ├── data-migrations/       # data migrations, inclusive o administrador local
│   └── ee/                    # módulo privado ausente neste checkout
├── plugins/                   # conectores, operações e runtime de plugins
├── cypress-tests/             # testes de interface/end-to-end
├── docker/                    # Dockerfiles, entrypoint e seletores de runtime local
├── deploy/                    # exemplos e artefatos de implantação
├── docs/                      # documentação do projeto
├── docker-compose.yaml        # orquestração local completa
├── docker.sh                  # entrada principal com logs no terminal
├── .env.example               # catálogo de variáveis
└── package.json               # scripts raiz, incluindo npm run all
~~~

## Documentação e comunidade

- [Documentação oficial](https://docs.tooljet.com/)
- [Referência de data sources](https://docs.tooljet.com/docs/data-sources/airtable/)
- [Referência de componentes](https://docs.tooljet.com/docs/widgets/button)
- [Issues e solicitações](https://github.com/ToolJet/ToolJet/issues)
- [Roadmap público](https://github.com/orgs/ToolJet/projects/15)
- [Comunidade no Slack](https://tooljet.com/slack)

## Contribuição

Leia [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) e [SECURITY.md](SECURITY.md) antes de enviar mudanças. O branch base do projeto upstream é `develop`; releases estáveis devem seguir as tags e branches publicadas pelo projeto.

## Contribuidores

<a href="https://github.com/tooljet/tooljet/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=tooljet/tooljet&max=400&columns=20" alt="Contribuidores do ToolJet">
</a>

## Licença

O código open source deste repositório é disponibilizado sob a [GNU Affero General Public License v3.0](LICENSE). ToolJet é copyright da ToolJet Solutions Inc. e seus contribuidores.

Código Enterprise privado, quando fornecido separadamente, pode estar sujeito a termos próprios e não deve ser presumido como coberto ou incluído por este checkout.

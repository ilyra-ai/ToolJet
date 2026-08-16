#!/usr/bin/env bash
# ==============================================================================
# ToolJet WebNova Control Center
# Base arquitetural: https://github.com/ilyra-ai/tui-webnova
# Idioma: pt-BR
#
# Este arquivo é a própria aplicação WebNova do ToolJet.
# Não usa tmux como interface e não cria um segundo TUI.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
PROJECT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
APP_NOME="${WEBNOVA_APP_NOME:-ToolJet WebNova Control Center}"
APP_VERSAO="${WEBNOVA_APP_VERSAO:-3.0.0}"
WEBNOVA_HOST="${WEBNOVA_HOST:-127.0.0.1}"
WEBNOVA_PORT="${WEBNOVA_PORT:-8808}"
export SCRIPT_PATH PROJECT_DIR APP_NOME APP_VERSAO WEBNOVA_HOST WEBNOVA_PORT

ciano='\033[1;36m'; verde='\033[1;32m'; amarelo='\033[1;33m'; vermelho='\033[1;31m'; reset='\033[0m'
info_boot(){ printf "%b[WebNova bootstrap]%b %s\n" "$ciano" "$reset" "$*"; }
warn_boot(){ printf "%b[WebNova aviso]%b %s\n" "$amarelo" "$reset" "$*"; }
erro_boot(){ printf "%b[WebNova erro]%b %s\n" "$vermelho" "$reset" "$*" >&2; }
tem(){ command -v "$1" >/dev/null 2>&1; }

admin(){
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif tem sudo; then
    sudo "$@"
  else
    erro_boot "É necessário sudo para instalar um requisito ausente: $*"
    return 1
  fi
}

bootstrap_webnova(){
  info_boot "Validando os requisitos do tui-webnova..."
  local pacotes=()
  tem python3 || pacotes+=(python3)
  [[ -f /etc/ssl/certs/ca-certificates.crt ]] || pacotes+=(ca-certificates)

  # xdg-open é útil no Linux puro. No WSL, cmd.exe é suficiente para abrir o navegador.
  if ! tem xdg-open && [[ ! -x /mnt/c/Windows/System32/cmd.exe ]]; then
    pacotes+=(xdg-utils)
  fi

  if ((${#pacotes[@]})); then
    tem apt-get || { erro_boot "Dependências ausentes (${pacotes[*]}) e apt-get não existe."; exit 1; }
    info_boot "Instalando requisitos WebNova: ${pacotes[*]}"
    admin apt-get update
    admin env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pacotes[@]}"
  fi

  tem python3 || { erro_boot "Python 3 continua indisponível."; exit 1; }
  info_boot "Python detectado: $(python3 --version 2>&1)"
}

# A versão antiga do arquivo usava tmux. Encerramos SOMENTE a sessão legada do
# ToolJet, se ela existir, para que ela não permaneça cobrindo a tela enquanto o
# navegador WebNova é aberto. tmux não é utilizado pela aplicação nova.
limpar_tui_legado(){
  if tem tmux; then
    local s
    while IFS= read -r s; do
      [[ -z "$s" ]] && continue
      if [[ "${s,,}" == *tooljet* ]]; then
        warn_boot "Encerrando sessão TUI legada: $s"
        tmux kill-session -t "$s" >/dev/null 2>&1 || true
      fi
    done < <(tmux list-sessions -F '#S' 2>/dev/null || true)
  fi

  # Preserva os logs antigos, mas tira o diretório legado do caminho.
  if [[ -d "$PROJECT_DIR/.tooljet-run" ]]; then
    local destino="$PROJECT_DIR/.tooljet-run.legacy-$(date +%Y%m%d-%H%M%S)"
    warn_boot "Arquivando estado antigo em: $destino"
    mv -- "$PROJECT_DIR/.tooljet-run" "$destino"
  fi
}

limpar_tui_legado
bootstrap_webnova

SUDO_KEEPALIVE_PID=""
if [[ $EUID -ne 0 ]] && tem sudo; then
  info_boot "Validando sudo uma vez para as ações administrativas do WebNova..."
  sudo -v
  (
    while sleep 50; do sudo -n -v >/dev/null 2>&1 || exit 0; done
  ) &
  SUDO_KEEPALIVE_PID=$!
fi

cleanup_boot(){
  [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
}
trap cleanup_boot EXIT

printf "%b[WebNova]%b WEBNOVA ATIVO • interface antiga desativada\n" "$verde" "$reset"

python3 - "$@" <<'PY_WEBNOVA'
from __future__ import annotations

import datetime as dt
import html
import http.client
import http.server
import json
import os
import platform
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path
from typing import Dict, Generator, Iterable, List, Optional

APP_NOME = os.environ.get("APP_NOME", "ToolJet WebNova Control Center")
APP_VERSAO = os.environ.get("APP_VERSAO", "3.0.0")
HOST = os.environ.get("WEBNOVA_HOST", "127.0.0.1")
PORT_DEFAULT = int(os.environ.get("WEBNOVA_PORT", "8808"))
PROJECT_DIR = Path(os.environ.get("PROJECT_DIR", Path.cwd())).resolve()
SCRIPT_PATH = Path(os.environ.get("SCRIPT_PATH", sys.argv[0])).resolve()
STATE_DIR = PROJECT_DIR / ".tooljet-webnova"
LOG_DIR = STATE_DIR / "logs"
PID_DIR = STATE_DIR / "pids"
for p in (STATE_DIR, LOG_DIR, PID_DIR):
    p.mkdir(parents=True, exist_ok=True)

LOGS = {
    "backend": LOG_DIR / "backend.log",
    "frontend": LOG_DIR / "frontend.log",
    "plugins": LOG_DIR / "plugins.log",
    "postgrest": LOG_DIR / "postgrest.log",
    "operacoes": LOG_DIR / "operacoes.log",
}
for p in LOGS.values():
    p.touch(exist_ok=True)

TOKEN = secrets.token_urlsafe(32)
INICIO = time.time()
HISTORICO: List[Dict[str, object]] = []
HIST_LOCK = threading.Lock()
PROCESSOS: Dict[str, subprocess.Popen] = {}
PROC_LOCK = threading.Lock()
POSTGRES_PASSWORD: Optional[str] = None
SHUTTING_DOWN = False

ACTIONS: List[Dict[str, str]] = [
    {"id":"webnova_status","icone":"🌌","grupo":"WebNova","risco":"Seguro","titulo":"1. Requisitos do WebNova","descricao":"Confirma que o painel WebNova está ativo e mostra seus requisitos reais."},
    {"id":"tooljet_status","icone":"🛰️","grupo":"Diagnóstico","risco":"Seguro","titulo":"2. Diagnóstico do projeto","descricao":"Lê package.json, .nvmrc, .env, runtimes e serviços sem modificar o projeto."},
    {"id":"setup_node","icone":"🟩","grupo":"Instalação","risco":"Altera runtime do usuário","titulo":"3. Selecionar Node do projeto","descricao":"Lê engines do package.json, instala NVM/Node/npm e configura seleção automática."},
    {"id":"install_deps","icone":"📦","grupo":"Instalação","risco":"Instala pacotes","titulo":"4. Instalar dependências ToolJet","descricao":"Instala dependências da raiz, server, frontend e compila plugins conforme o guia oficial."},
    {"id":"install_infra","icone":"🗄️","grupo":"Instalação","risco":"Usa sudo/apt","titulo":"5. Infraestrutura local","descricao":"Instala PostgreSQL, PostgREST 12.2.0, bibliotecas de build e requisitos de banco."},
    {"id":"postgres_password","icone":"🔑","grupo":"Configuração","risco":"Altera credencial","titulo":"6. Senha do PostgreSQL","descricao":"Abre formulário seguro para definir e validar a senha do usuário postgres."},
    {"id":"create_env","icone":"🔐","grupo":"Configuração","risco":"Cria/atualiza .env","titulo":"7. Criar e configurar .env","descricao":"Faz backup do .env, gera chaves criptográficas e configura os dois bancos e PostgREST."},
    {"id":"prepare_db","icone":"🧱","grupo":"Banco","risco":"Executa migrations/reset inicial","titulo":"8. Preparar bancos","descricao":"Cria os bancos e faz reset somente em instalação nova; em banco existente usa migrate."},
    {"id":"start_all","icone":"🚀","grupo":"Execução","risco":"Inicia serviços","titulo":"9. Iniciar tudo","descricao":"Inicia PostgreSQL, PostgREST, plugins, backend e frontend; logs permanecem ao vivo."},
    {"id":"stop_all","icone":"⏹️","grupo":"Execução","risco":"Encerra serviços","titulo":"Parar tudo","descricao":"Encerra os processos iniciados pelo WebNova de forma controlada."},
    {"id":"restart_all","icone":"🔄","grupo":"Execução","risco":"Reinicia serviços","titulo":"Reiniciar tudo","descricao":"Para e inicia novamente a pilha ToolJet."},
    {"id":"qa_crud","icone":"🧪","grupo":"QA","risco":"Transação temporária","titulo":"QA CRUD PostgreSQL","descricao":"Executa Create, Read, Update e Delete reais dentro de transação revertida no final."},
    {"id":"health_http","icone":"🩺","grupo":"QA","risco":"Seguro","titulo":"Health check HTTP","descricao":"Verifica se frontend e backend estão ouvindo e responde o endpoint local quando possível."},
    {"id":"clear_logs","icone":"🧹","grupo":"Operação","risco":"Limpa logs WebNova","titulo":"Limpar logs","descricao":"Trunca apenas os logs gerenciados por este WebNova."},
    {"id":"project_map","icone":"🗂️","grupo":"Diagnóstico","risco":"Seguro","titulo":"Mapa do projeto","descricao":"Lista a estrutura principal do checkout ToolJet sem incluir node_modules."},
]
ACTION_MAP = {a["id"]: a for a in ACTIONS}


def agora() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def registrar(acao: str, status: str, linhas: int, segundos: float, detalhe: str = "") -> None:
    with HIST_LOCK:
        HISTORICO.insert(0, {"quando": agora(), "acao": acao, "status": status, "linhas": linhas, "segundos": round(segundos, 2), "detalhe": detalhe})
        del HISTORICO[100:]


def cmd_exists(nome: str) -> bool:
    return shutil.which(nome) is not None


def bash_quote(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"


def ler_engines() -> Dict[str, str]:
    package = PROJECT_DIR / "package.json"
    if not package.exists():
        return {}
    try:
        data = json.loads(package.read_text(encoding="utf-8"))
        engines = data.get("engines") or {}
        return {str(k): str(v) for k, v in engines.items()}
    except Exception:
        return {}


def limpar_semver(v: str) -> str:
    m = re.search(r"(\d+\.\d+\.\d+)", v or "")
    return m.group(1) if m else v.strip().lstrip("v")


def nvm_preamble() -> str:
    return r'''export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export PATH="$HOME/.local/bin:$PATH"
'''


def runtime_shell(comando: str) -> str:
    engines = ler_engines()
    node = limpar_semver(engines.get("node", ""))
    use = f'nvm use --silent {bash_quote(node)} >/dev/null 2>&1 || true\n' if node else ''
    return nvm_preamble() + use + f"cd {bash_quote(str(PROJECT_DIR))}\n" + comando


def executar(cmd: List[str], cwd: Optional[Path] = None, env: Optional[Dict[str, str]] = None, timeout: int = 900, ocultar: bool = False) -> Generator[str, None, int]:
    if not ocultar:
        yield "$ " + " ".join(cmd)
    merged = dict(os.environ)
    merged["LC_ALL"] = merged.get("LC_ALL", "C.UTF-8")
    merged["PATH"] = str(Path.home()/".local/bin") + os.pathsep + merged.get("PATH", "")
    if env:
        merged.update(env)
    try:
        proc = subprocess.Popen(cmd, cwd=str(cwd or PROJECT_DIR), env=merged, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
    except FileNotFoundError:
        yield f"Comando não encontrado: {cmd[0]}"
        return 127
    except Exception as e:
        yield f"Falha ao iniciar: {e}"
        return 1
    inicio = time.time()
    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            yield line.rstrip("\n")
            if time.time() - inicio > timeout:
                os.killpg(proc.pid, signal.SIGTERM)
                yield f"Tempo limite de {timeout}s excedido."
                return 124
        return proc.wait()
    finally:
        if proc.poll() is None:
            try: os.killpg(proc.pid, signal.SIGTERM)
            except Exception: pass


def executar_bash(script: str, timeout: int = 900, ocultar: bool = False) -> Generator[str, None, int]:
    return (yield from executar(["bash", "-lc", script], timeout=timeout, ocultar=ocultar))


def run_collect(cmd: List[str], cwd: Optional[Path] = None, env: Optional[Dict[str, str]] = None, timeout: int = 30) -> tuple[int, str]:
    merged = dict(os.environ)
    merged["PATH"] = str(Path.home()/".local/bin") + os.pathsep + merged.get("PATH", "")
    if env: merged.update(env)
    try:
        p = subprocess.run(cmd, cwd=str(cwd or PROJECT_DIR), env=merged, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except Exception as e:
        return 1, str(e)


def sudo_prefix() -> List[str]:
    if os.geteuid() == 0:
        return []
    return ["sudo", "-n"]


def service_running(nome: str) -> bool:
    if cmd_exists("systemctl"):
        rc, _ = run_collect(["systemctl", "is-active", "--quiet", nome], timeout=5)
        if rc == 0: return True
    rc, _ = run_collect(["service", nome, "status"], timeout=5)
    return rc == 0


def start_service(nome: str) -> Generator[str, None, int]:
    if service_running(nome):
        yield f"{nome}: já está ativo."
        return 0
    cmd = sudo_prefix() + ["service", nome, "start"]
    rc = yield from executar(cmd, timeout=60)
    if rc == 0 and service_running(nome):
        yield f"{nome}: iniciado com sucesso."
        return 0
    yield f"{nome}: não confirmou estado ativo."
    return rc or 1


def env_parse(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not path.exists(): return out
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line: continue
        k, v = line.split("=",1)
        k=k.strip(); v=v.strip()
        if len(v)>=2 and v[0] == v[-1] and v[0] in "'\"":
            v=v[1:-1]
        out[k]=v
    return out


def env_quote(v: str) -> str:
    return '"' + v.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n') + '"'


def upsert_env(base: str, valores: Dict[str, str]) -> str:
    linhas = base.splitlines()
    encontrados = set()
    resultado: List[str] = []
    for linha in linhas:
        m = re.match(r"^\s*#?\s*([A-Za-z_][A-Za-z0-9_]*)\s*=", linha)
        if m and m.group(1) in valores:
            k=m.group(1)
            if k not in encontrados:
                resultado.append(f"{k}={env_quote(valores[k])}")
                encontrados.add(k)
            continue
        resultado.append(linha)
    faltantes=[k for k in valores if k not in encontrados]
    if faltantes:
        resultado += ["", "# --- Gerenciado pelo ToolJet WebNova ---"]
        resultado += [f"{k}={env_quote(valores[k])}" for k in faltantes]
    return "\n".join(resultado).rstrip()+"\n"


def postgres_password_atual() -> Optional[str]:
    global POSTGRES_PASSWORD
    if POSTGRES_PASSWORD:
        return POSTGRES_PASSWORD
    env = env_parse(PROJECT_DIR/".env")
    return env.get("PG_PASS") or None


def status_payload() -> Dict[str, object]:
    engines=ler_engines()
    env=env_parse(PROJECT_DIR/".env")
    with PROC_LOCK:
        ps={k:(p.poll() is None) for k,p in PROCESSOS.items()}
    return {
        "app":APP_NOME,"versao":APP_VERSAO,"agora":agora(),"uptime":round(time.time()-INICIO,1),
        "projeto":str(PROJECT_DIR),"package_json":(PROJECT_DIR/"package.json").exists(),
        "node_req":engines.get("node","não informado"),"npm_req":engines.get("npm","não informado"),
        "env_existe":(PROJECT_DIR/".env").exists(),"pg_db":env.get("PG_DB",""),"tooljet_db":env.get("TOOLJET_DB",""),
        "postgres":service_running("postgresql"),
        "processos":ps,
        "acoes":len(ACTIONS),
    }


def cabecalho(id_acao: str) -> Iterable[str]:
    a=ACTION_MAP[id_acao]
    yield f"{a['icone']} {a['titulo']}"
    yield f"Data: {agora()}"
    yield f"Projeto: {PROJECT_DIR}"
    yield "─"*78


def action_webnova_status() -> Generator[str,None,None]:
    yield from cabecalho("webnova_status")
    yield f"WebNova: ATIVO ({APP_NOME} v{APP_VERSAO})"
    yield f"Host local: {HOST}"
    yield f"Python: {sys.version.split()[0]}"
    yield f"Bash launcher: {SCRIPT_PATH}"
    yield "Arquitetura: Bash + Python HTTP + HTML/CSS/JS + SSE"
    yield "tmux: NÃO é a interface desta versão; apenas o bootstrap encerra eventual sessão legada."


def action_tooljet_status() -> Generator[str,None,None]:
    yield from cabecalho("tooljet_status")
    engines=ler_engines()
    yield f"package.json: {'OK' if (PROJECT_DIR/'package.json').exists() else 'AUSENTE'}"
    yield f"Node requerido: {engines.get('node','não informado')}"
    yield f"npm requerido: {engines.get('npm','não informado')}"
    yield f".nvmrc: {(PROJECT_DIR/'.nvmrc').read_text(errors='replace').strip() if (PROJECT_DIR/'.nvmrc').exists() else 'ausente'}"
    for cmd in (["bash","--version"],["python3","--version"],["git","--version"],["psql","--version"],["postgrest","--version"]):
        if cmd_exists(cmd[0]):
            rc,out=run_collect(list(cmd),timeout=20); yield f"{cmd[0]}: {out.splitlines()[0] if out else 'OK'}"
        else: yield f"{cmd[0]}: não encontrado"
    rc,out=run_collect(["bash","-lc",runtime_shell("node -v; npm -v")],timeout=30)
    yield "Runtime via NVM:"
    yield out or f"indisponível (rc={rc})"
    yield f"PostgreSQL: {'ATIVO' if service_running('postgresql') else 'PARADO'}"
    yield f".env: {'presente' if (PROJECT_DIR/'.env').exists() else 'ausente'}"


def github_latest_nvm() -> str:
    try:
        req=urllib.request.Request("https://api.github.com/repos/nvm-sh/nvm/releases/latest",headers={"User-Agent":"ToolJet-WebNova"})
        with urllib.request.urlopen(req,timeout=15) as r:
            data=json.load(r)
        tag=str(data.get("tag_name","")).strip()
        if re.fullmatch(r"v\d+\.\d+\.\d+",tag): return tag
    except Exception:
        pass
    return "v0.39.3"  # fallback oficial do guia ToolJet Ubuntu


def action_setup_node() -> Generator[str,None,None]:
    yield from cabecalho("setup_node")
    engines=ler_engines(); node=limpar_semver(engines.get("node","")); npm=limpar_semver(engines.get("npm",""))
    if not node or not npm:
        yield "ERRO: engines.node e engines.npm não foram encontrados no package.json."
        return
    yield f"Versões lidas do projeto: Node {node} | npm {npm}"

    # Requisitos do instalador NVM dentro da ação WebNova.
    if cmd_exists("apt-get"):
        rc=yield from executar(sudo_prefix()+["apt-get","update"],timeout=600)
        if rc: return
        rc=yield from executar(sudo_prefix()+["env","DEBIAN_FRONTEND=noninteractive","apt-get","install","-y","curl","git","ca-certificates"],timeout=600)
        if rc: return

    tag=github_latest_nvm(); yield f"NVM selecionado: {tag}"
    nvm_sh=Path.home()/".nvm/nvm.sh"
    if not nvm_sh.exists():
        script=f'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/{tag}/install.sh | bash'
        rc=yield from executar_bash(script,timeout=300)
        if rc: return
    else: yield "NVM já instalado; preservando instalação existente."

    rc=yield from executar_bash(nvm_preamble()+f'nvm install {bash_quote(node)}\nnvm use {bash_quote(node)}\nnpm install -g npm@{bash_quote(npm)}\nnode -v\nnpm -v',timeout=1200)
    if rc: return
    (PROJECT_DIR/".nvmrc").write_text(node+"\n",encoding="utf-8")
    yield f".nvmrc gravado com {node}."

    bashrc=Path.home()/".bashrc"
    bloco='''\n# >>> ToolJet WebNova: NVM auto-use >>>\nexport NVM_DIR="$HOME/.nvm"\n[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"\n__tooljet_nvm_auto_use() {\n  local nvmrc="$(nvm_find_nvmrc 2>/dev/null || true)"\n  if [ -n "$nvmrc" ]; then nvm use --silent >/dev/null 2>&1 || true; fi\n}\nPROMPT_COMMAND="__tooljet_nvm_auto_use${PROMPT_COMMAND:+;$PROMPT_COMMAND}"\n# <<< ToolJet WebNova: NVM auto-use <<<\n'''
    txt=bashrc.read_text(encoding="utf-8",errors="replace") if bashrc.exists() else ""
    if "# >>> ToolJet WebNova: NVM auto-use >>>" not in txt:
        backup=bashrc.with_name(f".bashrc.webnova-backup-{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}")
        if bashrc.exists(): shutil.copy2(bashrc,backup); yield f"Backup do .bashrc: {backup}"
        bashrc.write_text(txt.rstrip()+"\n"+bloco,encoding="utf-8")
        yield "Seleção automática por .nvmrc adicionada ao .bashrc."
    else: yield "Auto-use do NVM já configurado no .bashrc."


def action_install_deps() -> Generator[str,None,None]:
    yield from cabecalho("install_deps")
    for d in ["server","frontend","plugins"]:
        if not (PROJECT_DIR/d).is_dir(): yield f"ERRO: diretório ausente: {d}"; return
    comandos=["npm install --force -d","npm install --prefix server --force -d","npm install --prefix frontend --force -d","npm run build:plugins"]
    for c in comandos:
        yield f"▶ {c}"
        rc=yield from executar_bash(runtime_shell(c),timeout=3600)
        if rc:
            yield f"ERRO: etapa falhou com código {rc}: {c}"
            return
    yield "Dependências concluídas."


def action_install_infra() -> Generator[str,None,None]:
    yield from cabecalho("install_infra")
    if not cmd_exists("apt-get"):
        yield "ERRO: esta ação foi projetada para Ubuntu/WSL com apt-get."
        return
    pacotes=["postgresql","postgresql-contrib","libpq-dev","build-essential","xz-utils","curl","ca-certificates","openssl"]
    rc=yield from executar(sudo_prefix()+["apt-get","update"],timeout=600)
    if rc:return
    rc=yield from executar(sudo_prefix()+["env","DEBIAN_FRONTEND=noninteractive","apt-get","install","-y",*pacotes],timeout=1200)
    if rc:return
    rc=yield from start_service("postgresql")
    if rc:return

    versao="12.2.0"
    rc,out=run_collect(["bash","-lc",'export PATH="$HOME/.local/bin:$PATH"; postgrest --version'],timeout=10)
    if rc==0 and versao in out:
        yield f"PostgREST {versao} já instalado: {out}"
        return
    arch=platform.machine().lower()
    if arch in ("x86_64","amd64"):
        asset=f"postgrest-v{versao}-linux-static-x64.tar.xz"
    elif arch in ("aarch64","arm64"):
        asset=f"postgrest-v{versao}-ubuntu-aarch64.tar.xz"
    else:
        yield f"ERRO: arquitetura sem artefato configurado para PostgREST: {arch}"
        return
    url=f"https://github.com/PostgREST/postgrest/releases/download/v{versao}/{asset}"
    bindir=Path.home()/".local/bin"; bindir.mkdir(parents=True,exist_ok=True)
    tmp=STATE_DIR/asset
    yield f"Baixando PostgREST oficial: {url}"
    rc=yield from executar(["curl","-fL","--retry","3","-o",str(tmp),url],timeout=600)
    if rc:return
    rc=yield from executar(["tar","-xJf",str(tmp),"-C",str(bindir)],timeout=120)
    if rc:return
    (bindir/"postgrest").chmod(0o755)
    tmp.unlink(missing_ok=True)
    rc,out=run_collect([str(bindir/"postgrest"),"--version"],timeout=10)
    yield out
    if rc or versao not in out: yield "ERRO: versão do PostgREST não foi validada."


def action_create_env() -> Generator[str,None,None]:
    yield from cabecalho("create_env")
    senha=postgres_password_atual()
    if not senha:
        yield "ERRO: configure primeiro a senha do PostgreSQL pelo item 6."
        return
    env_path=PROJECT_DIR/".env"; example=PROJECT_DIR/".env.example"
    if env_path.exists():
        backup=STATE_DIR/f"env-backup-{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}.env"
        shutil.copy2(env_path,backup); yield f"Backup criado: {backup}"
        base=env_path.read_text(encoding="utf-8",errors="replace")
        old=env_parse(env_path)
    elif example.exists():
        base=example.read_text(encoding="utf-8",errors="replace"); old={}; yield "Base: .env.example"
    else:
        base=""; old={}; yield "Aviso: .env.example ausente; criando arquivo mínimo documentado."
    lock=old.get("LOCKBOX_MASTER_KEY") or secrets.token_hex(32)
    secret=old.get("SECRET_KEY_BASE") or secrets.token_hex(64)
    jwt=old.get("PGRST_JWT_SECRET") or secrets.token_hex(32)
    pgdb=old.get("PG_DB") or "tooljet_development"
    tjdb=old.get("TOOLJET_DB") or "tooljet_db"
    uri_pass=urllib.parse.quote(senha,safe="")
    valores={
        "TOOLJET_HOST":"http://localhost:8082","LOCKBOX_MASTER_KEY":lock,"SECRET_KEY_BASE":secret,"NODE_ENV":"development",
        "PG_HOST":"localhost","PG_PORT":"5432","PG_USER":"postgres","PG_PASS":senha,"PG_DB":pgdb,
        "TOOLJET_DB":tjdb,"TOOLJET_DB_USER":"postgres","TOOLJET_DB_HOST":"localhost","TOOLJET_DB_PORT":"5432","TOOLJET_DB_PASS":senha,
        "PGRST_JWT_SECRET":jwt,"PGRST_DB_URI":f"postgres://postgres:{uri_pass}@localhost:5432/{tjdb}","PGRST_LOG_LEVEL":"info","PGRST_DB_PRE_CONFIG":"postgrest.pre_config",
    }
    env_path.write_text(upsert_env(base,valores),encoding="utf-8")
    env_path.chmod(0o600)
    yield f".env gravado com permissão 600: {env_path}"
    yield f"PG_DB={pgdb} | TOOLJET_DB={tjdb}"
    yield "Segredos foram gerados/preservados sem serem exibidos no console."


def database_exists(db: str, senha: str) -> bool:
    rc,_=run_collect(["psql","-h","localhost","-U","postgres","-d","postgres","-tAc",f"SELECT 1 FROM pg_database WHERE datname='{db.replace(chr(39),chr(39)*2)}'"],env={"PGPASSWORD":senha},timeout=15)
    if rc:return False
    rc,out=run_collect(["psql","-h","localhost","-U","postgres","-d","postgres","-tAc",f"SELECT 1 FROM pg_database WHERE datname='{db.replace(chr(39),chr(39)*2)}'"],env={"PGPASSWORD":senha},timeout=15)
    return rc==0 and out.strip()=="1"


def action_prepare_db() -> Generator[str,None,None]:
    yield from cabecalho("prepare_db")
    env=env_parse(PROJECT_DIR/".env"); senha=env.get("PG_PASS") or postgres_password_atual()
    if not senha: yield "ERRO: senha/arquivo .env não disponível."; return
    yield from start_service("postgresql")
    pgdb=env.get("PG_DB","tooljet_development"); tjdb=env.get("TOOLJET_DB","tooljet_db")
    existente=database_exists(pgdb,senha) or database_exists(tjdb,senha)
    yield f"Banco pré-existente detectado: {'SIM' if existente else 'NÃO'}"
    rc=yield from executar_bash(runtime_shell("npm run --prefix server db:create"),timeout=1200)
    if rc:return
    if existente:
        yield "Proteção de dados ativa: usando db:migrate em vez de db:reset."
        rc=yield from executar_bash(runtime_shell("npm run --prefix server db:migrate"),timeout=1800)
    else:
        yield "Instalação nova: executando db:reset conforme guia de contribuição do ToolJet."
        rc=yield from executar_bash(runtime_shell("npm run --prefix server db:reset"),timeout=1800)
    if rc: yield f"ERRO na preparação do banco (rc={rc})"
    else: yield "Bancos preparados com sucesso."


def processo_vivo(nome: str) -> bool:
    with PROC_LOCK:
        p=PROCESSOS.get(nome)
        return bool(p and p.poll() is None)


def iniciar_processo(nome: str, shell_script: str, logfile: Path) -> tuple[bool,str]:
    with PROC_LOCK:
        p=PROCESSOS.get(nome)
        if p and p.poll() is None: return True,f"{nome} já está em execução (PID {p.pid})."
        f=logfile.open("a",encoding="utf-8",buffering=1)
        env=dict(os.environ); env["PATH"]=str(Path.home()/".local/bin")+os.pathsep+env.get("PATH","")
        try:
            p=subprocess.Popen(["bash","-lc",shell_script],cwd=str(PROJECT_DIR),env=env,stdout=f,stderr=subprocess.STDOUT,text=True,start_new_session=True)
        except Exception as e:
            f.close(); return False,str(e)
        PROCESSOS[nome]=p
        (PID_DIR/f"{nome}.pid").write_text(str(p.pid),encoding="utf-8")
        return True,f"{nome} iniciado (PID {p.pid})."


def parar_processo(nome: str, timeout: float=10) -> str:
    with PROC_LOCK: p=PROCESSOS.get(nome)
    if not p or p.poll() is not None:
        (PID_DIR/f"{nome}.pid").unlink(missing_ok=True)
        return f"{nome}: já parado."
    try: os.killpg(p.pid,signal.SIGTERM)
    except ProcessLookupError: pass
    limite=time.time()+timeout
    while time.time()<limite and p.poll() is None: time.sleep(.2)
    if p.poll() is None:
        try: os.killpg(p.pid,signal.SIGKILL)
        except ProcessLookupError: pass
    (PID_DIR/f"{nome}.pid").unlink(missing_ok=True)
    return f"{nome}: encerrado."


def postgrest_script() -> Optional[str]:
    env=env_parse(PROJECT_DIR/".env")
    req=["PGRST_DB_URI","PGRST_JWT_SECRET","PGRST_DB_PRE_CONFIG"]
    if any(not env.get(k) for k in req): return None
    exports=[]
    for k in ["PGRST_DB_URI","PGRST_JWT_SECRET","PGRST_DB_PRE_CONFIG","PGRST_LOG_LEVEL"]:
        if env.get(k): exports.append(f"export {k}={bash_quote(env[k])}")
    exports += ['export PGRST_SERVER_HOST="127.0.0.1"','export PGRST_SERVER_PORT="3001"','export PATH="$HOME/.local/bin:$PATH"']
    return "\n".join(exports)+"\nexec postgrest"


def action_start_all() -> Generator[str,None,None]:
    yield from cabecalho("start_all")
    rc=yield from start_service("postgresql")
    if rc:return
    pg=postgrest_script()
    if pg:
        ok,msg=iniciar_processo("postgrest",pg,LOGS["postgrest"]); yield msg
        if not ok:return
    else: yield "PostgREST não iniciado: .env ainda não contém configuração completa."
    tarefas={
        "plugins":runtime_shell("exec npm --prefix plugins start"),
        "backend":runtime_shell("exec npm --prefix server run start:dev"),
        "frontend":runtime_shell("exec npm --prefix frontend start"),
    }
    for nome,script in tarefas.items():
        ok,msg=iniciar_processo(nome,script,LOGS[nome]); yield msg
        if not ok:return
    yield "Pilha iniciada. Os painéis Backend e Frontend exibem os logs em tempo real."


def action_stop_all() -> Generator[str,None,None]:
    yield from cabecalho("stop_all")
    for nome in ["frontend","backend","plugins","postgrest"]: yield parar_processo(nome)
    yield "PostgreSQL foi preservado para não interromper outros aplicativos locais."


def action_restart_all() -> Generator[str,None,None]:
    yield from cabecalho("restart_all")
    for nome in ["frontend","backend","plugins","postgrest"]: yield parar_processo(nome)
    time.sleep(1)
    yield "Reiniciando..."
    yield from action_start_all()


def action_qa_crud() -> Generator[str,None,None]:
    yield from cabecalho("qa_crud")
    env=env_parse(PROJECT_DIR/".env"); senha=env.get("PG_PASS") or postgres_password_atual(); db=env.get("PG_DB","tooljet_development")
    if not senha: yield "ERRO: configure o PostgreSQL/.env primeiro."; return
    sql="""BEGIN;
CREATE TEMP TABLE webnova_crud_qa(id serial primary key, nome text not null);
INSERT INTO webnova_crud_qa(nome) VALUES ('criado') RETURNING id,nome;
SELECT id,nome FROM webnova_crud_qa;
UPDATE webnova_crud_qa SET nome='atualizado' WHERE nome='criado' RETURNING id,nome;
DELETE FROM webnova_crud_qa WHERE nome='atualizado' RETURNING id,nome;
SELECT count(*) AS restantes FROM webnova_crud_qa;
ROLLBACK;"""
    rc=yield from executar(["psql","-h","localhost","-U","postgres","-d",db,"-v","ON_ERROR_STOP=1","-c",sql],env={"PGPASSWORD":senha},timeout=120)
    if rc==0: yield "QA CRUD concluído e revertido com ROLLBACK."


def action_health_http() -> Generator[str,None,None]:
    yield from cabecalho("health_http")
    for host,port,nome in [("127.0.0.1",8082,"Frontend ToolJet"),("127.0.0.1",3001,"PostgREST")]:
        with socket.socket() as s:
            s.settimeout(2)
            try: s.connect((host,port)); yield f"{nome}: porta {port} ABERTA"
            except OSError as e: yield f"{nome}: porta {port} fechada/indisponível ({e})"
    try:
        req=urllib.request.Request("http://127.0.0.1:8082",headers={"User-Agent":"WebNova-QA"})
        with urllib.request.urlopen(req,timeout=5) as r: yield f"HTTP ToolJet: {r.status} {r.reason}"
    except Exception as e: yield f"HTTP ToolJet: indisponível ({e})"


def action_clear_logs() -> Generator[str,None,None]:
    yield from cabecalho("clear_logs")
    for nome,p in LOGS.items(): p.write_text("",encoding="utf-8"); yield f"Log limpo: {nome}"


def action_project_map() -> Generator[str,None,None]:
    yield from cabecalho("project_map")
    n=0
    for p in sorted(PROJECT_DIR.rglob("*")):
        rel=p.relative_to(PROJECT_DIR)
        if any(x in {"node_modules",".git",".tooljet-webnova"} for x in rel.parts): continue
        if len(rel.parts)>3: continue
        yield ("DIR  " if p.is_dir() else "FILE ")+str(rel)
        n+=1
        if n>=300: yield "Limite de 300 itens atingido."; break


ACTION_FUNCS={
    "webnova_status":action_webnova_status,"tooljet_status":action_tooljet_status,"setup_node":action_setup_node,
    "install_deps":action_install_deps,"install_infra":action_install_infra,"create_env":action_create_env,
    "prepare_db":action_prepare_db,"start_all":action_start_all,"stop_all":action_stop_all,"restart_all":action_restart_all,
    "qa_crud":action_qa_crud,"health_http":action_health_http,"clear_logs":action_clear_logs,"project_map":action_project_map,
}


def configurar_senha_postgres(senha: str) -> tuple[bool,str]:
    global POSTGRES_PASSWORD
    if len(senha)<8:return False,"Use uma senha com pelo menos 8 caracteres."
    if not cmd_exists("psql"):return False,"psql não está instalado. Execute primeiro o item 5."
    if not service_running("postgresql"):
        rc,_=run_collect(sudo_prefix()+["service","postgresql","start"],timeout=30)
        if rc:return False,"Não foi possível iniciar PostgreSQL."
    literal=senha.replace("'","''")
    sql=f"ALTER USER postgres WITH PASSWORD '{literal}';"
    cmd=sudo_prefix()+["-u","postgres","psql","-v","ON_ERROR_STOP=1","-d","postgres","-c",sql] if sudo_prefix() else ["sudo","-u","postgres","psql","-v","ON_ERROR_STOP=1","-d","postgres","-c",sql]
    # Quando o script está rodando como root, sudo pode não existir. Use runuser como fallback.
    if os.geteuid()==0:
        if cmd_exists("runuser"): cmd=["runuser","-u","postgres","--","psql","-v","ON_ERROR_STOP=1","-d","postgres","-c",sql]
        elif cmd_exists("sudo"): cmd=["sudo","-u","postgres","psql","-v","ON_ERROR_STOP=1","-d","postgres","-c",sql]
        else:return False,"Não há runuser/sudo para executar psql como postgres."
    rc,out=run_collect(cmd,timeout=30)
    if rc:return False,"Falha ao alterar senha: "+out[-500:]
    rc,out=run_collect(["psql","-h","localhost","-U","postgres","-d","postgres","-tAc","SELECT 1"],env={"PGPASSWORD":senha},timeout=20)
    if rc or out.strip()!="1":return False,"Senha foi alterada, mas a autenticação TCP de validação falhou: "+out[-300:]
    POSTGRES_PASSWORD=senha
    return True,"Senha configurada e validada com SELECT 1."


HTML=r'''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark light"><title>ToolJet WebNova</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Imprima&display=swap');
:root{--bg:#071016;--bg2:#0d1724;--panel:rgba(16,27,42,.86);--panel2:rgba(21,38,58,.77);--line:rgba(164,213,255,.17);--text:#edf7ff;--muted:#9fb3c8;--brand:#78f7d0;--brand2:#8da2ff;--warn:#ffd166;--bad:#ff6b8a;--ok:#73f59f;--radius:22px;--shadow:rgba(0,0,0,.34)}
body.light{--bg:#f5f8fb;--bg2:#eaf0f7;--panel:rgba(255,255,255,.9);--panel2:rgba(255,255,255,.78);--line:rgba(32,68,98,.16);--text:#0c1724;--muted:#526579;--shadow:rgba(28,53,84,.14)}
*{box-sizing:border-box}html,body{height:100%}body{margin:0;font-family:"Imprima",system-ui,sans-serif;color:var(--text);background:radial-gradient(circle at 10% 6%,rgba(120,247,208,.19),transparent 28%),radial-gradient(circle at 85% 13%,rgba(141,162,255,.23),transparent 32%),linear-gradient(145deg,var(--bg),var(--bg2));overflow:hidden}
button,input{font:inherit}.app{height:100vh;display:grid;grid-template-columns:285px minmax(0,1fr);gap:14px;padding:14px}.panel{border:1px solid var(--line);background:var(--panel);box-shadow:0 24px 80px var(--shadow);backdrop-filter:blur(22px)}
.sidebar{border-radius:28px;padding:15px;display:flex;flex-direction:column;overflow:hidden}.brand{display:flex;gap:11px;align-items:center;padding:12px;border-radius:19px;background:linear-gradient(135deg,rgba(120,247,208,.14),rgba(141,162,255,.1))}.logo{width:44px;height:44px;border-radius:15px;display:grid;place-items:center;font-size:23px;background:linear-gradient(135deg,var(--brand),var(--brand2));color:#071016}.brand h1{font-size:17px;margin:0}.brand p{font-size:11px;color:var(--muted);margin:4px 0 0}.search{margin:13px 0;padding:10px 12px;border:1px solid var(--line);border-radius:15px;background:rgba(255,255,255,.04)}.search input{width:100%;border:0;outline:0;background:transparent;color:var(--text)}
.nav{overflow:auto}.group{margin:13px 7px 6px;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.12em}.navbtn{width:100%;display:grid;grid-template-columns:28px 1fr auto;gap:8px;align-items:center;text-align:left;padding:10px;border:1px solid transparent;border-radius:14px;background:transparent;color:var(--text);cursor:pointer}.navbtn:hover{background:rgba(120,247,208,.1);border-color:rgba(120,247,208,.2)}.navbtn small{color:var(--muted)}
.main{border-radius:28px;overflow:auto;padding:16px}.top{display:flex;justify-content:space-between;align-items:center;gap:12px}.topactions{display:flex;gap:8px}.btn{border:1px solid var(--line);background:rgba(255,255,255,.06);color:var(--text);border-radius:13px;padding:9px 12px;cursor:pointer}.btn:hover{background:rgba(120,247,208,.11)}.hero{display:grid;grid-template-columns:1.15fr .85fr;gap:13px;margin:14px 0}.card,.metric,.logsWrap{border:1px solid var(--line);background:var(--panel2);border-radius:20px;padding:15px}.eyebrow{color:var(--brand);font-size:11px;letter-spacing:.13em;text-transform:uppercase}h2{font-size:31px;margin:7px 0 8px;letter-spacing:-.035em}.muted{color:var(--muted)}.metrics{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}.metric b{display:block;font-size:20px;margin-top:4px}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:11px}.actionCard{position:relative;cursor:pointer;min-height:155px;transition:.18s transform,.18s border}.actionCard:hover{transform:translateY(-2px);border-color:rgba(120,247,208,.31)}.actionCard .ico{font-size:25px}.actionCard h3{margin:8px 0 6px;font-size:16px}.badge{display:inline-block;padding:4px 7px;border-radius:999px;border:1px solid var(--line);font-size:10px;color:var(--muted)}
.logsTitle{display:flex;justify-content:space-between;align-items:center;margin:15px 0 8px}.logs{display:grid;grid-template-columns:1fr 1fr;gap:11px}.logbox{min-height:260px;max-height:360px;overflow:auto;background:#04090d;color:#cbe8ff;border:1px solid rgba(120,247,208,.16);border-radius:17px;padding:12px;font:12px/1.45 ui-monospace,SFMono-Regular,Consolas,monospace;white-space:pre-wrap}.consoleDrawer{position:fixed;right:14px;bottom:14px;width:min(560px,calc(100vw - 28px));height:42vh;border-radius:20px;padding:12px;z-index:20;display:flex;flex-direction:column}.consoleDrawer.hidden{display:none}.consoleHead{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.console{flex:1;overflow:auto;background:#03070a;border-radius:14px;padding:11px;font:12px/1.45 ui-monospace,Consolas,monospace;white-space:pre-wrap;color:#d8f2ff}
.modal{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;place-items:center;z-index:40;padding:16px}.modal.show{display:grid}.modalCard{width:min(500px,100%);border-radius:22px;padding:18px}.field{display:grid;gap:6px;margin:12px 0}.field input{padding:11px;border-radius:12px;border:1px solid var(--line);background:rgba(255,255,255,.06);color:var(--text);outline:0}.toast{position:fixed;left:50%;bottom:18px;transform:translateX(-50%);padding:10px 14px;border:1px solid var(--line);border-radius:13px;background:var(--panel);display:none;z-index:60}.toast.show{display:block}
@media(max-width:1100px){.cards{grid-template-columns:repeat(2,1fr)}.hero{grid-template-columns:1fr}.logs{grid-template-columns:1fr}}
@media(max-width:760px){body{overflow:auto}.app{height:auto;min-height:100vh;grid-template-columns:1fr;padding:8px}.sidebar{position:relative;max-height:360px}.main{overflow:visible}.cards{grid-template-columns:1fr}.top{align-items:flex-start}.logs .logbox{min-height:210px}.consoleDrawer{right:8px;bottom:8px;width:calc(100vw - 16px)}}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
</style></head><body><div class="app">
<aside class="sidebar panel"><div class="brand"><div class="logo">🌌</div><div><h1>ToolJet WebNova</h1><p>Control Center • pt-BR</p></div></div><div class="search"><input id="search" placeholder="Buscar ação..." aria-label="Buscar ação"></div><nav class="nav" id="nav"></nav></aside>
<main class="main panel"><div class="top"><div><div class="eyebrow">TUI WEB LOCAL</div><b>ToolJet Control Center</b></div><div class="topactions"><button class="btn" id="theme">🌗 Tema</button><button class="btn" id="consoleBtn">🖥️ Console</button></div></div>
<section class="hero"><div class="card"><div class="eyebrow">WEBNOVA ATIVO</div><h2>Um único painel para instalar, configurar e executar o ToolJet.</h2><div class="muted">Sem cockpit tmux. Todas as ações operacionais são disparadas por esta interface WebNova local.</div></div><div class="metrics"><div class="metric"><span>Node exigido</span><b id="mNode">...</b></div><div class="metric"><span>npm exigido</span><b id="mNpm">...</b></div><div class="metric"><span>PostgreSQL</span><b id="mPg">...</b></div><div class="metric"><span>.env</span><b id="mEnv">...</b></div></div></section>
<section class="cards" id="cards"></section>
<div class="logsTitle"><div><b>Logs simultâneos</b><div class="muted">Backend e Frontend em tempo real</div></div><button class="btn" onclick="runAction('clear_logs')">🧹 Limpar</button></div>
<section class="logs"><div class="logsWrap"><div class="eyebrow">BACKEND</div><pre class="logbox" id="backendLog"></pre></div><div class="logsWrap"><div class="eyebrow">FRONTEND</div><pre class="logbox" id="frontendLog"></pre></div></section>
</main></div>
<div class="consoleDrawer panel" id="drawer"><div class="consoleHead"><div><b>Console de operações</b><div class="muted" id="consoleState">Pronto.</div></div><button class="btn" onclick="toggleConsole()">✕</button></div><pre class="console" id="console">WebNova pronto.\n</pre></div>
<div class="modal" id="passwordModal"><div class="modalCard panel"><div class="eyebrow">POSTGRESQL</div><h3>Definir senha do usuário postgres</h3><div class="muted">A senha não é exibida no console e não é colocada na URL.</div><div class="field"><label>Nova senha</label><input type="password" id="pgPass" autocomplete="new-password"></div><div class="field"><label>Confirmar senha</label><input type="password" id="pgPass2" autocomplete="new-password"></div><div style="display:flex;justify-content:flex-end;gap:8px"><button class="btn" onclick="closePassword()">Cancelar</button><button class="btn" onclick="savePassword()">Configurar</button></div></div></div>
<div class="toast" id="toast"></div>
<script>
const TOKEN=new URLSearchParams(location.search).get('token')||'';let ACTIONS=[];const $=q=>document.querySelector(q);
function toast(t){const e=$('#toast');e.textContent=t;e.classList.add('show');setTimeout(()=>e.classList.remove('show'),2600)}
async function api(path,opt={}){const sep=path.includes('?')?'&':'?';const r=await fetch(path+sep+'token='+encodeURIComponent(TOKEN),opt);const j=await r.json().catch(()=>({erro:'Resposta inválida'}));if(!r.ok)throw new Error(j.erro||('HTTP '+r.status));return j}
function render(items){const groups={};items.forEach(a=>(groups[a.grupo]??=[]).push(a));$('#nav').innerHTML=Object.entries(groups).map(([g,arr])=>`<div class="group">${g}</div>`+arr.map(a=>`<button class="navbtn" data-id="${a.id}"><span>${a.icone}</span><span>${a.titulo}</span><small>›</small></button>`).join('')).join('');$('#cards').innerHTML=items.map(a=>`<article class="card actionCard" data-id="${a.id}"><div class="ico">${a.icone}</div><span class="badge">${a.grupo} • ${a.risco}</span><h3>${a.titulo}</h3><div class="muted">${a.descricao}</div></article>`).join('');document.querySelectorAll('[data-id]').forEach(e=>e.onclick=()=>selectAction(e.dataset.id));}
function selectAction(id){if(id==='postgres_password'){openPassword();return}runAction(id)}
function runAction(id){const c=$('#console'),s=$('#consoleState');$('#drawer').classList.remove('hidden');c.textContent+=`\n▶ ${id}\n`;s.textContent='Executando...';const es=new EventSource(`/events?action=${encodeURIComponent(id)}&token=${encodeURIComponent(TOKEN)}`);es.onmessage=e=>{c.textContent+=e.data+'\n';c.scrollTop=c.scrollHeight};es.addEventListener('done',e=>{s.textContent='Concluído: '+id;es.close();refresh();toast('Ação concluída')});es.onerror=()=>{s.textContent='Streaming encerrado.';es.close();refresh()}}
function logStream(name,el){const es=new EventSource(`/log-stream?name=${name}&token=${encodeURIComponent(TOKEN)}`);es.onmessage=e=>{if(e.data==='__WEBNOVA_CLEAR__'){el.textContent='';return}el.textContent+=e.data+'\n';if(el.textContent.length>200000)el.textContent=el.textContent.slice(-150000);el.scrollTop=el.scrollHeight};return es}
async function refresh(){try{const s=await api('/api/status');$('#mNode').textContent=s.node_req;$('#mNpm').textContent=s.npm_req;$('#mPg').textContent=s.postgres?'ATIVO':'PARADO';$('#mEnv').textContent=s.env_existe?'OK':'AUSENTE'}catch(e){}}
function toggleConsole(){$('#drawer').classList.toggle('hidden')}function openPassword(){$('#passwordModal').classList.add('show')}function closePassword(){$('#passwordModal').classList.remove('show')}
async function savePassword(){const a=$('#pgPass').value,b=$('#pgPass2').value;if(a!==b){toast('As senhas não coincidem');return}try{const j=await api('/api/postgres-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({senha:a})});toast(j.mensagem);$('#pgPass').value='';$('#pgPass2').value='';closePassword();refresh()}catch(e){toast(e.message)}}
$('#theme').onclick=()=>document.body.classList.toggle('light');$('#consoleBtn').onclick=toggleConsole;$('#search').oninput=e=>{const q=e.target.value.toLowerCase();render(ACTIONS.filter(a=>(a.titulo+a.descricao+a.grupo+a.id).toLowerCase().includes(q)))};
api('/api/actions').then(a=>{ACTIONS=a;render(a);refresh();setInterval(refresh,4000);logStream('backend',$('#backendLog'));logStream('frontend',$('#frontendLog'))}).catch(e=>toast(e.message));
</script></body></html>'''


def token_ok(query: Dict[str,List[str]], headers: http.client.HTTPMessage) -> bool:
    recebido=(query.get("token") or [""])[0] or headers.get("X-WebNova-Token","")
    return secrets.compare_digest(recebido,TOKEN)


class Handler(http.server.BaseHTTPRequestHandler):
    server_version="ToolJetWebNova/3.0"
    protocol_version="HTTP/1.1"
    def log_message(self,fmt,*args):
        sys.stderr.write("[%s] %s\n"%(self.log_date_time_string(),fmt%args))
    def headers_base(self):
        self.send_header("Cache-Control","no-store")
        self.send_header("X-Content-Type-Options","nosniff")
        self.send_header("X-Frame-Options","DENY")
        self.send_header("Referrer-Policy","no-referrer")
        self.send_header("Content-Security-Policy","default-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; script-src 'self' 'unsafe-inline'; connect-src 'self'")
    def json(self,obj,status=200):
        data=json.dumps(obj,ensure_ascii=False).encode()
        self.send_response(status);self.send_header("Content-Type","application/json; charset=utf-8");self.headers_base();self.send_header("Content-Length",str(len(data)));self.end_headers();self.wfile.write(data)
    def do_GET(self):
        p=urllib.parse.urlparse(self.path);q=urllib.parse.parse_qs(p.query)
        if p.path=="/":
            data=HTML.encode();self.send_response(200);self.send_header("Content-Type","text/html; charset=utf-8");self.headers_base();self.send_header("Content-Length",str(len(data)));self.end_headers();self.wfile.write(data);return
        if not token_ok(q,self.headers):self.json({"erro":"token inválido"},403);return
        if p.path=="/api/status":self.json(status_payload());return
        if p.path=="/api/actions":self.json(ACTIONS);return
        if p.path=="/api/history":
            with HIST_LOCK:self.json(HISTORICO);return
        if p.path=="/events":self.stream_action((q.get("action") or [""])[0]);return
        if p.path=="/log-stream":self.stream_log((q.get("name") or [""])[0]);return
        self.json({"erro":"rota não encontrada"},404)
    def do_POST(self):
        p=urllib.parse.urlparse(self.path);q=urllib.parse.parse_qs(p.query)
        if not token_ok(q,self.headers):self.json({"erro":"token inválido"},403);return
        try:n=int(self.headers.get("Content-Length","0"));data=json.loads(self.rfile.read(n) or b"{}")
        except Exception:self.json({"erro":"JSON inválido"},400);return
        if p.path=="/api/postgres-password":
            senha=str(data.get("senha", ""));ok,msg=configurar_senha_postgres(senha)
            self.json({"mensagem":msg} if ok else {"erro":msg},200 if ok else 400);return
        self.json({"erro":"rota não encontrada"},404)
    def stream_action(self,id_acao:str):
        if id_acao=="postgres_password" or id_acao not in ACTION_FUNCS:
            self.send_response(404);self.send_header("Content-Type","text/event-stream; charset=utf-8");self.headers_base();self.end_headers();return
        self.send_response(200);self.send_header("Content-Type","text/event-stream; charset=utf-8");self.send_header("Connection","keep-alive");self.headers_base();self.end_headers()
        inicio=time.time();linhas=0;status="ok"
        try:
            for line in ACTION_FUNCS[id_acao]():
                linhas+=1;safe=str(line).replace("\r","").replace("\n"," ")
                self.wfile.write(f"data: {safe}\n\n".encode());self.wfile.flush()
        except (BrokenPipeError,ConnectionResetError):status="cliente_desconectou"
        except Exception as e:
            status="erro"
            try:self.wfile.write(f"data: ERRO: {str(e).replace(chr(10),' ')}\n\n".encode());self.wfile.flush()
            except Exception:pass
        finally:
            registrar(id_acao,status,linhas,time.time()-inicio)
            try:self.wfile.write(f"event: done\ndata: {status}\n\n".encode());self.wfile.flush()
            except Exception:pass
    def stream_log(self,nome:str):
        if nome not in LOGS:self.json({"erro":"log inválido"},404);return
        self.send_response(200);self.send_header("Content-Type","text/event-stream; charset=utf-8");self.send_header("Connection","keep-alive");self.headers_base();self.end_headers();path=LOGS[nome];pos=0
        try:
            while not SHUTTING_DOWN:
                size=path.stat().st_size if path.exists() else 0
                if size<pos:pos=0;self.wfile.write(b"data: __WEBNOVA_CLEAR__\n\n");self.wfile.flush()
                if size>pos:
                    with path.open("r",encoding="utf-8",errors="replace") as f:
                        f.seek(pos)
                        for line in f:self.wfile.write(f"data: {line.rstrip()}\n\n".encode());self.wfile.flush()
                        pos=f.tell()
                else:self.wfile.write(b": keepalive\n\n");self.wfile.flush()
                time.sleep(.7)
        except (BrokenPipeError,ConnectionResetError):return
        except Exception:return


def achar_porta(host:str,inicial:int)->int:
    for p in range(inicial,inicial+50):
        with socket.socket() as s:
            try:s.bind((host,p));return p
            except OSError:pass
    raise RuntimeError("Nenhuma porta WebNova livre encontrada.")


def abrir_navegador(url:str)->None:
    # WSL: preferir o navegador do Windows.
    cmd=Path("/mnt/c/Windows/System32/cmd.exe")
    if cmd.exists():
        try:
            subprocess.Popen([str(cmd),"/c","start","",url],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            return
        except Exception:pass
    try:
        if webbrowser.open(url):return
    except Exception:pass
    if cmd_exists("xdg-open"):
        try:subprocess.Popen(["xdg-open",url],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception:pass


def self_test()->int:
    erros=[]
    ids=[a["id"] for a in ACTIONS]
    if len(ids)!=len(set(ids)):erros.append("IDs duplicados")
    for i in ids:
        if i=="postgres_password":continue
        if i not in ACTION_FUNCS:erros.append(f"ação sem função: {i}")
    for trecho in ["ToolJet WebNova","EventSource","BACKEND","FRONTEND","/api/postgres-password","@media(max-width:760px)"]:
        if trecho not in HTML:erros.append(f"componente ausente: {trecho}")
    fonte=SCRIPT_PATH.read_text(encoding="utf-8",errors="replace")
    assinatura_legada="tmux "+"new-session"
    if assinatura_legada in fonte:erros.append("cockpit tmux legado encontrado")
    if erros:
        print("SELF-TEST FALHOU");[print("-",e) for e in erros];return 1
    print(f"SELF-TEST OK: {len(ACTIONS)} ações WebNova reais.")
    print("Interface: WebNova Web local; cockpit tmux legado ausente.")
    print("Painéis simultâneos: Backend + Frontend.")
    return 0


def encerrar():
    global SHUTTING_DOWN;SHUTTING_DOWN=True
    for n in ["frontend","backend","plugins","postgrest"]:
        try:parar_processo(n,4)
        except Exception:pass


def main(argv:List[str])->int:
    if "--self-test" in argv:return self_test()
    if "--list-actions-json" in argv:print(json.dumps(ACTIONS,ensure_ascii=False,indent=2));return 0
    porta=achar_porta(HOST,PORT_DEFAULT)
    server=http.server.ThreadingHTTPServer((HOST,porta),Handler)
    url=f"http://{HOST}:{porta}/?token={urllib.parse.quote(TOKEN)}"
    print("="*78)
    print(f"{APP_NOME} v{APP_VERSAO}")
    print("Interface única: WebNova")
    print(f"Projeto: {PROJECT_DIR}")
    print(f"URL local: {url}")
    print("O cockpit tmux antigo NÃO faz parte desta versão.")
    print("="*78,flush=True)
    if "--no-browser" not in argv:threading.Timer(.6,abrir_navegador,args=(url,)).start()
    def stop(sig,frame):
        encerrar();threading.Thread(target=server.shutdown,daemon=True).start()
    signal.signal(signal.SIGINT,stop);signal.signal(signal.SIGTERM,stop)
    try:server.serve_forever(poll_interval=.4)
    finally:encerrar();server.server_close()
    return 0

if __name__=="__main__":raise SystemExit(main(sys.argv[1:]))
PY_WEBNOVA

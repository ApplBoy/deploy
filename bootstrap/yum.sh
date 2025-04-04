#!/bin/bash
# MIT License (c) 2025 Saulo José
set -e
dbs_supported=("mariadb-10.4" "postgres-17")
trap_ctrlc=0; on_ctrlc(){ ((trap_ctrlc++))||{ echo -e "\nPressione CTRL+C novamente para sair."; return; }; echo -e "\nEncerrando."; exit 1; }; trap on_ctrlc SIGINT
for arg; do [[ $arg == -h || $arg == --help ]] && echo -e "Uso: $0 [--db=mariadb-10.4,postgres-17]\nDBs suportados: ${dbs_supported[*]}" && exit 0; [[ $arg == --db=* ]] && dbs="${arg#*=}"; done
type -p gh >/dev/null || { type -p yum-config-manager >/dev/null || sudo yum install -y yum-utils; sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo; sudo yum install -y gh; }
gh config set -h github.com git_protocol https
UA="User-Agent: curl"; AC="Accept: application/vnd.github+json"
skip_auth=0
gh auth status --hostname github.com >/dev/null 2>&1 && { read -r -p $'\e[1mJá está logado. Usar essa sessão? [Y/n] \e[0m' s; [[ $s =~ ^[Nn]$ ]] || skip_auth=1; }
if [[ $skip_auth -eq 0 ]]; then
  while :; do
    read -r -p $'\e[1mDigite seu GitHub token: \e[0m' token
    [[ $token =~ ^ghp_[A-Za-z0-9]{36,}$ ]] || { echo "Token inválido"; continue; }
    auth="Authorization: token $token"
    user=$(curl -s -H "$auth" -H "$UA" -H "$AC" https://api.github.com/user | grep '"login"' | cut -d '"' -f4)
    [[ $user ]] || { echo "Token recusado"; continue; }
    echo "Logado como: $user"
    read -r -p $'\e[1mDigite o repositório: \e[0m' repo
    repo=$(echo "$repo" | sed -E 's#(git@|https://)github.com[:/]##;s#\.git$##')
    perms=$(curl -s -H "$auth" -H "$UA" -H "$AC" https://api.github.com/repos/"$repo")
    echo -n "Permissões: "; for p in pull push admin; do grep -q "\"$p\": true" <<<"$perms" && echo -n "$p "; done; echo
    read -r -p $'\e[1mPermissões estão corretas? [y/N] \e[0m' y; [[ $y =~ ^[Yy]$ ]] || continue
    echo "Abra a janela de login:"; gh auth login; break
  done
else read -r -p $'\e[1mDigite o repositório: \e[0m' repo; repo=$(echo "$repo" | sed -E 's#(git@|https://)github.com[:/]##;s#\.git$##'); fi
dir=$(basename "$repo")
[ -d "$dir" ] && { read -r -p $'\e[1mJá existe. Re-clonar? [y/N] \e[0m' r; [[ $r =~ ^[Yy]$ ]] && rm -rf "$dir" && gh repo clone "$repo" || cd "$dir" && git pull && cd - >/dev/null; } || gh repo clone "$repo"
type -p docker >/dev/null || { sudo dnf -y install dnf-plugins-core; sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo; sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; sudo systemctl enable --now docker; sudo docker run hello-world; }
[ -d ~/.local/src/fzf ] || { mkdir -p ~/.local/src; git clone --depth 1 https://github.com/junegunn/fzf.git ~/.local/src/fzf; ~/.local/src/fzf/install --key-bindings --completion --no-update-rc; command -v fzf && eval "$(fzf --bash)"; }
type -p kubectl >/dev/null || { cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF
sudo yum install -y kubectl; }

# DB install
IFS=',' read -ra db_arr <<<"$dbs"
for db in "${db_arr[@]}"; do
  [[ $db == mariadb-10.4 ]] && {
    sudo yum install -y wget
    wget -q https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    chmod +x mariadb_repo_setup && sudo ./mariadb_repo_setup && rm -f mariadb_repo_setup
    sudo yum install -y MariaDB-server && sudo systemctl start mariadb && sudo mariadb-secure-installation
  }
  [[ $db == postgres-17 ]] && {
    sudo dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sudo dnf -qy module disable postgresql
    sudo dnf install -y postgresql17-server
    sudo /usr/pgsql-17/bin/postgresql-17-setup initdb
    sudo systemctl enable postgresql-17 && sudo systemctl start postgresql-17
  }
done

#!/bin/bash
# MIT License (c) 2025 Saulo José
R='\033[1;31m';N='\033[0m';B='\033[1m';UA="User-Agent: curl";AC="Accept: application/vnd.github+json"
type -p yum||{ printf "${R}Yum not found. Are you sure this is a Red Hat-based distro?${N}\n";exit 1;}
set -e;sudo -v||{ printf "${R}You don't have sudo privileges.${N}\n";exit 1;}
[[ $1 == -h || $1 == --help ]]&&printf "Usage: $0 [--db=mariadb-10.4,postgres-17] [--node] [--nginx] [--gh-token-docker]\n"&&exit
printf '    ____  ____  ____  _____________________  ___    ____ \n   / __ )/ __ \\/ __ \\/_  __/ ___/_  __/ __ \\/   |  / __ \\\n  / __  / / / / / / / / /  \\__ \\ / / / /_/ / /| | / /_/ /\n / /_/ / /_/ / /_/ / / /  ___/ // / / _, _/ ___ |/ ____/ \n/_____/\\____/\\____/ /_/  /____//_/ /_/ |_/_/  |_/_/\n'
for a;do [[ $a == --db=* ]]&&dbs="${a#*=}";[[ $a == --node ]]&&node=1;[[ $a == --nginx ]]&&nginx=1;[[ $a == --gh-token-docker ]]&&tokendocker=1;done
type -p gh||{ type -p yum-config-manager||sudo yum -y install yum-utils;sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo;sudo yum -y install gh;}
gh config set -h github.com git_protocol https
gh auth status -h github.com >/dev/null 2>&1&&{ printf "${B}Already authenticated. Use current session? [Y/n] ${N}";read s;[[ $s =~ ^[Nn]$ ]]||skip_auth=1;}
[[ $skip_auth != 1 ]]&&while :;do printf "${B}GitHub token: ${N}";read t;[[ $t =~ ^ghp_[A-Za-z0-9]{36,}$ ]]||{ printf "${R}Invalid token.${N}\n";continue;};a="Authorization: token $t";u=$(curl -s -H "$a" -H "$UA" -H "$AC" https://api.github.com/user|grep login|cut -d'"' -f4);[[ $u ]]||{ printf "${R}Token rejected.${N}\n";continue;};printf "${B}Logged in as: $u${N}\n${B}Repository: ${N}";read r;r=$(sed -E 's#(git@|https://)github.com[:/]##;s#\.git$##'<<<"$r");perms=$(curl -s -H "$a" -H "$UA" -H "$AC" https://api.github.com/repos/"$r");printf "Permissions: ";for p in pull push admin;do grep -q "\"$p\": true"<<<"$perms"&&printf "$p ";done;printf "\n${B}Are these permissions correct? [y/N] ${N}";read y;[[ $y =~ ^[Yy]$ ]]&&printf "${B}Opening auth window...${N}\n"&&gh auth login&&break;done
[[ $skip_auth == 1 ]]&&printf "${B}Repository: ${N}";read r;r=$(sed -E 's#(git@|https://)github.com[:/]##;s#\.git$##'<<<"$r")
d=$(basename "$r");[ -d "$d" ]&&{ printf "${B}Re-clone? [y/N] ${N}";read y;[[ $y =~ ^[Yy]$ ]]&&rm -rf "$d"&&gh repo clone "$r"||cd "$d"&&git pull&&cd -; }||gh repo clone "$r"
type -p docker||{ sudo yum -y install dnf-plugins-core;sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo;sudo yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;sudo systemctl enable --now docker;sudo docker run hello-world;}
sudo usermod -aG docker "$USER"
(! docker info|grep -q Username||{ printf "${B}Already logged in. Re-login? [y/N] ${N}";read d;[[ $d =~ ^[Yy]$ ]];})&&docker logout ghcr.io 2>/dev/null;([[ $tokendocker == 1 ]]&&echo "$t"|docker login ghcr.io -u "$u" --password-stdin||docker login ghcr.io -u "$u")
[ -d ~/.local/src/fzf ]||{ mkdir -p ~/.local/src;git clone --depth 1 https://github.com/junegunn/fzf.git ~/.local/src/fzf;~/.local/src/fzf/install --key-bindings --completion --no-update-rc;}
type -p kubectl||{ printf "[kubernetes]\nname=Kubernetes\nbaseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/\nenabled=1\ngpgcheck=1\ngpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key"|sudo tee /etc/yum.repos.d/kubernetes.repo;sudo yum -y install kubectl;}
sudo yum -y install epel-release&&grep -q "Oracle Linux" /etc/os-release&&sudo yum -y install oracle-epel-release-el8&&sudo yum config-manager --enable ol8_developer_EPEL;sudo yum -y update
[[ $nginx == 1 ]]&&sudo yum -y install certbot python3-certbot-nginx nginx policycoreutils-python-utils&&sudo systemctl enable --now nginx&&for p in 8080 8832;do sudo semanage port -a -t http_port_t -p tcp "$p"||sudo semanage port -m -t http_port_t -p tcp "$p";done&&sudo setsebool -P httpd_can_network_connect 1
IFS=',' read -ra db_arr<<<"$dbs";for db in "${db_arr[@]}";do 
[[ $db == mariadb-10.4 ]]&&{ sudo yum -y install wget;wget -q https://downloads.mariadb.com/MariaDB/mariadb_repo_setup;chmod +x mariadb_repo_setup;sudo ./mariadb_repo_setup;rm -f mariadb_repo_setup;sudo yum -y install MariaDB-server;sudo systemctl start mariadb;sudo mariadb-secure-installation; };
[[ $db == postgres-17 ]]&&{ sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm;sudo yum -qy module disable postgresql;sudo yum -y install postgresql17-server;sudo /usr/pgsql-17/bin/postgresql-17-setup initdb;sudo systemctl enable postgresql-17;sudo systemctl start postgresql-17; };done
[[ $node == 1 ]]&&curl -sL https://rpm.nodesource.com/setup_18.x|sudo bash -&&sudo yum -y install nodejs

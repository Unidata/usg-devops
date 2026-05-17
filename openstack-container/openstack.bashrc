# .bashrc

if [ "$(id -u)" -eq 0 ]; then
  export HOME=/root
  export HISTFILE=/root/.bash_history

  if [[ $- == *i* ]]; then
    echo
    echo "WARNING: You are root inside this container."
    echo "Most work should be done as the openstack user."
    echo
    echo "Prefer entering as openstack:"
    echo "  docker exec -u openstack -it <container> bash"
    echo
    echo "Or switch now:"
    echo "  exec gosu openstack bash"
    echo
  fi
fi

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ll='ls -alF'
alias la='ls -A'

alias o='openstack'
alias ofl='openstack floating ip list'
alias ofc='openstack floating ip create public'
alias osl='openstack server list'
alias onl='openstack network list'
alias ovl='openstack volume list'
alias ocl='openstack coe cluster list'
alias ocs='openstack coe cluster show'
alias k='kubectl'
alias kctl='kubectl'
alias kgn='kubectl get nodes'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias h='history'
alias hist='history'

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

source /home/openstack/bin/openrc.sh

function set_prompt() {
  local cluster_name="${CLUSTER:-openstack}"
  local user_color

  if [ "$(id -u)" -eq 0 ]; then
    user_color='\[\e[1;41m\]\[\e[1;37m\]'
  else
    user_color='\[\e[1;33m\]'
  fi

  PS1='\[\e[1;32m\]❯'"${user_color}"' \u\[\e[1;31m\] ('"$cluster_name"') \[\e[1;34m\]\w\[\e[0m\] ➜ '
}

PROMPT_COMMAND=set_prompt

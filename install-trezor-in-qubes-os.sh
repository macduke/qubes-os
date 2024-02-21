#!/bin/bash
###############################################################################
# Script to install the trezor suite on qube-os.                              #
# Copyright (C) 2024 Thorsten Seeger                                          #
#                                                                             #
#    This program is free software: you can redistribute it and/or modify     #
#    it under the terms of the GNU General Public License as published by     #
#    the Free Software Foundation, either version 3 of the License, or        #
#    (at your option) any later version.                                      #
#                                                                             #
#    This program is distributed in the hope that it will be useful,          #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
#    GNU General Public License for more details.                             #
#                                                                             #
#    You should have received a copy of the GNU General Public License        #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.    #
###############################################################################

# qvm-template list --enablerepo=qubes-templates-community
# qvm-template list

# https://is.gd/EkyLdG
# https://t1p.de/sxzez


# qvm-run --pass-io --dispvm fedora-36-dvm "curl -sL https://is.gd/EkyLdG" > install-trezor-in-qubes-os.sh && \
# chmod +x install-trezor-in-qubes-os.sh && ./install-trezor-in-qubes-os.sh


###############################################################################
# INIT
###############################################################################
function init::variables(){
  utils::ui::print::function_line_in

  _old_fedora_template_name='fedora-36'
  _old_fedora_dvm_template_name='fedora-36-dvm'

  _fedora_template_name='fedora-38'
  _fedora_dvm_template_name='fedora-38-dvm'
  _fedora_sys_template_name='fedora-38-sys'
  _fedora_sys_dvm_template_name='fedora-38-sys-dvm'

  _whonix_ws_template_name='whonix-ws-16'
  _whonix_gw_template_name='whonix-gw-16'

  _whonix_ws_crypto_template_name='whonix-ws-16-crypto'
  _whonix_ws_trezor_wm_name='whonix-ws-16-trezor'

  _skip_all_template_updates='FALSE'

  # API-Endpunkt für die neueste Release-Version
  # GitHub repository
  _git_trezor_repo='trezor/trezor-suite'
  _trezor_release_url="https://api.github.com/repos/${_git_trezor_repo}/releases/latest"

  _qvmrun="qvm-run --quiet --pass-io --no-colour-output \
                   --no-colour-stderr --filter-escape-chars"

  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::fedora::update_os(){
  utils::ui::print::function_line_in
  local    p_system="${1}" ; shift
  # Not sure if necessary
  utils::qvm::start ${p_system}

  ${_qvmrun} ${p_system} 'sudo dnf -y --quiet install gnome-packagekit-updater'
  ${_qvmrun} ${p_system} 'sudo dnf -y --quiet clean all'
  ${_qvmrun} ${p_system} 'sudo dnf -y --quiet update'
  ${_qvmrun} ${p_system} 'sudo dnf -y --quiet upgrade'
  ${_qvmrun} ${p_system} 'sudo dnf -y --quiet clean all'

  utils::ui::print::info 'sudo fstrim -av'
  ${_qvmrun} ${p_system} 'sudo fstrim -av'

  utils::qvm::shutdown ${p_system}
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::update_all_templates(){
  [[ ${_skip_all_template_updates^^} == 'TRUE' ]] && return 0
  utils::ui::print::function_line_in
  sudo qubesctl --skip-dom0 \
                --max-concurrency 2 \
                --templates \
                state.sls \
                update.qubes-vm
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::update_dom0(){
  [[ ${_skip_all_template_updates^^} == 'TRUE' ]] && return 0
  utils::ui::print::function_line_in
  sudo qubesctl state.sls update.qubes-dom0
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::update_vm(){
  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift
  utils::ui::print::info "Updating ${p_vm}"
  sudo qubesctl --skip-dom0 \
                --max-concurrency 2 \
                --targets="${p_vm}" \
                state.sls \
                update.qubes-vm
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::start_service_vms(){
  utils::ui::print::function_line_in
  for vmname in sys-usb sys-net sys-firewall sys-backup;
  do 
    sudo qvm-start --skip-if-running "${vmname}" ;
  done
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::start(){
  local    p_vm="${1}" ; shift
  #utils::ui::print::function_line_in
  sudo qvm-start --skip-if-running "${p_vm}" ;
  #utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::shutdown(){
#  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift

  utils::ui::print::info "Trying to shutdown ${p_vm}"
  sudo qvm-shutdown --wait ${p_vm}

  # Force to shutdown if the vm is still running
  if [[ -n $(qvm-ls --quiet --running --raw-list ${p_vm}) ]]
  then
    sudo qvm-shutdown --wait --force ${p_vm}
  fi
#  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::shutdown_all(){
#  utils::ui::print::function_line_in

  utils::ui::print::info "Trying to shutdown all vms"
  sudo qvm-shutdown --wait --all

#  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::shutdown_all_using_netvm(){
#  utils::ui::print::function_line_in
  local    p_netvm="${1}" ; shift

  utils::ui::print::info "Shutting down all vms using ${p_netvm}"
  for s_vmname in $(qvm-ls --fields=name,state,NETVM | \
                    grep -w 'Running' | \
                    grep -Pw "\b${p_netvm}(\s|$)" | \
                    awk '{print $1}' | \
                    grep -Pwv "\b${p_netvm}(\s|$)" );
  do
    utils::qvm::shutdown "${s_vmname}" ;
  done
#  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::shutdown_all_using_template(){
#  utils::ui::print::function_line_in
  local    p_template="${1}" ; shift

  utils::ui::print::info "Shutting down all vms using ${p_template}"
  for vmname in $(qvm-ls --fields=name,state,template | \
                    grep -w 'Running' | \
                    grep -Pw "\b${p_template}(\s|$)" | \
                    awk '{print $1}' | \
                    grep -Pwv "\b${p_template}(\s|$)");
  do
    utils::qvm::shutdown "${s_vmname}" ;
  done
#  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::change_template(){
#  utils::ui::print::function_line_in

  local    p_vm="${1}" ; shift
  local    p_template="${1}" ; shift

  utils::ui::print::info "Changing template of ${p_vm} to ${p_template}"
  utils::qvm::shutdown "${p_vm}"
  sudo qvm-prefs "${p_vm}" template ${p_template};
#  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::clone_template(){
  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift
  local    p_clone="${1}" ; shift

  if qvm-ls | awk '{print $1}' | grep -Pw "\b${p_clone}(\s|$)"
  then
    utils::ui::print::info "Template ${p_clone} is already cloned."
  else
    utils::ui::print::info "Cloning ${p_vm} to ${p_clone}."
    sudo qvm-clone ${p_vm} ${p_clone}
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::create_dispvm_template(){
  utils::ui::print::function_line_in
  local    p_new_dispvm_template="${1}" ; shift
  local    p_template="${1}" ; shift
  local    p_label="${1}" ; shift
  local    s_msg=''

  if qvm-ls | awk '{print $1}' | grep -w "^${p_new_dispvm_template}$"
  then
    s_msg="Template ${p_new_dispvm_template} is already installed."
    utils::ui::print::info "${s_msg}"
  else
    # Create a disposable vm template based on fedora-XX
    qvm-create --verbose \
               --template=${p_template} \
               --label=${p_label} \
               ${p_new_dispvm_template}
    
    qvm-prefs ${p_new_dispvm_template} template_for_dispvms True
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::qvm::create_new_vm(){
  utils::ui::print::function_line_in
  local    p_new_vm="${1}" ; shift
  local    p_template="${1}" ; shift
  local    p_label="${1}" ; shift
  local    s_msg=''
  
  if qvm-ls | awk '{print $1}' | grep -Pw "\b${p_new_vm}(\s|$)"
  then
    s_msg="${p_new_vm} already exists. Skipping."
    utils::ui::print::info "${s_msg}"
  else
    sudo qvm-create --verbose \
                    --class=AppVM \
                    --template=${p_template} \
                    --label=${p_label} \
                    "${p_new_vm}"
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::update_global_templates(){
  utils::ui::print::function_line_in
  # That the global default template and default disposable template
  # fedora-XX
  if qubes-prefs --get default_template | awk '{print $1}' | grep -w "^${_fedora_template_name}$"
  then
    utils::ui::print::info "${_fedora_template_name} is already the default global template."
  else
    sudo qubes-prefs --set default_template ${_fedora_template_name}
  fi
  # fedora-XX-dvm
  if qubes-prefs --get default_dispvm | awk '{print $1}' | grep -w "^${_fedora_dvm_template_name}$"
  then
    utils::ui::print::info "${_fedora_dvm_template_name} is already the default disposable global template."
  else
    sudo qubes-prefs --set default_dispvm ${_fedora_dvm_template_name}
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# _old_fedora_template_name='fedora-36'
# _old_fedora_dvm_template_name='fedora-36-dvm'
###############################################################################
function utils::remove_old_fedora_templates(){
  utils::ui::print::function_line_in
  utils::qvm::remove_template "${_old_fedora_dvm_template_name}"
  utils::qvm::remove_template "${_old_fedora_template_name}"
  utils::ui::print::function_line_out
}

###############################################################################
# _old_fedora_template_name='fedora-36'
# _old_fedora_dvm_template_name='fedora-36-dvm'
###############################################################################
function utils::qvm::remove_template(){
  utils::ui::print::function_line_in
  local    p_template="${1}" ; shift

  if qvm-ls | awk '{print $1}' | grep -w "^${p_template}$"
  then
    sudo qvm-remove --quiet "${p_template}"
  else
    utils::ui::print::warn "Template ${p_template} not found."
    utils::ui::print::warn "Or already removed."
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::clone_whonix_to_a_whonix_crypto(){
  utils::ui::print::function_line_in
  local    s_msg=''

  utils::qvm::update_vm "${_whonix_ws_template_name}"

  # Create a new whonix template for cryptocurrency
  sudo ${_qvmrun} ${_whonix_ws_template_name} 'sudo apt -qq -y autoremove'
  sudo ${_qvmrun} ${_whonix_ws_template_name} 'sudo apt -qq -y autoclean'

  sudo ${_qvmrun} ${_whonix_ws_template_name} 'sudo fstrim -av'

  utils::qvm::shutdown "${_whonix_ws_template_name}"

  # Check if the new whonix template is already installed
  utils::qvm::clone_template ${_whonix_ws_template_name} \
                                ${_whonix_ws_crypto_template_name}

  utils::qvm::shutdown "${_whonix_ws_crypto_template_name}"

  # Create a Whonix AppVM based on your new Crypto Whonix template which you 
  # will now use Trezor on.
  s_msg="Creating Whonix AppVM dedicated to Trezor ${_whonix_ws_trezor_wm_name}."
  utils::ui::print::info "${s_msg}"
  # Create Trezor AppVM (whonix-ws-16-crypto) from Template whonix-ws-16-crypto
  
  utils::qvm::create_new_vm "${_whonix_ws_trezor_wm_name}" \
                            "${_whonix_ws_crypto_template_name}" \
                            'purple'

  utils::ui::print::function_line_out
}

###############################################################################
#
#  _fedora_template_name='fedora-38
#
###############################################################################
function utils::fedora::download_and_update(){
  utils::ui::print::function_line_in
  local    s_msg=''
  # Check if the new fedora template is already installed
  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_template_name}$"
  then
    s_msg="Template ${_fedora_template_name} is already installed."
    utils::ui::print::info "${s_msg}"
    return 0
  else
    sudo qubes-dom0-update qubes-template-${_fedora_template_name}
    utils::fedora::update_os ${_fedora_template_name}
    utils::qvm::update_vm "${_fedora_template_name}"
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# 
#  _fedora_template_name='fedora-38'
#  _fedora_dvm_template_name='fedora-38-dvm'
#  _fedora_sys_template_name='fedora-38-sys'
#  _fedora_sys_dvm_template_name='fedora-38-sys-dvm'
###############################################################################
function utils::upgrade_to_new_fedora_template(){
  utils::ui::print::function_line_in
  # Open Terminal in dom0

  utils::fedora::download_and_update

  utils::qvm::clone_template "${_fedora_template_name}" \
                             "${_fedora_sys_template_name}"

  utils::qvm::create_dispvm_template "${_fedora_dvm_template_name}" \
                                     "${_fedora_template_name}" \
                                     'red'

  utils::qvm::clone_template "${_fedora_dvm_template_name}" \
                             "${_fedora_sys_dvm_template_name}"

  utils::qvm::shutdown "${_fedora_template_name}" ;
  utils::qvm::shutdown "${_fedora_dvm_template_name}" ;
  utils::qvm::shutdown "${_fedora_sys_template_name}" ;
  utils::qvm::shutdown "${_fedora_sys_dvm_template_name}" ;

  utils::update_global_templates

  utils::qvm::shutdown_all_using_netvm 'sys-firewall'
  utils::qvm::shutdown_all_using_netvm 'sys-net'

  # Shutdown all the vms using the old fedora dvm template
  utils::qvm::shutdown_all_using_template "${_old_fedora_dvm_template_name}"
  utils::qvm::shutdown_all_using_template "${_old_fedora_template_name}"

  utils::qvm::shutdown_all


  utils::qvm::change_template "${_fedora_sys_dvm_template_name}" \
                              "${_fedora_sys_template_name}"
  utils::qvm::change_template 'sys-usb' "${_fedora_sys_dvm_template_name}"
  utils::qvm::change_template 'sys-backup' "${_fedora_template_name}"
  utils::qvm::change_template 'sys-net' "${_fedora_template_name}"
  utils::qvm::change_template 'default-mgmt-dvm' "${_fedora_template_name}"
  utils::qvm::change_template 'sys-firewall' "${_fedora_dvm_template_name}"

  # Start all vms
  utils::qvm::start_service_vms
  
  utils::ui::print::function_line_out
}

###############################################################################
# Check if we are reaching the internet
###############################################################################
function utils::check_if_online(){
  utils::ui::print::function_line_in
  local s_error_msg=''
  local s_success_msg=''

  s_error_msg='Could not ping or access web. Retrying in 10 seconds...'
  s_success_msg='Internet connectivity verified, beginning update and install.'
  while true
  do
    if ! qvm-run -q sys-net 'ping -c 1 1.1.1.1'
    then
      if ! qvm-run -q sys-net 'curl --max-time 5 --silent --head qubes-os.org'
      then
        utils::ui::print::warn "${s_error_msg}"
        sleep 10
        continue
      fi
    fi
    utils::ui::print::info "${s_success_msg}"
    break
  done
  utils::ui::print::function_line_out
}

############################## CONFIG WHONIX WS TREZOR VM #####################

###############################################################################
  # Config Dom0 Trezor Policy
###############################################################################
function trezor::config::dom0(){
  utils::ui::print::function_line_in
  local    s_policy_file=''
  local    s_policy_line=''

  s_policy_file='/etc/qubes-rpc/policy/trezord-service'
  s_policy_line='$anyvm $anyvm allow,user=trezord,target=sys-usb'
  sudo touch ${s_policy_file}
  sudo printf '%s\n' "${s_policy_line}" | sudo tee ${s_policy_file}

  utils::ui::print::function_line_out
}

###############################################################################
# Config Port Listening in Trezor-dedicated AppVM
###############################################################################
function trezor::config::listening_port(){
  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift

  local    s_tcp_listen_line=''
  local    i_result=0
  local    s_msg=''

  s_tcp_listen_line='socat TCP-LISTEN:21325,fork EXEC:"qrexec-client-vm sys-usb trezord-service" &'

  s_msg="Adding ${s_tcp_listen_line} to ${p_vm} rc.local"
  utils::ui::print::info "${s_msg}"
  #
  ${_qvmrun} ${p_vm} "sudo cat /rw/config/rc.local | grep -q 'socat TCP-LISTEN:21325'" || i_result=$?
  if [[ ${i_result} == 1 ]]
  then
    printf '%s\n' "${s_tcp_listen_line}" | \
      ${_qvmrun} ${p_vm} 'sudo tee /rw/config/rc.local'
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# Install needed packages in Trezor-dedicated AppVM (whonix-ws-XX-trezor)
###############################################################################
function trezor::config::install_packages(){
  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift

  local    s_warn_msg=''
  local    s_cmd_line=''

  s_warn_msg="Waiting till whonix can reach the internet."
  utils::qvm::start 'sys-whonix'
  utils::qvm::start "${p_vm}"

  while true
  do
    s_cmd_line='scurl --max-time 5 --silent --head https://deb.debian.org'
    if ${_qvmrun} ${p_vm} ${s_cmd_line} > /dev/null
    then
      break
    else
      utils::ui::print::warn "${s_warn_msg}"
      sleep 10
      continue
    fi
  done
  
  s_cmd_line='nslookup security.debian.org && \
              sudo apt -qq -y update && \
              sudo apt -qq -y install curl gpg pip'
  ${_qvmrun} ${p_vm} "${s_cmd_line}"

  sleep 10

  # Install the trezor package
  s_cmd_line='pip3 install --user trezor'
  utils::ui::print::info "${_qvmrun} ${p_vm} ${s_cmd_line}"
  ${_qvmrun} ${p_vm} ${s_cmd_line}
  utils::ui::print::function_line_out
}

############################ CONFIG FEDORA-XX-SYS-DVM #########################
#_fedora_sys_dvm_template_name='fedora-38-sys-dvm'
function trezor::config::fedora_sys_dvm_template(){
  utils::ui::print::function_line_in

  local s_qubes_rpc_dir=''
  local s_trezord_srv_line=''
  local s_cmd_line=''

  s_qubes_rpc_dir='/usr/local/etc/qubes-rpc'
  s_trezord_srv_file="${s_qubes_rpc_dir}/trezord-service"
  s_trezord_srv_line='socat - TCP:localhost:21325'

  s_cmd_line="sudo mkdir -p '${s_qubes_rpc_dir}'"
  ${_qvmrun} ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  s_cmd_line="sudo touch ${s_trezord_srv_file}"
  ${_qvmrun} ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  s_cmd_line="sudo printf '%s\n' '${s_trezord_srv_line}' | \
              sudo tee '${s_trezord_srv_file}'"
  ${_qvmrun} ${_fedora_sys_dvm_template_name} "${s_cmd_line}"
  # Make the new file executable
  s_cmd_line="sudo chmod +x '${s_trezord_srv_file}'"
  ${_qvmrun} ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  utils::ui::print::function_line_out
}

############################## CONFIG FEDORA-XX-SYS ###########################
############################# INSTALL Trezor Bridge ###########################
function trezor::config::trezor_bridge(){
  utils::ui::print::function_line_in
  local s_trezor_bridge_file_name=''
  local s_trezor_bridge_file_url=''
  local s_trezor_pattern=''
  local s_cmd_line=''
  local s_msg=''

  s_cmd_line="curl -sL https://data.trezor.io/bridge/latest/ | \
              grep -o 'trezor-bridge-[0-9\.]*[0-9\-]*.x86_64.rpm'"
  s_trezor_bridge_file_name=$(${_qvmrun} --dispvm ${_fedora_dvm_template_name} "${s_cmd_line}")
  s_trezor_bridge_file_url="https://data.trezor.io/bridge/latest/${s_trezor_bridge_file_name}"

  utils::qvm::start "${_fedora_dvm_template_name}"
  utils::qvm::start "${_fedora_sys_template_name}"

  sleep 10

  # Download and Import the signing key
  s_msg="Downloading trezor-bridge with ${_fedora_dvm_template_name} and pipe to ${_fedora_sys_template_name}"
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} --dispvm ${_fedora_dvm_template_name} "curl -L ${s_trezor_bridge_file_url}" | \
      ${_qvmrun} ${_fedora_sys_template_name} "cat > /tmp/${s_trezor_bridge_file_name}"
  
  s_msg="${_qvmrun} ${_fedora_sys_template_name} chmod u+x /tmp/${s_trezor_bridge_file_name}"
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} ${_fedora_sys_template_name} "chmod u+x /tmp/${s_trezor_bridge_file_name}"

  s_msg="${_qvmrun} ${_fedora_sys_template_name} sudo rpm -i /tmp/${s_trezor_bridge_file_name}"
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} ${_fedora_sys_template_name} "sudo rpm -i /tmp/${s_trezor_bridge_file_name}"
  
  s_msg="${_qvmrun} ${_fedora_sys_template_name} sudo rpm -i /tmp/${s_trezor_bridge_file_name}"
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} ${_fedora_sys_template_name} "rm -f /tmp/${s_trezor_bridge_file_name}"

  utils::qvm::shutdown "${_fedora_dvm_template_name}"
  utils::qvm::shutdown "${_fedora_sys_template_name}"

  utils::ui::print::function_line_out
}

###############################################################################
# Function
###############################################################################
function trezor::create::udev_rule_file(){
  local s_trezor_udev_rules_file=''
  
  s_trezor_udev_rules_file='/etc/udev/rules.d/51-trezor.rules'
  cat > '/tmp/51-trezor.rules' << __EOF__
# Trezor: The Original Hardware Wallet
# https://trezor.io/
#
# Trezor
SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"

KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Trezor v2
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"

SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"

KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
__EOF__

  # Config and install udev rules in fedora-XX-sys
  cat /tmp/51-trezor.rules | \
    ${_qvmrun} ${_fedora_sys_template_name} "sudo tee ${s_trezor_udev_rules_file} > /dev/null"
  ${_qvmrun} ${_fedora_sys_template_name} "sudo chmod +x ${s_trezor_udev_rules_file}"
  utils::qvm::shutdown ${_fedora_sys_template_name}
  utils::ui::print::function_line_out
}

###############################################################################
# Function
###############################################################################
function trezor::install::trezor_common::fedora_xx_sys(){
  utils::ui::print::function_line_in
  local s_cmd_line=''
  local s_msg=''

  # 
  utils::qvm::shutdown ${_fedora_sys_template_name}

  utils::ui::print::info "Allow Network access for fedora-XX-sys"
  qvm-prefs --set ${_fedora_sys_template_name} netvm sys-firewall

  s_cmd_line='sudo dnf -y --quiet install trezor-common'

  # Install the trezor common package
  s_msg="${_qvmrun} ${_fedora_sys_template_name} ${s_cmd_line}"
  utils::ui::print::info "${s_msg}"

  ${_qvmrun} ${_fedora_sys_template_name} "${s_cmd_line}"
  utils::qvm::shutdown ${_fedora_sys_template_name}

  s_msg='Remove Network access for fedora-XX-sys'
  utils::ui::print::info "${s_msg}"
  qvm-prefs --set ${_fedora_sys_template_name} netvm none

  utils::qvm::shutdown ${_fedora_sys_template_name}
  utils::ui::print::function_line_out
}

###############################################################################
# Function
###############################################################################
function trezor::get_download_url(){
  local s_trezor_suite_app_url=''

  cat > '/tmp/gettrezorurl.sh' << '__EOF__'
#!/bin/bash
declare s_git_trezor_repo='trezor/trezor-suite'
declare s_trezor_release_url="https://api.github.com/repos/${s_git_trezor_repo}/releases/latest"
declare s_json_git_response="$(curl -s ${s_trezor_release_url})"

sudo dnf -y --quiet install jq
s_trezor_suite_app_url=$(printf '%s' ${s_json_git_response} | jq -r '.assets[] | select(.name | endswith("linux-x86_64.AppImage")) | .browser_download_url')
printf '%s' "${s_trezor_suite_app_url}"
__EOF__

  # Trezor-release-url for the Linux x86_64 AppImage
  s_trezor_suite_app_url=$(cat /tmp/gettrezorurl.sh | \
    ${_qvmrun} --dispvm ${_fedora_dvm_template_name} "cat > /tmp/gettrezorurl.sh && chmod +x /tmp/gettrezorurl.sh && /tmp/gettrezorurl.sh")

  printf '%s\n' "${s_trezor_suite_app_url}"
}

###############################################################################
# Function
###############################################################################
function trezor::get_trezor_version(){
  local s_json_git_response=''
  local s_latest_trezor_version=''
  
  s_json_git_response=$(${_qvmrun} --dispvm ${_fedora_dvm_template_name} "curl -s ${_trezor_release_url}")
  # Neueste Release-Version aus den JSON-Daten extrahieren
  s_latest_trezor_version=$(printf '%s' "${s_json_git_response}" | \
                            grep -o '"tag_name": "[^"]*' | \
                            grep -o '[^"]*$')
  printf '%s\n' "${s_latest_trezor_version}"
}

###############################################################################
# Function
###############################################################################
function trezor::config::setup_trezor_suite_on_vm(){
  utils::ui::print::function_line_in
  local    p_vm="${1}" ; shift

  local s_satoshilaps_private_key=''
  local s_satoshilaps_private_key_url=''
  local s_satoshilaps_local_path=''
  local s_app_whitelist=''
  local s_trezor_suite_app_url=''
  local s_trezor_suite_asc_url=''
  local s_trezor_suite_file_name=''
  local s_trezor_suite_asc_file_name=''
  local s_trezor_suite_file_path=''
  local s_trezor_suite_asc_file_path=''
  local s_latest_trezor_version=''
  local s_satoshilaps_key_fingerprint=''
  local s_fingerprint=''
  local s_msg=''


  s_satoshilaps_private_key='satoshilabs-2021-signing-key.asc'
  s_satoshilaps_private_key_url="https://trezor.io/security/${s_satoshilaps_private_key}"
  s_satoshilaps_local_path="/home/user/${s_satoshilaps_private_key}"
  s_satoshilaps_key_fingerprint='Keyfingerprint=EB483B26B078A4AA1B6F425EE21B6950A2ECB65C'

  s_latest_trezor_version=$(trezor::get_trezor_version)
  utils::ui::print::info "Trezor Suite Version is ${s_latest_trezor_version}"

  # Trezor-release-url for the Linux x86_64 AppImage
  s_trezor_suite_app_url=$(trezor::get_download_url)

  utils::ui::print::info "Trezor Suite download url: ${s_trezor_suite_app_url}"

  # Trezor-release-url for the Linux x86_64 AppImage asc file
  s_trezor_suite_asc_url="${s_trezor_suite_app_url}.asc"

  s_trezor_suite_file_name="Trezor-Suite-${s_latest_trezor_version}-linux-x86_64.AppImage"
  s_trezor_suite_asc_file_name="Trezor-Suite-${s_latest_trezor_version}-linux-x86_64.AppImage.asc"
  s_trezor_suite_file_path="/home/user/${s_trezor_suite_file_name}"
  s_trezor_suite_asc_file_path="/home/user/${s_trezor_suite_asc_file_name}"

  # Newest Release-Asset (Linux x86_64 AppImage) Trezor-Suite-24.1.2-linux-x86_64
  s_msg="Getting Trezor Suite version ${s_latest_trezor_version} (AppImage)..."
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} --dispvm ${_fedora_dvm_template_name} "curl -L ${s_trezor_suite_app_url}" | \
    ${_qvmrun} ${p_vm} "cat > ${s_trezor_suite_file_path}"

  # Download asc-file
  s_msg="Loading signature file for the trezor suite version ${s_latest_trezor_version}..."
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} --dispvm ${_fedora_dvm_template_name} "curl -L ${s_trezor_suite_asc_url}" | \
    ${_qvmrun} ${p_vm} "cat > ${s_trezor_suite_asc_file_path}"

  # Download and Import the signing key
  s_msg="Download and Import the signing key ${s_satoshilaps_private_key}..."
  utils::ui::print::info "${s_msg}"
  ${_qvmrun} --dispvm ${_fedora_dvm_template_name} "curl -L ${s_satoshilaps_private_key_url}" | \
    ${_qvmrun} ${p_vm} "cat > ${s_satoshilaps_local_path}"

  # Import the public key of the Satoshilabs. This is necessary to check the downloaded trezor suite
  # Key fingerprint = EB48 3B26 B078 A4AA 1B6F  425E E21B 6950 A2EC B65C
  s_fingerprint=$(${_qvmrun} ${p_vm} "gpg --keyid-format long --import --import-options show-only --with-fingerprint ${s_satoshilaps_local_path} | grep 'Key fingerprint' | sed 's/ //g'")
  
  if [[ "${s_fingerprint}" == "${s_satoshilaps_key_fingerprint}" ]]
  then
    utils::ui::print::info "Fingerprint of the Satoshi key is valid!"
    utils::ui::print::info "Importing ${s_satoshilaps_local_path}"
    ${_qvmrun} ${p_vm} "gpg --import ${s_satoshilaps_local_path}"
  else
    utils::ui::print::errorX "Unable to verify ${s_satoshilaps_local_path}!"
    utils::ui::print::errorX "STOPPING!"
    utils::pause
  fi

  # checking signature
  utils::ui::print::info "Checking signature!"
  if ${_qvmrun} ${p_vm} "gpg --verify ${s_trezor_suite_asc_file_name} ${s_trezor_suite_file_path}"
  then
    utils::ui::print::info "Signature is valid!"
  else
    utils::ui::print::errorX "Unable to verify ${s_trezor_suite_file_name}!"
    utils::ui::print::errorX "STOPPING!"
    utils::pause
  fi

  ${_qvmrun} ${p_vm} "chmod +x ${s_trezor_suite_file_path}"

  s_msg="Extract Trezor Suite AppImage: ${s_trezor_suite_file_name}"
  utils::ui::print::info "${s_msg}"

  # Not working cause it is only a lint to the trezor-suite.png file
  #${_qvmrun} ${p_vm} "${s_trezor_suite_file_path} --appimage-extract trezor-suite.png"
  #${_qvmrun} ${p_vm} "${s_trezor_suite_file_path} --appimage-extract trezor-suite.desktop"
  ${_qvmrun} ${p_vm} "${s_trezor_suite_file_path} --appimage-extract >/dev/null"

  ${_qvmrun} ${p_vm} "sed -i 's|^Exec=.*|Exec=/home/user/trezor-suite/trezor-suite.AppImage|' /home/user/squashfs-root/trezor-suite.desktop"
  
  ${_qvmrun} ${p_vm} 'mkdir -p /home/user/.local/share/applications'
  ${_qvmrun} ${p_vm} 'mkdir -p /home/user/.local/share/icons'

  ${_qvmrun} ${p_vm} 'cp -a /home/user/squashfs-root/trezor-suite.desktop /home/user/.local/share/applications/'
  ${_qvmrun} ${p_vm} 'cp -a /home/user/squashfs-root/usr/share/icons/hicolor/0x0/apps/trezor-suite.png /home/user/.local/share/icons/'

  ${_qvmrun} ${p_vm} 'sudo mkdir -vp /home/user/trezor-suite'
  ${_qvmrun} ${p_vm} "sudo mv ${s_trezor_suite_file_path} /home/user/trezor-suite/"
  ${_qvmrun} ${p_vm} "sudo ln /home/user/trezor-suite/${s_trezor_suite_file_name} /home/user/trezor-suite/trezor-suite.AppImage"

  # Add trezor-suite to Appmenu
  s_app_whitelist=$(qvm-appmenus ${p_vm} --get-whitelist)
  printf '%b\n' "${s_app_whitelist}\ntrezor-suite.desktop" | qvm-appmenus ${p_vm} --set-whitelist -
  qvm-appmenus --update --force ${p_vm}

  qvm-sync-appmenus ${p_vm}

  # Some Cleanup
  ${_qvmrun} ${p_vm} "sudo rm -f ${s_satoshilaps_local_path}"
  ${_qvmrun} ${p_vm} "sudo rm -f ${s_trezor_suite_asc_file_path}"
  ${_qvmrun} ${p_vm} 'sudo rm -fR /home/user/squashfs-root'
  
  ${_qvmrun} ${p_vm} 'sudo apt -qq -y autoremove && sudo apt -qq -y autoclean'
  ${_qvmrun} ${p_vm} 'sudo fstrim -av'

  utils::qvm::shutdown ${p_vm}
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::pause(){
  printf '%s\n' 'Press [Enter] to continue...'
  read -r
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::function_line_in() {
  local -i i_cl=0
  local    s_func_name=''
  local    s_print_options=''

  i_cl=$(($(tput cols)-23))
  s_func_name="${FUNCNAME[1]}"
  if (( ${#} != 0 ))
  then
    s_func_name="${s_func_name} -- ${@}"
  fi

  s_print_options="${_color_code_light_blue}%b${_color_reset}%-*s"
  printf "${s_print_options}" ' >>>>> Function ' "${i_cl}" "${s_func_name}"
  s_print_options="${_color_code_light_blue}%b${_color_reset}\n"
  printf "${s_print_options}" '[CALL]'
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::function_line_out() {
  local -i i_cl=0
  local    s_func_name=''
  local    s_print_options=''

  i_cl=$(($(tput cols)-21))
  s_func_name="${FUNCNAME[1]}"
  s_print_options="${_color_code_light_green}%b${_color_reset}%-*s"
  printf "${s_print_options}" ' <<<<< Function ' "${i_cl}" "${s_func_name}"
  s_print_options="${_color_code_light_green}%b${_color_reset}\n"
  printf "${s_print_options}" '[OK]'
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::info() {
  local -i i_cl=0
  local    s_print_options=''

  i_cl=$(($(tput cols)-20))
  s_print_options="${_color_code_light_yellow}%b%-*s"
  printf "${s_print_options}" ' >>>>> INFO: ' "${i_cl}" "${1}"
  s_print_options="${_color_code_light_yellow}%b${_color_reset}\n"
  printf "${s_print_options}" '[INFO]'
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::infoX() {
  local -i i_cl=0
  local    s_print_options=''

  i_cl=$(($(tput cols)-20))
  s_print_options="${_color_code_red}%b${_color_code_white}%-*s"
  printf "${s_print_options}" ' >>>>> INFO: ' "${i_cl}" "${1}"
  s_print_options="${_color_code_red}%b${_color_reset}\n"
  printf "${s_print_options}" '[INFO]'
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::warn() {
  local -i i_cl=0
  local    s_print_options=''

  i_cl=$(($(tput cols)-20))
  s_print_options="${_color_code_light_red}%b%-*s"
  printf "${s_print_options}" ' >>>>> WARN: ' "${i_cl}" "${1}" >&2
  s_print_options="${_color_code_light_red}%b${_color_reset}\n"
  printf "${s_print_options}" '[WARN]' >&2
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::error() {
  local -i i_cl=0
  local    s_func_name=''
  local    s_print_options=''

  i_cl=$(($(tput cols)-21))
  s_func_name="${FUNCNAME[1]}"
  s_print_options="${_color_code_light_red}%b${_color_code_white}%-*s"
  printf "${s_print_options}" ' >>>>> ERROR: ' "${i_cl}" "${1}" >&2
  s_print_options="${_color_code_light_red}%b${_color_reset}\n"
  printf "${s_print_options}" ' <<<<<' >&2
}

###############################################################################
# Function
#
###############################################################################
function utils::ui::print::errorX() {
  local -i i_cl=0
  local    s_func_name=''
  local    s_msg_err=''
  local    s_print_options=''

  i_cl=$(($(tput cols)-21))
  s_func_name="${FUNCNAME[1]}"

  s_msg_err="Exception in called function:"
  s_print_options="${_color_code_light_red}%b${_color_code_white}%-*s"
  printf "${s_print_options}" ' >>>>> ERROR: ' "${i_cl}" "${s_msg_err}" >&2
  s_print_options="${_color_code_light_red}%b${_color_reset}\n"
  printf "${s_print_options}" ' <<<<<' >&2

  s_msg_err="    >>> ${s_func_name} <<<"
  s_print_options="${_color_code_light_red}%b${_color_code_white}%-*s"
  printf "${s_print_options}" ' >>>>> ERROR: ' "${i_cl}" "${s_msg_err}" >&2
  s_print_options="${_color_code_light_red}%b${_color_reset}\n"
  printf "${s_print_options}" ' <<<<<' >&2

  s_msg_err="${1}"
  s_print_options="${_color_code_light_red}%b${_color_code_white}%-*s"
  printf "${s_print_options}" ' >>>>> ERROR: ' "${i_cl}" "${s_msg_err}" >&2
  s_print_options="${_color_code_light_red}%b${_color_reset}\n"
  printf "${s_print_options}" ' <<<<<' >&2
}

###############################################################################
# MAIN 
###############################################################################
function main(){
  # Version 0.0.1
  utils::ui::print::function_line_in
  local s_vm=''
  if [[ ${#} == 0 ]]
  then
    s_vm="${_whonix_ws_trezor_wm_name}"
  else
    s_vm="${1}" ; shift 
  fi

  # Running Qubes Update
  #sudo qubes-update-qui

  # Extend the privat volume of personal-internet to 4GB
  #qvm-volume extend personal-internet:private 4G

  # Default kernel used by qubes
  # Change kernel to 6.6.? in Qubes Global Settings


  utils::check_if_online
  init::variables

  utils::upgrade_to_new_fedora_template
  utils::remove_old_fedora_templates

  # Update Templates in dom0
  utils::qvm::update_dom0
  utils::qvm::update_all_templates
  
  utils::clone_whonix_to_a_whonix_crypto

  trezor::config::dom0
  trezor::config::listening_port "${s_vm}"
  trezor::config::install_packages "${s_vm}"
  trezor::config::fedora_sys_dvm_template
  trezor::config::trezor_bridge
  trezor::create::udev_rule_file
  trezor::install::trezor_common::fedora_xx_sys
  trezor::config::setup_trezor_suite_on_vm "${s_vm}"
  #utils::ui::print::info "Trezor Suite downloaded and installed!"
  utils::ui::print::infoX 'Finished please restart!'
  utils::ui::print::infoX 'Press any key to restart or STRG+c!'
  utils::pause
  sudo shutdown -r now
  utils::ui::print::function_line_out
}

  declare _old_fedora_template_name=''
  declare _old_fedora_dvm_template_name=''
  declare _fedora_template_name=''
  declare _fedora_dvm_template_name=''
  declare _fedora_sys_template_name=''
  declare _fedora_sys_dvm_template_name=''
  declare _whonix_ws_crypto_template_name=''
  declare _whonix_ws_trezor_wm_name=''

  # API-Endpunkt für die neueste Release-Version
  # GitHub repository
  declare _git_trezor_repo=''
  declare _trezor_release_url=''

  declare _qvmrun=''

  declare -r _color_reset='\e[0m'
  declare -r _color_code_black='\e[30m'
  declare -r _color_code_red='\e[31m'
  declare -r _color_code_green='\e[32m'
  declare -r _color_code_yellow='\e[33m'
  declare -r _color_code_blue='\e[34m'
  declare -r _color_code_grey='\e[37m'
  declare -r _color_code_light_red='\e[91m'
  declare -r _color_code_light_green='\e[92m'
  declare -r _color_code_light_yellow='\e[93m'
  declare -r _color_code_light_blue='\e[94m'
  declare -r _color_code_white='\e[97m'

main "${@}"

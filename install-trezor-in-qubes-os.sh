#!/bin/bash

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

  _whonix_ws_crypto_template_name='whonix-ws-16-crypto'
  _whonix_ws_trezor_wm_name='whonix-ws-16-trezor'

  # API-Endpunkt für die neueste Release-Version
  # GitHub repository
  _git_trezor_repo='trezor/trezor-suite'
  _trezor_release_url="https://api.github.com/repos/${_git_trezor_repo}/releases/latest"
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function fedora::update_the_system(){
  utils::ui::print::function_line_in
  local    p_system="${1}" ; shift
  # Not sure if necessary 
  qvm-run --pass-io ${p_system} 'sudo dnf -y install gnome-packagekit-updater'
  qvm-run --pass-io ${p_system} 'sudo dnf -y clean all'
  qvm-run --pass-io ${p_system} 'sudo dnf -y update'
  qvm-run --pass-io ${p_system} 'sudo dnf -y upgrade'
  qvm-run --pass-io ${p_system} 'sudo dnf -y clean all'
  qvm-run --pass-io ${p_system} 'sudo fstrim -av'
  qvm-shutdown --wait ${p_system}
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::update_global_templates(){
  utils::ui::print::function_line_in
  # That the global default template and default disposable template
  # fedora-XX
  sudo qubes-prefs --set default_template ${_fedora_template_name}
  # fedora-XX-dvm
  sudo qubes-prefs --set default_dispvm ${_fedora_dvm_template_name}
  utils::ui::print::function_line_out
}

###############################################################################
# _old_fedora_template_name='fedora-36'
# _old_fedora_dvm_template_name='fedora-36-dvm'
###############################################################################
function utils::remove_old_fedora_templates(){
  utils::ui::print::function_line_in
  sudo qvm-remove --quiet "${_old_fedora_dvm_template_name}"
  sudo qvm-remove --quiet "${_old_fedora_template_name}"
  utils::ui::print::function_line_out
}

###############################################################################
# 
###############################################################################
function utils::clone_whonix_to_a_whonix_crypto(){
  utils::ui::print::function_line_in
  # Create a new whonix template for cryptocurrency
  sudo qvm-run --pass-io whonix-ws-16 'sudo apt -y autoremove'
  sudo qvm-run --pass-io whonix-ws-16 'sudo apt -y autoclean'
  sudo qvm-run --pass-io whonix-ws-16 'sudo fstrim -av'

  sudo qvm-shutdown --wait whonix-ws-16

  sudo qvm-clone whonix-ws-16 ${_whonix_ws_crypto_template_name}
  sudo qvm-prefs sys-net template ${_whonix_ws_crypto_template_name}

  sudo qvm-run --pass-io ${_whonix_ws_crypto_template_name} 'sudo apt-get install -y jq'
  sudo qvm-run --pass-io ${_whonix_ws_crypto_template_name} 'sudo apt-get install -y jq'
  
  sudo qvm-shutdown --wait ${_whonix_ws_crypto_template_name}

  # Create a Whonix AppVM based on your new Crypto Whonix template which you will now use Trezor on.
  utils::ui::print::info "Creating Whonix AppVM dedicated to Trezor ${_whonix_ws_trezor_wm_name}."

  # Create Trezor AppVM (whonix-ws-16-crypto) from Template whonix-ws-16-crypto
  sudo qvm-create --verbose \
                  --class=AppVM \
                  --template=${_whonix_ws_crypto_template_name} \
                  --label=purple \
                  "${_whonix_ws_trezor_wm_name}"

  utils::ui::print::function_line_out
}

###############################################################################
# 
#  _fedora_template_name='fedora-38'
#  _fedora_dvm_template_name='fedora-38-dvm'
#  _fedora_sys_template_name='fedora-38-sys'
#  _fedora_sys_dvm_template_name='fedora-38-sys-dvm'
###############################################################################
function utils::update_to_new_fedora_template(){
  utils::ui::print::function_line_in
  # Open Terminal in dom0

  # Check if the new fedora template is already installed
  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_template_name}$"
  then
    utils::ui::print::info "Template ${_fedora_template_name} is already installed."
  else
    sudo qubes-dom0-update qubes-template-${_fedora_template_name}
    fedora::update_the_system
  fi

  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_sys_template_name}$"
  then
    utils::ui::print::info "Template ${_fedora_sys_template_name} is already installed."
  else
    # Clone current regular fedora-XX template Qube and name it fedora-XX-sys.
    qvm-clone ${_fedora_template_name} ${_fedora_sys_template_name}
  fi

  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_dvm_template_name}$"
  then
    utils::ui::print::info "Template ${_fedora_dvm_template_name} is already installed."
  else
    # Create a disposable vm template based on fedora-XX
    qvm-create --verbose --template ${_fedora_template_name} --label red ${_fedora_dvm_template_name}
    qvm-prefs ${_fedora_dvm_template_name} template_for_dispvms True
  fi

  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_sys_dvm_template_name}$"
  then
      utils::ui::print::info "Template ${_fedora_sys_dvm_template_name} is already installed."
  else
    # Clone fedora-XX-dvm qube and name it fedora-XX-sys-dvm.
    qvm-clone ${_fedora_dvm_template_name} ${_fedora_sys_dvm_template_name}
  fi

  sudo qvm-shutdown --wait "${_fedora_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_dvm_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_sys_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_sys_dvm_template_name}" ;

  utils::update_global_templates

  #TODO 
  utils::ui::print::info "Try to shutdown all vms!"

  utils::ui::print::info "Shutting down all vms using sys-usb"
  for vmname in $(qvm-ls --fields=name,state,NETVM | \
                    grep -w 'Running' | \
                    grep -w 'sys-usb' | \
                    awk '{print $1}' | \
                    grep -vw 'sys-usb' );
  do
    utils::ui::print::info "qvm-shutdown --wait ${vmname}"
    sudo qvm-shutdown --wait "${vmname}" ;
  done

  utils::ui::print::info "Shutting down all vms using sys-firewall"
  for vmname in $(qvm-ls --fields=name,state,NETVM | \
                    grep -w 'Running' | \
                    grep -w 'sys-firewall' | \
                    awk '{print $1}' | \
                    grep -vw 'sys-firewall' );
  do
    utils::ui::print::info "qvm-shutdown --wait ${vmname}"
    sudo qvm-shutdown --wait "${vmname}" ;
  done

  utils::ui::print::info "Shutting down all vms using sys-net"
  for vmname in $(qvm-ls --fields=name,state,NETVM | \
                    grep -w 'Running' | \
                    grep -w 'sys-net' | \
                    awk '{print $1}' | \
                    grep -vw 'sys-net' );
  do
    utils::ui::print::info "qvm-shutdown --wait ${vmname}"
    sudo qvm-shutdown --wait "${vmname}" ;
  done

  # Shutdown all the vms using the old fedora dvm template
  utils::ui::print::info "Shutting down all vms using ${_old_fedora_dvm_template_name}"
  for vmname in $(qvm-ls --fields=name,state,template | \
                    grep -w 'Running' | \
                    grep -Pw "\b${_old_fedora_dvm_template_name}(\s|$)" | \
                    awk '{print $1}' | \
                    grep -Pwv "\b${_old_fedora_dvm_template_name}(\s|$)");
  do
    utils::ui::print::info "qvm-shutdown --wait ${vmname}"
    sudo qvm-shutdown --wait "${vmname}";
  done

  # Shutdown all the vms using the old fedora template
  utils::ui::print::info "Shutting down all vms using ${_old_fedora_template_name}"
  for vmname in $(qvm-ls --fields=name,state,template | \
                    grep -w 'Running' | \
                    grep -w "\b${_old_fedora_template_name}(\s|$)" | \
                    awk '{print $1}' | \
                    grep -Pwv "\b${_old_fedora_template_name}(\s|$)");
  do
    utils::ui::print::info "qvm-shutdown --wait ${vmname}"
    sudo qvm-shutdown --wait "${vmname}";
  done

  utils::ui::print::info "Shutting all vms!"
  sudo qvm-shutdown --wait --all
  utils::ui::print::info "Shutting down all vms done!"

  utils::ui::print::info "Changing template of sys-usb to ${_fedora_sys_dvm_template_name}"
  sudo qvm-shutdown --wait sys-usb; sudo qvm-prefs sys-usb template ${_fedora_sys_dvm_template_name};

  utils::ui::print::info "Changing template of sys-backup to ${_fedora_template_name}"
  sudo qvm-prefs sys-backup template ${_fedora_template_name};

  utils::ui::print::info "Changing template of sys-net to ${_fedora_template_name}"
  sudo qvm-prefs sys-net template ${_fedora_template_name};

  utils::ui::print::info "Changing template of default-mgmt-dvm to ${_fedora_template_name}"
  sudo qvm-prefs default-mgmt-dvm template ${_fedora_template_name};

  utils::ui::print::info "Changing template of sys-firewall to ${_fedora_dvm_template_name}"
  sudo qvm-prefs sys-firewall template ${_fedora_dvm_template_name};

  # Start all vms
  for vmname in sys-usb sys-net sys-firewall sys-backup;
  do 
    sudo qvm-start --skip-if-running "${vmname}" ;
  done

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
  local s_policy_file='/etc/qubes-rpc/policy/trezord-service'
  local s_policy_line='$anyvm $anyvm allow,user=trezord,target=sys-usb'

  sudo touch ${s_policy_file}
  sudo printf '%s\n' "${s_policy_line}" | sudo tee ${s_policy_file}
  utils::ui::print::function_line_out
}

###############################################################################
# Config Port Listening in Trezor-dedicated AppVM (whonix-ws-XX-trezor)
###############################################################################
function trezor::config::listening_port(){
  utils::ui::print::function_line_in
  local s_tcp_listen_line=''
  local i_result=0
  s_tcp_listen_line='socat TCP-LISTEN:21325,fork EXEC:"qrexec-client-vm sys-usb trezord-service" &'

  utils::ui::print::info "Adding ${s_tcp_listen_line} to ${_whonix_ws_trezor_wm_name} rc.local"
  #
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo cat /rw/config/rc.local | grep -q 'socat TCP-LISTEN:21325'" || i_result=$?
  if [[ ${i_result} == 1 ]]
  then
    printf '%s\n' "${s_tcp_listen_line}" | \
      qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo tee /rw/config/rc.local'
  fi
  utils::ui::print::function_line_out
}

###############################################################################
# Install needed packages in Trezor-dedicated AppVM (whonix-ws-XX-trezor)
###############################################################################
function trezor::config::install_packages(){
  utils::ui::print::function_line_in
  local s_warn_msg=''

  s_warn_msg="Waiting till whonix can reach the internet."
  qvm-run --wait sys-whonix

  while true
  do
    if qvm-run -q ${_whonix_ws_trezor_wm_name} 'curl --max-time 5 --silent --head deb.debian.org'
    then
      break
    else
      utils::ui::print::warn "${s_warn_msg}"
      sleep 10
      continue
    fi
  done

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt update'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt -y install curl'

  # Install needed packages on the whonix trezor Appws
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt -y install gpg'

  # Install pip
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt -y install pip'
  # Install the trezor package
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'pip3 install --user trezor'
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
  qvm-run --pass-io ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  s_cmd_line="sudo touch ${s_trezord_srv_file}"
  qvm-run --pass-io ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  s_cmd_line="sudo printf '%s\n' '${s_trezord_srv_line}' | \
              sudo tee '${s_trezord_srv_file}'"
  qvm-run --pass-io ${_fedora_sys_dvm_template_name} "${s_cmd_line}"
  # Make the new file executable
  s_cmd_line="sudo chmod +x '${s_trezord_srv_file}'"
  qvm-run --pass-io ${_fedora_sys_dvm_template_name} "${s_cmd_line}"

  utils::ui::print::function_line_out
}

############################## CONFIG FEDORA-XX-SYS ###########################
############################# INSTALL Trezor Bridge ###########################
function trezor::config::trezor-bridge(){
  utils::ui::print::function_line_in
  local s_trezor_bridge_file_name=''
  local s_trezor_bridge_file_url=''
  local s_trezor_pattern=''
  local s_cmd_line=''

  s_cmd_line="curl -sL https://data.trezor.io/bridge/latest/ | grep -o 'trezor-bridge-[0-9\.]*[0-9\-]*.x86_64.rpm'"
  s_trezor_bridge_file_name=$(qvm-run --pass-io ${_fedora_dvm_template_name} "${s_cmd_line}")
  s_trezor_bridge_file_url="https://data.trezor.io/bridge/latest/${s_trezor_bridge_file_name}"

  # Download and Import the signing key
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${s_trezor_bridge_file_url}" | \
      qvm-run --pass-io ${_fedora_sys_template_name} "cat > /tmp/${s_trezor_bridge_file_name}"
  qvm-run --pass-io ${_fedora_sys_template_name} "chmod u+x /tmp/${s_trezor_bridge_file_name}"
  qvm-run --pass-io ${_fedora_sys_template_name} "sudo rpm -i /tmp/${s_trezor_bridge_file_name}"
  qvm-run --pass-io ${_fedora_sys_template_name} "rm -f /tmp/${s_trezor_bridge_file_name}"
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
    qvm-run --pass-io ${_fedora_sys_template_name} "sudo cat > ${s_trezor_udev_rules_file}"
  qvm-run --pass-io ${_fedora_sys_template_name} "sudo chmod +x ${s_trezor_udev_rules_file}"
  qvm-shutdown --wait ${_fedora_sys_template_name}
  utils::ui::print::function_line_out
}

###############################################################################
# Function
###############################################################################
function trezor::install::trezor-common::fedora_xx_sys(){
  utils::ui::print::function_line_in
  # Allow Network access for fedora-XX-sys
  qvm-shutdown --wait ${_fedora_sys_template_name}
  qvm-prefs --set ${_fedora_sys_template_name} netvm sys-firewall
  # Install the trezor common package
  qvm-run --pass-io ${_fedora_sys_template_name} "sudo dnf -y trezor-common"
  qvm-shutdown --wait ${_fedora_sys_template_name}
  # Remove Network access for fedora-XX-sys
  qvm-prefs --set ${_fedora_sys_template_name} netvm none
  utils::ui::print::function_line_out
}

###############################################################################
# Function
###############################################################################
function trezor::config::whonix-ws-trezor(){
  utils::ui::print::function_line_in
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

  s_satoshilaps_private_key='satoshilabs-2021-signing-key.asc'
  s_satoshilaps_private_key_url="https://trezor.io/security/${s_satoshilaps_private_key}"
  s_satoshilaps_local_path="/home/user/${s_satoshilaps_private_key}"


  # Get the JSON data of the newest release
  _json_git_response=$(qvm-run --pass-io ${_fedora_dvm_template_name} "curl -s ${_trezor_release_url}")

  # Neueste Release-Version aus den JSON-Daten extrahieren
  _latest_trezor_version=$(printf '%s' "${_json_git_response}" | \
                            grep -o '"tag_name": "[^"]*' | \
                            grep -o '[^"]*$')

  # Trezor-release-url for the Linux x86_64 AppImage
  s_trezor_suite_app_url=$(qvm-run --pass-io ${_fedora_dvm_template_name} "printf '%s' ${_json_git_response} | jq -r '.assets[] | select(.name | endswith('linux-x86_64.AppImage')) | .browser_download_url'")

  # Trezor-release-url for the Linux x86_64 AppImage asc file
  s_trezor_suite_asc_url=$(qvm-run --pass-io ${_fedora_dvm_template_name} "printf '%s' ${_json_git_response} | jq -r '.assets[] | select(.name | endswith('linux-x86_64.AppImage.asc)) | .browser_download_url'")

  s_trezor_suite_file_name="Trezor-Suite-${_latest_trezor_version}-linux-x86_64.AppImage"
  s_trezor_suite_asc_file_name="Trezor-Suite-${_latest_trezor_version}-linux-x86_64.AppImage.asc"
  s_trezor_suite_file_path="/home/user/${s_trezor_suite_file_name}"
  s_trezor_suite_asc_file_path="/home/user/${s_trezor_suite_asc_file_name}"

  # Newest Release-Asset (Linux x86_64 AppImage) Trezor-Suite-24.1.2-linux-x86_64
  utils::ui::print::info "Getting Trezor Suite version ${_latest_trezor_version} (AppImage)..."
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${s_trezor_suite_app_url}" | \
    qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${s_trezor_suite_file_path}"

  # Download asc-file
  utils::ui::print::info "Loading signature file for the trezor suite version ${_latest_trezor_version}..."
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${s_trezor_suite_asc_url}" | \
    qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${s_trezor_suite_asc_file_path}"

  # Download and Import the signing key
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${s_satoshilaps_private_key_url}" | \
      qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${s_satoshilaps_local_path}"

  # Import the public key of the Satoshilabs. This is necessary to check the downloaded trezor suite
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "gpg --import ${s_satoshilaps_local_path}"

  # checking signature
  utils::ui::print::info "Checking signature!"
  if ! qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "gpg --verify ${s_trezor_suite_asc_file_name} ${s_trezor_suite_file_path}"
  then
    utils::ui::print::errorX "Unable to verify ${s_trezor_suite_file_name}!"
    utils::ui::print::errorX "STOPPING!"
    return 1
  fi

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "chmod +x ${s_trezor_suite_file_path}"

  utils::ui::print::info "Extract Trezor Suite AppImage: ${s_trezor_suite_file_name}"
  
  # Not working cause it is only a lint to the trezor-suite.png file
  #qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${s_trezor_suite_file_path} --appimage-extract trezor-suite.png"
  #qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${s_trezor_suite_file_path} --appimage-extract trezor-suite.desktop"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${s_trezor_suite_file_path} --appimage-extract >/dev/null"

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sed -i 's|^Exec=.*|Exec=/opt/trezor-suite/trezor-suite.AppImage|' /home/user/squashfs-root/trezor-suite.desktop"
  
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'mkdir -p /home/user/.local/share/applications'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'mkdir -p /home/user/.local/share/icons'

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'cp -a /home/user/squashfs-root/trezor-suite.desktop /home/user/.local/share/applications/'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'cp -a /home/user/squashfs-root/usr/share/icons/hicolor/0x0/apps/trezor-suite.png /home/user/.local/share/icons/'

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sed -i 's|^Exec=.*|Exec=/opt/trezor-suite/trezor-suite.AppImage|' /home/user/"

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo mkdir -p /opt/trezor-suite'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo mv ${s_trezor_suite_file_path} /opt/trezor-suite"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "ln /opt/trezor-suite/${s_trezor_suite_file_name} /opt/trezor-suite/trezor-suite.AppImage"

  # Add trezor-suite to Appmenu
  s_app_whitelist=$(qvm-appmenus ${_whonix_ws_trezor_wm_name} --get-whitelist)
  utils::ui::print::info "${s_app_whitelist}\ntrezor-suite.desktop"
  printf '%b\n' "${s_app_whitelist}" | qvm-appmenus ${_whonix_ws_trezor_wm_name} --set-whitelist -
  qvm-appmenus --update --force ${_whonix_ws_trezor_wm_name}

  qvm-sync-appmenus ${_whonix_ws_trezor_wm_name}

  # Some Cleanup
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo rm -f ${s_satoshilaps_local_path}"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo rm -f ${s_trezor_suite_asc_file_path}"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo rm -fR /home/user/squashfs-root'
  
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt -y autoremove && apt -y autoclean'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo fstrim -av'

  qvm-shutdown --wait ${_whonix_ws_trezor_wm_name}
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
  # Running Qubes Update
  #sudo qubes-update-qui

  # Extend the privat volume of personal-internet to 4GB
  #qvm-volume extend personal-internet:private 4G

  # Default kernel used by qubes
  # Change kernel to 6.6.? in Qubes Global Settings


  utils::check_if_online
  init::variables

  utils::pause
  # Update Templates in dom0
  #sudo qubesctl --skip-dom0 --templates state.sls update.qubes-vm

  utils::update_to_new_fedora_template
utils::pause
  utils::remove_old_fedora_templates
utils::pause
  utils::clone_whonix_to_a_whonix_crypto
utils::pause
  trezor::config::dom0
utils::pause
  trezor::config::listening_port
utils::pause
  trezor::config::install_packages
utils::pause
  trezor::config::fedora_sys_dvm_template
utils::pause
  trezor::config::trezor-bridge
utils::pause
  trezor::create::udev_rule_file
utils::pause
  trezor::install::trezor-common::fedora_xx_sys
utils::pause
  trezor::config::whonix-ws-trezor
utils::pause
  utils::ui::print::function_line_in
  utils::ui::print::info "Trezor Suite downloaded and installed!"
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

main

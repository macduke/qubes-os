#!/bin/bash



###############################################################################
# INIT
###############################################################################
function init::variables(){

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

  # Get the JSON data of the newest release
  _json_git_response=$(qvm-run --pass-io ${_fedora_dvm_template_name} "curl -s ${_trezor_release_url}")

  # Neueste Release-Version aus den JSON-Daten extrahieren
  _latest_trezor_version=$(printf '%s' "${_json_git_response}" | \
                            grep -o '"tag_name": "[^"]*' | \
                            grep -o '[^"]*$')

  # Trezor-release-url for the Linux x86_64 AppImage
  _trezor_suite_app_url=$(qvm-run --pass-io ${_fedora_dvm_template_name} "printf '%s' ${_json_git_response} | jq -r '.assets[] | select(.name | endswith('linux-x86_64.AppImage')) | .browser_download_url'")

  # Trezor-release-url for the Linux x86_64 AppImage asc file
  _trezor_suite_asc_url=$(qvm-run --pass-io ${_fedora_dvm_template_name} "printf '%s' ${_json_git_response} | jq -r '.assets[] | select(.name | endswith('linux-x86_64.AppImage.asc)) | .browser_download_url'")

  _trezor_suite_file_name="Trezor-Suite-${_latest_trezor_version}-linux-x86_64.AppImage"
  _trezor_suite_asc_file_name="Trezor-Suite-${_latest_trezor_version}-linux-x86_64.AppImage.asc"
  _trezor_suite_file_path="/home/user/${_trezor_suite_file_name}"
  _trezor_suite_asc_file_path="/home/user/${_trezor_suite_asc_file_name}"

  printf '%s\n' "Trezor Suite file name: ${_trezor_suite_file_name}"
  sleep 5
}

###############################################################################
# 
###############################################################################
function utils::pause(){
  echo "Press [Enter] to continue..."
  read -r
}
###############################################################################
# 
###############################################################################
function utils::update_the_new_fedora_template(){
    # Not sure if necessary 
  qvm-run --pass-io ${_fedora_template_name} 'sudo dnf install -y gnome-packagekit-updater'
  qvm-run --pass-io ${_fedora_template_name} 'sudo dnf clean all'
  qvm-run --pass-io ${_fedora_template_name} 'sudo dnf update -y'
  qvm-run --pass-io ${_fedora_template_name} 'sudo dnf upgrade -y'
  qvm-run --pass-io ${_fedora_template_name} 'sudo dnf clean all'
  qvm-run --pass-io ${_fedora_template_name} 'sudo fstrim -av'
  qvm-shutdown ${_fedora_template_name}
}

###############################################################################
# 
###############################################################################
function utils::update_global_templates(){
  # That the global default template and default disposable template
  # fedora-XX
  sudo qubes-prefs --set default_template ${_fedora_template_name}
  # fedora-XX-dvm
  sudo qubes-prefs --set default_dispvm ${_fedora_dvm_template_name}
}

###############################################################################
# _old_fedora_template_name='fedora-36'
# _old_fedora_dvm_template_name='fedora-36-dvm'
###############################################################################
function utils::remove_old_fedora_templates(){
  sudo qvm-remove --quiet "${_old_fedora_template_name}"
  sudo qvm-remove --quiet "${_old_fedora_dvm_template_name}"
}

###############################################################################
# 
###############################################################################
function utils::clone_whonix_to_a_whonix_crypto(){
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
  printf '%s\n' "Creating Whonix AppVM dedicated to Trezor ${_whonix_ws_trezor_wm_name}."

  # Create Trezor AppVM (whonix-ws-16-crypto) from Template whonix-ws-16-crypto
  sudo qvm-create --verbose \
                  --class=AppVM \
                  --template=${_whonix_ws_crypto_template_name} \
                  --label=purple \
                  "${_whonix_ws_trezor_wm_name}"
}

###############################################################################
# 
#  _fedora_template_name='fedora-38'
#  _fedora_dvm_template_name='fedora-38-dvm'
#  _fedora_sys_template_name='fedora-38-sys'
#  _fedora_sys_dvm_template_name='fedora-38-sys-dvm'
###############################################################################
function utils::update_to_new_fedora_template(){
  # Open Terminal in dom0

  # Check if the new fedora template is already installed
  if qvm-ls | awk '{print $1}' | grep -w "^${_fedora_template_name}$"
  then
    printf '%s\n' "Template ${_fedora_template_name} is already installed."
  else
    sudo qubes-dom0-update qubes-template-${_fedora_template_name}
    utils::update_the_new_fedora_template
  fi

  if ! qvm-ls | awk '{print $1}' | grep -w "^${_fedora_sys_template_name}$"
  then
    # Clone current regular fedora-XX template Qube and name it fedora-XX-sys.
    qvm-clone ${_fedora_template_name} ${_fedora_sys_template_name}
  fi

  if ! qvm-ls | awk '{print $1}' | grep -w "^${_fedora_dvm_template_name}$"
  then
    # Create a disposable vm template based on fedora-XX
    qvm-create --verbose --template ${_fedora_template_name} --label red ${_fedora_dvm_template_name}
    qvm-prefs ${_fedora_dvm_template_name} template_for_dispvms True
  fi

  if ! qvm-ls | awk '{print $1}' | grep -w "^${_fedora_sys_dvm_template_name}$"
  then
    # Clone fedora-XX-dvm qube and name it fedora-XX-sys-dvm.
    qvm-clone ${_fedora_dvm_template_name} ${_fedora_sys_dvm_template_name}
  fi

  sudo qvm-shutdown --wait "${_fedora_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_dvm_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_sys_template_name}" ;
  sudo qvm-shutdown --wait "${_fedora_sys_dvm_template_name}" ;

  utils::update_global_templates

  #TODO
  sudo qvm-shutdown --wait sys-usb; sudo qvm-prefs sys-usb template ${_fedora_sys_dvm_template_name};

  # Change fedora-38-dvm template for sy
  for vmname in $(qvm-ls --fields=name,state,template | \
                    grep -w 'Running' | \
                    grep -w "^${_old_fedora_template_name}$" | \
                    awk '{print $1}' | \
                    grep -vw "^${_old_fedora_template_name}$" ) ;
  do 
    sudo qvm-shutdown --wait "${vmname}";
  done

  for vmname in $(qvm-ls --fields=name,state,template | \
                    grep -w 'Running' | \
                    grep -w "^${_old_fedora_dvm_template_name}$" | \
                    awk '{print $1}' | \
                    grep -vw "^${_old_fedora_dvm_template_name}$" ) ;
  do 
    sudo qvm-shutdown --wait "${vmname}";
  done

  for vmname in $(qvm-ls --fields=name,state,NETVM | \
                    grep -w 'Running' | \
                    grep -w "${_fedora_template_name}" | \
                    awk '{print $1}' | \
                    grep -vw "${_fedora_template_name}" ) ;
  do 
    sudo qvm-shutdown --wait "${vmname}" ;
  done

  #sudo qvm-shutdown --all --wait;

  sudo qvm-prefs sys-backup template ${_fedora_template_name};
  sudo qvm-prefs sys-net template ${_fedora_template_name};
  sudo qvm-prefs default-mgmt-dvm template ${_fedora_template_name};
  sudo qvm-prefs sys-firewall template ${_fedora_dvm_template_name};
  sudo qvm-prefs sys-usb template ${_fedora_sys_dvm_template_name}; 

  # Start all vms
  for vmname in sys-usb sys-net sys-firewall sys-backup;
  do 
    sudo qvm-start --skip-if-running "${vmname}" ;
  done

  utils::remove_old_fedora_templates

  utils::clone_whonix_to_a_whonix_crypto

}

###############################################################################
# Check if we are reaching the internet
###############################################################################
function utils::check_if_online(){
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
        printf '%s\n' "${s_error_msg}"
        sleep 10
        continue
      fi
    fi
    printf '%s\n' "${s_success_msg}"
    break
  done
}

############################## CONFIG WHONIX WS TREZOR VM #####################

###############################################################################
  # Config Dom0 Trezor Policy
###############################################################################
function trezor::config::dom0(){
  local s_policy_file='/etc/qubes-rpc/policy/trezord-service'
  local s_policy_line='$anyvm $anyvm allow,user=trezord,target=sys-usb'

  sudo touch ${s_policy_file}
  sudo printf '%s\n' "${s_policy_line}" | sudo tee ${s_policy_file}
}

###############################################################################
# Config Port Listening in Trezor-dedicated AppVM (whonix-ws-XX-trezor)
###############################################################################
function trezor::config::listening_port(){
  local s_tcp_listen_line=''
  local i_result=0
  s_tcp_listen_line='socat TCP-LISTEN:21325,fork EXEC:"qrexec-client-vm sys-usb trezord-service" &'

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo cat /rw/config/rc.local | grep -q 'socat TCP-LISTEN:21325'" || i_result=$?
  if [[ ${i_result} == 1 ]]
  then
    printf '%s\n' "${s_tcp_listen_line}" | \
      qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo tee /rw/config/rc.local'
  fi
}

###############################################################################
# Install needed packages in Trezor-dedicated AppVM (whonix-ws-XX-trezor)
###############################################################################
function trezor::config::install_packages(){
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt update && sudo apt -y install curl'

  # Install needed packages on the whonix trezor Appws
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt update && sudo apt -y install gpg'

  # Install pip
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt update && sudo apt -y install pip'
  # Install the trezor package
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'pip3 install --user trezor'
}

############################ CONFIG FEDORA-XX-SYS-DVM #########################
#_fedora_sys_dvm_template_name='fedora-38-sys-dvm'
function trezor::config::fedora_sys_dvm_template(){
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
}

############################## CONFIG FEDORA-XX-SYS ###########################
############################# INSTALL Trezor Bridge ###########################
function trezor::config::trezor-bridge(){
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
}

###############################################################################
# Function
###############################################################################
function trezor::create::udev-rule-file(){
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
}

###############################################################################
# Function
###############################################################################
function trezor::install::trezor-common::fedora-xx-sys(){
  # Allow Network access for fedora-XX-sys
  qvm-shutdown --wait ${_fedora_sys_template_name}
  qvm-prefs --set ${_fedora_sys_template_name} netvm sys-firewall
  # Install the trezor common package
  qvm-run --pass-io ${_fedora_sys_template_name} "sudo dnf -y trezor-common"
  qvm-shutdown --wait ${_fedora_sys_template_name}
  # Remove Network access for fedora-XX-sys
  qvm-prefs --set ${_fedora_sys_template_name} netvm none
}

###############################################################################
# Function
###############################################################################
function trezor::config::whonix-ws-trezor(){
  local s_satoshilaps_private_key=''
  local s_satoshilaps_private_key_url=''
  local s_satoshilaps_local_path=''
  local s_app_whitelist=''
  
  s_satoshilaps_private_key='satoshilabs-2021-signing-key.asc'
  s_satoshilaps_private_key_url="https://trezor.io/security/${s_satoshilaps_private_key}"
  s_satoshilaps_local_path="/home/user/${s_satoshilaps_private_key}"

  # Newest Release-Asset (Linux x86_64 AppImage) Trezor-Suite-24.1.2-linux-x86_64
  printf '%s\n' "Getting Trezor Suite version ${_latest_trezor_version} (AppImage)..."
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${_trezor_suite_app_url}" | \
    qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${_trezor_suite_file_path}"

  # Download asc-file
  printf '%s\n' "Loading signatur file for the trezor suite version ${_latest_trezor_version}..."
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${_trezor_suite_asc_url}" | \
    qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${_trezor_suite_asc_file_path}"

  # Download and Import the signing key
  qvm-run --pass-io ${_fedora_dvm_template_name} "curl -L ${s_satoshilaps_private_key_url}" | \
      qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "cat > ${s_satoshilaps_local_path}"

  # Import the public key of the Satoshilabs. This is necessary to check the downloaded trezor suite
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "gpg --import ${s_satoshilaps_local_path}"

  # checking signature
  printf '%s\n'  "Checking signature!"
  if ! qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "gpg --verify ${_trezor_suite_asc_file_name} ${_trezor_suite_file_path}"
  then
    printf '%s\n' "ERROR: Unable to verify ${_trezor_suite_file_name}!"
    printf '%s\n' "ERROR: Unable to verify ${_trezor_suite_file_name}!"
    printf '%s\n' "ERROR: Unable to verify ${_trezor_suite_file_name}!"
    printf '%s\n' "STOPPING!"
    return 1
  fi

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "chmod +x ${_trezor_suite_file_path}"

  printf '%s\n' "Extract Trezor Suite AppImage: ${_trezor_suite_file_name}"
  
  # Not working cause it is only a lint to the trezor-suite.png file
  #qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${_trezor_suite_file_path} --appimage-extract trezor-suite.png"
  #qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${_trezor_suite_file_path} --appimage-extract trezor-suite.desktop"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "${_trezor_suite_file_path} --appimage-extract >/dev/null"

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sed -i 's|^Exec=.*|Exec=/opt/trezor-suite/trezor-suite.AppImage|' /home/user/squashfs-root/trezor-suite.desktop"
  
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'mkdir -p /home/user/.local/share/applications'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'mkdir -p /home/user/.local/share/icons'

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'cp -a /home/user/squashfs-root/trezor-suite.desktop /home/user/.local/share/applications/'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'cp -a /home/user/squashfs-root/usr/share/icons/hicolor/0x0/apps/trezor-suite.png /home/user/.local/share/icons/'

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sed -i 's|^Exec=.*|Exec=/opt/trezor-suite/trezor-suite.AppImage|' /home/user/"

  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo mkdir -p /opt/trezor-suite'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo mv ${_trezor_suite_file_path} /opt/trezor-suite"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "ln /opt/trezor-suite/${_trezor_suite_file_name} /opt/trezor-suite/trezor-suite.AppImage"

  # Add trezor-suite to Appmenu
  s_app_whitelist=$(qvm-appmenus ${_whonix_ws_trezor_wm_name} --get-whitelist)
  printf '%b\n' "${s_app_whitelist}\ntrezor-suite.desktop"
  printf '%b\n' "${s_app_whitelist}" | qvm-appmenus ${_whonix_ws_trezor_wm_name} --set-whitelist -
  qvm-appmenus --update --force ${_whonix_ws_trezor_wm_name}

  qvm-sync-appmenus ${_whonix_ws_trezor_wm_name}

  # Some Cleanup
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo rm -f ${s_satoshilaps_local_path}"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} "sudo rm -f ${_trezor_suite_asc_file_path}"
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo rm -fR /home/user/squashfs-root'
  
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo apt -y autoremove && apt -y autoclean'
  qvm-run --pass-io ${_whonix_ws_trezor_wm_name} 'sudo fstrim -av'

  qvm-shutdown --wait ${_whonix_ws_trezor_wm_name}
}

###############################################################################
# MAIN 
###############################################################################
function main(){
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
  sudo qubesctl --skip-dom0 --templates state.sls update.qubes-vm

  utils::update_to_new_fedora_template
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
  trezor::create::udev-rule-file
utils::pause
  trezor::install::trezor-common::fedora-xx-sys
utils::pause
  trezor::config::whonix-ws-trezor
utils::pause
  printf '%s\n'  "Trezor Suite downloaded and installed!"
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

  declare _trezor_suite_file_name=''
  declare _trezor_suite_asc_file_name=''
  declare _trezor_suite_file_path=''
  declare _trezor_suite_asc_file_path=''

  declare _trezor_suite_app_url=''
  declare _trezor_suite_asc_url=''

main

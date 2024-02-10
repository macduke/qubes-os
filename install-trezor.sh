#!/bin/bash
declare s_satoshilaps_private_key=''
declare s_satoshilaps_private_key_url=''
declare s_satoshilaps_local_path=''
declare s_trezor_suite_app_url=''
declare s_trezor_suite_asc_url=''
declare s_trezor_suite_file_name=''
declare s_trezor_suite_asc_file_name=''
declare s_trezor_suite_file_path=''
declare s_trezor_suite_asc_file_path=''
declare s_json_git_response=''
declare s_latest_trezor_version=''
declare b_verbose=''
declare s_fingerprint=''

s_satoshilaps_private_key='satoshilabs-2021-signing-key.asc'
s_satoshilaps_private_key_url="https://trezor.io/security/${s_satoshilaps_private_key}"
s_satoshilaps_key_fingerprint='Keyfingerprint=EB483B26B078A4AA1B6F425EE21B6950A2ECB65C'
s_satoshilaps_local_path="/home/user/${s_satoshilaps_private_key}"
s_git_trezor_repo='trezor/trezor-suite'
s_trezor_release_url="https://api.github.com/repos/${s_git_trezor_repo}/releases/latest"
b_verbose='TRUE'

###############################################################################
while true
do
  if scurl --max-time 5 --silent --head https://trezor.io
  then
    break
  else
    printf '%s\n' "Waiting till whonix can reach the internet."
    sleep 10
    continue
  fi
done
###############################################################################

s_json_git_response="$(scurl -s ${s_trezor_release_url})"

# Neueste Release-Version aus den JSON-Daten extrahieren
s_latest_trezor_version=$(printf '%s' "${s_json_git_response}" | \
                          grep -o '"tag_name": "[^"]*' | \
                          grep -o '[^"]*$')
#printf '%s\n' "Trezor Suite Version is ${s_latest_trezor_version}"

sudo apt -y install jq
s_trezor_suite_app_url=$(printf '%s' "${s_json_git_response}" | \
  jq -r '.assets[] | select(.name | endswith("linux-x86_64.AppImage")) | .browser_download_url')
#printf '%s' "${s_trezor_suite_app_url}"

#printf '%s\n' "Trezor Suite download url: ${s_trezor_suite_app_url}"
# Trezor-release-url for the Linux x86_64 AppImage asc file
s_trezor_suite_asc_url="${s_trezor_suite_app_url}.asc"

s_trezor_suite_file_name="Trezor-Suite-${s_latest_trezor_version}-linux-x86_64.AppImage"
s_trezor_suite_asc_file_name="${s_trezor_suite_file_name}.asc"
s_trezor_suite_file_path="/home/user/${s_trezor_suite_file_name}"
s_trezor_suite_asc_file_path="/home/user/${s_trezor_suite_asc_file_name}"

# Newest Release-Asset (Linux x86_64 AppImage) Trezor-Suite-24.1.2-linux-x86_64
#printf '%s\n' "Getting Trezor Suite version ${s_latest_trezor_version} (AppImage)..."
scurl --silent ${s_trezor_suite_app_url} \
      --output ${s_trezor_suite_file_path}

# Download asc-file
#printf '%s\n' "Loading signature file for the trezor suite version ${s_latest_trezor_version}..."
scurl --silent ${s_trezor_suite_asc_url} \
      --output ${s_trezor_suite_asc_file_path}

# Download and Import the signing key
scurl --silent ${s_satoshilaps_private_key_url} \
      --output ${s_satoshilaps_local_path}

# Import the public key of the Satoshilabs. This is necessary to check the downloaded trezor suite
# Key fingerprint = EB48 3B26 B078 A4AA 1B6F  425E E21B 6950 A2EC B65C
gpg --keyid-format long \
    --import \
    --import-options show-only \
    --with-fingerprint ${s_satoshilaps_local_path}

s_fingerprint=$(gpg --keyid-format long \
                    --import --quiet \
                    --import-options show-only \
                    --with-fingerprint ${s_satoshilaps_local_path} \
                    | grep 'Key fingerprint' | sed 's/ //g')

if [[ "${s_fingerprint}" == "${s_satoshilaps_key_fingerprint}" ]]
then
  gpg --import ${s_satoshilaps_local_path}
else
  print '%s\n' "Unable to verify ${s_satoshilaps_local_path}!"
  print '%s\n' "STOPPING!"
  exit 1
fi

# checking signature
printf '%s\n' "Checking signature!"
if gpg --verify ${s_trezor_suite_asc_file_name} ${s_trezor_suite_file_path}
then
  print '%s\n' "Signature verification successful."
else
  print '%s\n' "Unable to verify ${s_trezor_suite_file_name}!"
  print '%s\n' "STOPPING!"
  exit 1
fi

chmod +x ${s_trezor_suite_file_path}

# printf '%s\n' "Extract Trezor Suite AppImage: ${s_trezor_suite_file_name}"
${s_trezor_suite_file_path} --appimage-extract >/dev/null
sed -i 's|^Exec=.*|Exec=/home/user/trezor-suite/trezor-suite.AppImage|' \
       /home/user/squashfs-root/trezor-suite.desktop

mkdir -p /home/user/.local/share/applications
mkdir -p /home/user/.local/share/icons

cp -a /home/user/squashfs-root/trezor-suite.desktop /home/user/.local/share/applications/
cp -a /home/user/squashfs-root/usr/share/icons/hicolor/0x0/apps/trezor-suite.png /home/user/.local/share/icons/
sudo mkdir -vp /home/user/trezor-suite
sudo mv ${s_trezor_suite_file_path} /home/user/trezor-suite/
sudo ln /home/user/trezor-suite/${s_trezor_suite_file_name} \
        /home/user/trezor-suite/trezor-suite.AppImage

# Some Cleanup
sudo rm -f ${s_satoshilaps_local_path}
sudo rm -f ${s_trezor_suite_asc_file_path}
sudo rm -fR /home/user/squashfs-root

sudo apt -y autoremove && sudo apt -y autoclean
sudo fstrim -av

exit 0
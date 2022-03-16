#!/usr/bin/bash

  if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
    pacman -Sy --noconfirm --needed artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    if [[ "$(find /install_script/configs -name pacman.conf)" ]]; then
      cp /install_script/configs/pacman.conf /etc/pacman.conf
      pacman -Syy 
    else
      j=1
      IFS=' ' 
      read -ra LANGUAGES_array <<< "$LANGUAGES_generate"
      for language in "${LANGUAGES_array[@]}"; do
        suffix="$j"
        if [[ "${language:0:2}" == "en" ]]; then
          declare "srv_$suffix"="${language:0:5}"
        else
          declare "srv_$suffix"="${language:0:2}"
        fi 
        let j++
      done
      for ((i=1; i<$(($j+1)); i++)); do
        language="srv_$i"
        language_size="${!language}"
        if ! [[ "${!language}" == "en_"* ]]; then
          if [[ "${#language_size}" -eq "2" ]]; then
            sed -i '33s/$/ !*locale*\/'"${!language}"'*\/*/' configs/pacman.conf
            sed -i '37s/$/ !usr\/share\/*locales\/'"${!language}"'*/' configs/pacman.conf
            sed -i '40s/$/ !*\/'"${!language}"'-*.pak/' configs/pacman.conf
            sed -i '41s/$/ !*\/'"${!language}"'-*.pak/' configs/pacman.conf
          fi
        elif [[ "${!language}" == "en_"* ]]; then
          sed -i '40s/$/ !*\/'"${!language}"'-*.pak/' configs/pacman.conf
          sed -i '41s/$/ !*\/'"${!language}"'-*.pak/' configs/pacman.conf
        fi
      done
      cp configs/pacman.conf /etc/pacman.conf
      pacman -Syy 
    fi
  fi

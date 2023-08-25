#!/usr/bin/bash

# Functions for checking user-input

  SIZE_check() {
    INPUT_type="$1"
    if ! [[ "$DRIVE_size" == "" ]]; then
      if ! [[ "$DRIVE_size" =~ ^[0-9]+$ ]]; then echo; PRINT_MESSAGE "Only numbers please!"; PROCEED="false"
      else 
        if [[ "$INPUT_type" == "BOOT" ]]; then
          if [[ "$DRIVE_size" -lt "500" ]]; then echo; PRINT_MESSAGE "Minimum 500 MB is required for the boot-partition!"; echo; PROCEED="false"
          else export BOOT_size=$DRIVE_size; PROCEED="true"; fi
        elif [[ "$INPUT_type" == "HOME" ]]; then
          if [[ "$DRIVE_size" -gt "$SIZE_cleaned" ]]; then PRINT_MESSAGE "Invalid size; bigger than whole drive!"; echo; PROCEED="false"            
          else export HOME_size=$DRIVE_size; PROCEED="true"; fi
        elif [[ "$INPUT_type" == "SWAP" ]]; then
          export SIZE_megabytes=$((DRIVE_size * 1000)); export SWAP_size=$((SIZE_megabytes+BOOT_size)); PROCEED="true"; fi
      fi
    else PROCEED="true"; fi
}

  LABEL_check() {
    INPUT_type="$1"
    if ! [[ "$DRIVE_label" == "" ]]; then
      if [[ "$INPUT_type" == "BOOT" ]]; then
        if [[ "${#DRIVE_label}" -ge "11" ]]; then echo; PRINT_MESSAGE "Maximum 11 characters is allowed for FAT32!"; PROCEED="false"
        else export BOOT_label=$DRIVE_label; PROCEED="true"; fi
      elif [[ "$INPUT_type" == "HOME" ]]; then export HOME_label=$DRIVE_label; PROCEED="true"
      elif [[ "$INPUT_type" == "SWAP" ]]; then export SWAP_label=$DRIVE_label; PROCEED="true"
      elif [[ "$INPUT_type" == "PRIMARY" ]]; then export PRIMARY_label=$DRIVE_label; PROCEED="true"; fi
    else PROCEED="true"; fi
}

  ENCRYPTION_check() {
    if [[ "$ENCRYPTION_passwd_export" == "" ]]; then
      echo; PRINT_MESSAGE "An empty encryption-password is... not so strong!"; PROCEED="false"
    else export ENCRYPTION_passwd=$ENCRYPTION_passwd_export; PROCEED="true"; fi
}

  TIMEZONE_check() {
   if ! [[ -f "/usr/share/zoneinfo/"$TIMEZONE_export"" ]] && ! [[ "$TIMEZONE_export" == "" ]]; then PRINT_MESSAGE "Illegal timezone!"; PROCEED="false"   
   elif [[ "$TIMEZONE_export" == "" ]]; then PROCEED="true";
   else export TIMEZONE=$TIMEZONE_export; PROCEED="true"; fi
}

  LANGUAGE_check() {
    if [[ "$1" == "generate" ]]; then
      IFS=','
      read -ra languages <<< "$LANGUAGES_generate_export"
      if ! [[ "$LANGUAGES_generate_export" == "" ]]; then
        for ((val=0; val < "${#languages[@]}"; val++)); do 
          if grep -Eq "#${languages[$val]} UTF-8" /etc/locale.gen; then correct="true";
          else PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""; correct="false"; fi
        done
        if [[ "$correct" == "true" ]]; then export LANGUAGES_generate=$LANGUAGES_generate_export; PROCEED="true"
        else PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""; PROCEED="false"; fi
      else PROCEED="true"; fi
    elif [[ "$1" == "system" ]]; then
      if [[ $(grep -Eq "#$LANGUAGE_system_export UTF-8" /etc/locale.gen) ]] && ! [[ "$LANGUAGES_generate_export" == "" ]]; then PROCEED="true"; export LANGUAGE_system=$LANGUAGE_system_export;
      elif [[ "$LANGUAGE_system_export" == "" ]]; then PROCEED="true";
      else PRINT_MESSAGE "Illegal language!"; fi
    fi
}

  KEYMAP_check() {
    if ! [[ $(loadkeys "$KEYMAP_system_export") ]] && ! [[ "$KEYMAP_system_export" == "" ]]; then PRINT_MESSAGE "Illegal keymap!";
    elif [[ "$KEYMAP_system_export" == "" ]]; then PROCEED="true";
    else export KEYMAP_system=$KEYMAP_system_export; PROCEED="true"; fi
}

  HOSTNAME_check() {
    if ! [[ "$HOSTNAME_system_export" == "" ]]; then export HOSTNAME_system=$HOSTNAME_system_export; PROCEED="true"
    else PROCEED="true"; fi
}

  USER_check() {
    if [[ "$1" == "password" ]]; then
      if [[ "$ROOT_passwd_export" == "" ]]; then PRINT_MESSAGE "Empty password!";  
      elif [[ "$USER_passwd_export" == "" ]] && ! [[ "$USERNAME_export" == "" ]]; then PRINT_MESSAGE "Empty password!";
      else PROCEED="true"; fi
    elif [[ "$1" == "username" ]]; then
      if [[ "$USERNAME_export" == "" ]]; then PRINT_MESSAGE "Empty username!";
      else export USERNAME=$USERNAME_export; PROCEED="true"; fi    
    fi   
}

  PACKAGES_check() {
    if ! [[ "$PACKAGES_additional_export" == "NONE" ]]; then
      unavailable_packages="0"
      IFS="," 
      read -ra packages_to_install <<< "$PACKAGES_additional_export"
      for ((val=0; val<"${#packages_to_install[@]}"; val++)); do 
        if ! [[ $(pacman -Si "${packages_to_install[$val]}") ]] ; then echo "${packages_to_install[$val]} is not found in repos!"; unavailable_packages+=1; fi
      done
      if ! [[ "$unavailable_packages" == "0" ]]; then PRINT_MESSAGE "Illegal packages!";
      elif [[ "$PACKAGES_additional_export" == "" ]]; then PROCEED="true";
      else PACKAGES_additional_export_clean=$(echo "$PACKAGES_additional_export" | tr "," " "); export PACKAGES_additional=$PACKAGES_additional_export_clean; PROCEED="true"; fi
    elif [[ "$PACKAGES_additional_export" == "NONE" ]]; then export PACKAGES_additional=$PACKAGES_additional_export; PROCEED="true"; fi 
}

  POST_SCRIPT_check() {
    if [[ "$1" == "repo" ]]; then
      if ! [[ "$POST_script_export" == "SKIP" ]]; then
        if ! [[ "$POST_script_export" == "" ]]; then
          file="${POST_script_export##*/}"
          if ! wget -q https://"$POST_script_export" > /dev/null 2>&1; then PRINT_MESSAGE "Invalid git-repo!"; rm -rf "$file" 
          else export POST_install_script=$POST_script_export; export basename=$(basename "$POST_install_script"); export basename_clean=${basename%.*}; PROCEED="true"; fi 
        elif [[ "$POST_script_export" == "" ]]; then PRINT_MESSAGE "No repo specified!"; fi   
      elif [[ "$POST_script_export" == "SKIP" ]]; then export POST_install_script=NONE; export POST_install_script_name=NONE; PROCEED="true"; fi
    elif [[ "$1" == "path" ]]; then
      if ! [[ "$POST_script_name_export" == "" ]]; then
        if ! [[ -d "test" ]]; then mkdir test; git clone -q https://"$POST_install_script"; fi
        if [ -f "$basename_clean/$POST_script_name_export" ]; then export POST_install_script_name=$POST_script_name_export; rm -rf test; PROCEED="true"
        else PRINT_MESSAGE "Invalid path to script!"; fi
      elif [[ "$POST_script_name_export" == "" ]]; then PRINT_MESSAGE "Empty path to script!"; fi
    fi
}

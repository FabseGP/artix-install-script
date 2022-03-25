#!/usr/bin/bash

# DO NOT TOUCH!

  set -a # Force export all variables; most relevant for answerfile
  if [[ -f "/.encrypt/.answer_encrypt.txt" ]]; then
    openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -in /.encrypt/.answer_encrypt.txt -out /.decrypt/.decrypt.txt -pass file:/.nothing/.nothing.txt
    source /.decrypt/.decrypt.txt
  else
    source answerfile
  fi
  COLUMNS=$(tput cols) 
  BEGINNER_DIR=$(pwd)
  RAM_size="$(($(free -g | grep Mem: | awk '{print $2}') + 1))"
  mapfile -t DRIVES < <(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}')
  core_count=$(($(grep -c ^processor /proc/cpuinfo) / 2))

#----------------------------------------------------------------------------------------------------------------------------------

# Configurable variables

  # Choices during install
  FILESYSTEM_primary_bcachefs=""
  FILESYSTEM_primary_btrfs=""
  ENCRYPTION_partitions=""
  SWAP_partition=""
  INIT_choice=""
  REPLACE_networkmanager=""
  REPLACE_sudo=""
  REPLACE_elogind=""
  POST_script=""

  # Drives and partitions + encryption
  DRIVE_path="" 
  DRIVE_path_boot=""
  DRIVE_path_swap=""
  DRIVE_path_primary=""
  BOOT_size="300"
  BOOT_label="BOOT"
  SWAP_size="$((RAM_size * 1000))"
  SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
  SWAP_label="RAM_co"
  PRIMARY_size="∞"
  PRIMARY_label="PRIMARY"
  ENCRYPTION_passwd="NOT CHOSEN"
  MOUNTPOINT=""

  # Locals
  TIMEZONE="Europe/Copenhagen"
  LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  LANGUAGE_system="en_GB.UTF-8"
  KEYMAP_system="dk-latin1"
  HOSTNAME_system="artix"

  # Users
  ROOT_username="root"
  ROOT_passwd="NOT CHOSEN"
  USERNAME="NOT CHOSEN"
  USER_passwd="NOT CHOSEN"

  # Miscellaneous
  BOOTLOADER_label="ARTIX_BOOT"
  PACKAGES_additional="NONE"
  POST_install_script="NOT CHOSEN"
  POST_install_script_name="NOT CHOSEN"
  WRONG=""
  PROCEED=""
  CONFIRM=""

#----------------------------------------------------------------------------------------------------------------------------------

# Parameters that customizes the system-install

  # BCACHEFS-support
  if ! grep -q bcachefs "/proc/filesystems"; then
    BCACHEFS_implemented="false"
    BCACHEFS_notice="(BCACHEFS as filesystem) # NOTICE: Currently not implemented"
  else
    BCACHEFS_implemented="true"
    BCACHEFS_notice="BCACHEFS as filesystem"
  fi

  # Subvolumes to be created 
  subvolumes=(
    \@
    "home"
    "var/cache"
    "var/log"
    "var/spool"
    "var/tmp"
    "opt"
    "tmp"
    "srv"
    ".snapshots"
    "root"
    "grub"
    "snapshot"
  )

  # Size of tmpfs (/tmp) 
  RAM_size_G_half="$((RAM_size / 2))G" # tmpfs will fill half the RAM-size

  # Groups which user is added to 
  export USER_groups="wheel,realtime,video,audio,network,uucp,input,storage,disk,lp,scanner"

  # Miscellaneous security enhancements 
  export LOGIN_delay="3000000" # Delays initial login with 3 seconds if wrong credentials

#----------------------------------------------------------------------------------------------------------------------------------

# Source answerfile if conditions is met

  if [[ "$INTERACTIVE_INSTALL" == "false" ]]; then
    if [[ -f "/.encrypt/.answer_encrypt.txt" ]]; then
      openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -in /.encrypt/.answer_encrypt.txt -out /.decrypt/.decrypt.txt -pass file:/.nothing/.nothing.txt
      source /.decrypt/.decrypt.txt
    else
      source answerfile
    fi
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Colors for any output

  PRINT_WITH_COLOR(){
    case "$1" in
      red)
        echo -e "\033[91m$2\033[0m"
        ;;
      green)
        echo -e "\033[92m$2\033[0m"
        ;;
      yellow)
        echo -e "\033[93m$2\033[0m"
        ;;
      blue)
        echo -e "\033[94m$2\033[0m"
        ;;
      purple)
        echo -e "\033[95m$2\033[0m"
        ;;
      cyan)
        echo -e "\033[96m$2\033[0m"
        ;;
      white)
        echo -e "\033[97m$2\033[0m"
        ;;
    esac
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions to print text / outputs of commands / lines

  PRINT_LINES() {
  if [[ "$1" == "SPACE" ]]; then
    echo
    printf '%0.s-' $(seq 1 "$COLUMNS")
    echo
  else
    printf '%0.s-' $(seq 1 "$COLUMNS")
  fi
}

  PRINT_MESSAGE() {
    OUTPUT="$*"
    echo
    printf '%0.s-' $(seq 1 "$COLUMNS")
    printf "%*s\n" $((("${#OUTPUT}"+"$COLUMNS")/2)) "$OUTPUT" | lolcat
    printf '%0.s-' $(seq 1 "$COLUMNS")
    echo
}

  PRINT_PROGRESS_BAR() {
    local progress_bar="."
    printf "%s" "${progress_bar}"
}

#----------------------------------------------------------------------------------------------------------------------------------

# Choices to present in text-menu

  intro=(
    "INTRO"
    "FILESYSTEM_primary_btrfs:BTRFS as filesystem"
    "FILESYSTEM_primary_bcachefs:$BCACHEFS_notice"
    "ENCRYPTION_partitions:Encryption" 
    "SWAP_partition:Swap-partition" 
    "INIT_choice_runit:runit as init" 
    "INIT_choice_openrc:openrc as init" 
    "INIT_choice_dinit:dinit as init" 
    "REPLACE_networkmanager:Replace NetworkManager with connman # NOTICE: connman doesn't conflict with NetworkManager"
    "REPLACE_sudo:Replace sudo with doas # NOTICE: doas doesn't conflict with sudo" 
    "REPLACE_elogind:Replace elogind with seatd # NOTICE: a elogind-dummy-package is installed, though NetworkManager requires elogind"
    "POST_script:Execute post-install script as regular user"
)

  drive_selection=(
    "DRIVE_SELECTION"
    "${DRIVES[@]}"
)

  PARTITIONS="VALUE,BOOT-PARTITION (1),SWAP-PARTITION (2),PRIMARY-PARTITION (3)"
  PARTITIONS_without_swap="VALUE,BOOT-PARTITION (1),PRIMARY-PARTITION (2)"
  LOCALS="VALUE,TIMEZONE (1),LANGUAGES (2),KEYMAP (3),HOSTNAME (4)"
  USERS="VALUE,root (1),personal (2)"
  MISCELLANEOUS=",BOOTLOADER-ID (1),ADDITIONAL PACKAGES (2),POST INSTALL SCRIPT (3)"

#----------------------------------------------------------------------------------------------------------------------------------

# Function to update user-chosen choices when printing

  UPDATE_CHOICES() {

    read -r -d '' OUTPUT_partitions_full << EOM
$PARTITIONS
SIZE:,$BOOT_size MB,$SWAP_size MB, $PRIMARY_size MB
LABEL:,$BOOT_label,$SWAP_label,$PRIMARY_label
ENCRYPTION-password:,,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_partitions_without_swap << EOM
$PARTITIONS_without_swap
SIZE:,$BOOT_size MB, $PRIMARY_size MB
LABEL:,$BOOT_label,$PRIMARY_label
ENCRYPTION-password:,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_locals << EOM
$LOCALS
GENERATED:,,$LANGUAGES_generate
SYSTEMWIDE:,$TIMEZONE,$LANGUAGE_system,$KEYMAP_system,$HOSTNAME_system
EOM

    read -r -d '' OUTPUT_users << EOM
$USERS
USERNAME:,$ROOT_username,$USERNAME
PASSWORD:,$ROOT_passwd,$USER_passwd
EOM

    read -r -d '' OUTPUT_miscellaneous << EOM
$MISCELLANEOUS
VALUE:,$BOOTLOADER_label,$PACKAGES_additional,$POST_install_script
PATH:,,,$POST_install_script_name
EOM
}

#----------------------------------------------------------------------------------------------------------------------------------

# Messages to print

  messages=(
    "figlet -c -t -k WELCOME | lolcat -a -d 3 && echo && figlet -c -t -k You are about to install Artix Linux! | lolcat -a -d 2" # Intro
    "figlet -c -t -k FAREWELL - THIS TIME FOR REAL! | lolcat -a -d 3 && echo" # Goodbye
    "To tailer the installation to your needs, you have the following options: " # Choices for customizing install
    "USAGE: Tapping SPACE reverts the value, while tapping ENTER confirms your choices! " # Usage of text-menu
    "AM I A JOKE TO YOU?! YOU DIDN'T EVEN BOTHER TO CHOOSE AN INIT NOR A FILESYSTEM!" # Usage of text-menu
    "YOU NEED TO CHOOSE ONE OF THE LISTED INIT! " # If none of the init is chosen
    "YOU NEED TO CHOOSE ONE OF THE LISTED FILESYSTEM! " # If none of the init is chosen
    "Please select the drive to be partitioned! " # Drive-selection
    "YOU NEED TO CHOOSE ONE OF THE LISTED DRIVES! " # Drive-selection
    "TIME TO FORMAT THESE DRIVES!" # While specifying sizes / labels for the partitions
    "TIME TO LOCALIZE YOUR SYSTEM!" # While configuring locals
    "WE CAN ALL BENEFIT FROM MORE USERS!" # While configuring the users
    "TIME TO PACK UP!" # When configuring miscellaneous options
    "AND VOILA - YOU NOW HAVE A FULLY FUNCTIONAL ARTIX INSTALL!" # When... done
    "THIS SCRIPT MUST BE RUN AS ROOT!" # When user is not root and an argument isn't passed
)

#----------------------------------------------------------------------------------------------------------------------------------

# Insure that the script is run as root-user

  if [[ -z "$1" ]] && ! [[ "$USER" == 'root' ]]; then
    echo
    PRINT_LINES
    printf "%*s\n" $((("${#messages[14]}"+"$COLUMNS")/2)) "${messages[14]}"
    PRINT_LINES
    exit 1
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for printing tables

  PRINT_TABLE() {
    local -r delimiter="${1}"
    local -r data="$(REMOVE_EMPTY_LINES "${2}")"
    if ! [[ "${delimiter}" == "" ]] && [[ "$(EMPTY_STRING "${data}")" = "false" ]]; then
      local -r numberOfLines="$(wc -l <<< "${data}")"
      if [[ "${numberOfLines}" -gt "0" ]]; then
        local table=""
        local i=1
        for ((i=1; i<="${numberOfLines}"; i++)); do
          local line=""
          line="$(sed "${i}q;d" <<< "${data}")"
          local numberOfColumns="0"
          numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"
          if [[ "${i}" -eq "1" ]]; then
            table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"
          fi
          table="${table}\n"
          local j=1
          for ((j=1; j<="${numberOfColumns}"; j++)); do
            table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
          done
          table="${table}#|\n"
          if [[ "${i}" -eq "1" ]] || [[ "${numberOfLines}" -gt "1" && "${i}" -eq "${numberOfLines}" ]]; then
            table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"
          fi
        done
        if [[ "$(EMPTY_STRING "${table}")" = "false" ]]; then
          echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
        fi
      fi
    fi
}

  REMOVE_EMPTY_LINES() {
    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

  REPEAT_STRING() {
    local -r string="${1}"
    local -r numberToRepeat="${2}"
    if ! [[ "${string}" == "" ]] && [[ "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
      local -r result="$(printf "%${numberToRepeat}s")"
      echo -e "${result// /${string}}"
    fi
}

  EMPTY_STRING() {
    local -r string="${1}"
    if [[ "$(TRIM_STRING "${string}")" = "" ]]; then
      echo 'true' && return 0
    fi
    echo 'false' && return 1
}

  TRIM_STRING() {
    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for printing menu

  MULTISELECT_MENU() {
    until [[ "$PROCEED" == "true" ]]; do 
      ESC=$( printf "\033")
      cursor_blink_on() { 
        printf "$ESC[?25h"
      }
      cursor_blink_off() { 
        printf "$ESC[?25l" 
      }
      cursor_to() { 
        printf "$ESC[$1;${2:-1}H"
      }
      print_inactive() { 
        printf "$2   $1 "
      }
      print_active() { 
        printf "$2  $ESC[7m $1 $ESC[27m" 
      }
      get_cursor_row() { 
        IFS=';' read -rsdR -p $'\E[6n' ROW COL 
        echo "${ROW#*[}"
      }
      options=("$@")
      return_value="result"
      selected=()
      if ! [[ "$WRONG" == "true" ]]; then
        if [[ "${options[0]}" == "INTRO" ]]; then
          PRINT_MESSAGE "${messages[2]}" 
          PRINT_MESSAGE "${messages[3]}"
          selected=("true")
          printf "\n"
        elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then  
          PRINT_MESSAGE "${messages[7]}"    
        fi
        echo
        for ((i=1; i<${#options[@]}; i++)); do
          selected+=("false")
          printf "\n"
        done
      else
        if [[ "${options[0]}" == "INTRO" ]]; then
          selected=("true")
          printf "\n"
        fi
        for ((i=1; i<${#options[@]}; i++)); do
          selected+=("${values[i]}")
          printf "\n"
        done
      fi
      lastrow=$(get_cursor_row)
      startrow=$((lastrow - ${#options[@]}))
      trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
      cursor_blink_off
      key_input() { 
        local key
        IFS=""
        read -rsn1 key 2> /dev/null >&2
        if [[ "$key" = "" ]]; then 
          echo enter
        elif [[ "$key" = $'\x20' ]]; then 
          echo space
        elif [[ "$key" = $'\x1b' ]]; then
          read -rsn2 key
          if [[ "$key" = "[A" ]]; then
            echo up
          elif [[ "$key" = "[B" ]]; then 
            echo down
          fi
        fi 
      }
      toggle_option() {
        local option=$1
        if [[ "${selected[option]}" == "true" ]]; then
          selected[option]="false"
        else
          selected[option]="true"
        fi
      }
      print_options() {
        local index=0
        for option in "${options[@]:1:${#options[@]}}"; do
          sorted=${option#*:}
          local prefix="[ ]"
          if [[ "${selected[index]}" == "true" ]]; then
            prefix="[\e[38;5;46m✔\e[0m]"
          fi
          cursor_to $(("$startrow" + "$index"))
          if [[ "$index" -eq "$1" ]]; then
            print_active "$sorted" "$prefix"
          else
            print_inactive "$sorted" "$prefix"
          fi
          ((index++))
        done
      }
      local active=0
      while true; do
        print_options $active
        case $(key_input) in
          space)  
            print_options -1 
            if [[ "${options[0]}" == "INTRO" ]]; then
              COUNT_init=$(grep -o true <<< "${selected[@]:4:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              if [[ "$COUNT_init" -eq "1" ]] && [[ "$active" == @(4|5|6) ]]; then
                eval selected[{4..6}]=false
                toggle_option $active
              elif [[ "$BCACHEFS_implemented" == "true" ]] && [[ "$COUNT_filesystem" -eq 1 ]] && [[ "$active" == @(0|1) ]]; then
                eval selected[{0..1}]=false
                toggle_option $active
              elif [[ "$active" == "7" ]] && [[ "${selected[7]}" == "true" ]] && [[ "${selected[9]}" == "true" ]]; then
                eval selected[7]=false
                eval selected[9]=false
              elif [[ "$active" == "9" ]] && [[ "${selected[7]}" == "false" ]]; then
                :
              elif [[ "$BCACHEFS_implemented" == "false" ]] && [[ "$active" == @(0|1)	 ]]; then
                :
              else
                toggle_option $active
              fi
            elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then
              DRIVES="$((${#options[@]} - 2))"
              COUNT_drive=$(grep -o true <<< "${selected[@]}" | wc -l)
              if [[ "$COUNT_drive" -eq "1" ]]; then
                for i in $(eval "echo {0..$DRIVES}"); do
                  eval selected[i]=false   	  	
                done
                toggle_option $active	
              else
                toggle_option $active
              fi
            fi
            ;;
          enter)  
            print_options -1 
            if [[ "${options[0]}" == "INTRO" ]]; then
              export COUNT_init=$(grep -o true <<< "${selected[@]:4:3}" | wc -l)
              export COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              export COUNT_intro="${#selected[@]}"
              export values=("${selected[@]}")
              if [[ "$COUNT_init" == "0" ]] && [[ "$COUNT_filesystem" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[4]}"
              elif [[ "$COUNT_init" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[5]}"
              elif [[ "$COUNT_filesystem" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[6]}"
              else
                INTRO_choices="$((${#selected[@]} - 1))"
                for ((i=0, j=1; i<INTRO_choices; i++, j++)); do
                  VALUE=${selected[i]}
                  CHOICE=${options[j]%%:*}
                  export $CHOICE=$VALUE
                done
                PROCEED="true"
              fi
            elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then
              COUNT_drive=$(grep -o true <<< "${selected[@]}" | wc -l)
              if [[ "$COUNT_drive" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[8]}"
              else
                for i in $(eval "echo {0..$DRIVES}"); do
                  if [[ "${selected[i]}" == "true" ]]; then
                    j=$((i+1))
                    PATH_cleaned=$(echo "${options[j]}" | cut -d'|' -f 1)
                    export "DRIVE_path"="$PATH_cleaned"
                    if [[ "$SWAP_partition" == "true" ]]; then
                      if [[ "$DRIVE_path" == *"nvme"* ]]; then
                        export DRIVE_path_boot=""$DRIVE_path"p1"
                        export DRIVE_path_swap=""$DRIVE_path"p2"
                        export DRIVE_path_primary=""$DRIVE_path"p3"
                      else
                        export DRIVE_path_boot=""$DRIVE_path"1"
                        export DRIVE_path_swap=""$DRIVE_path"2"
                        export DRIVE_path_primary=""$DRIVE_path"3"
                      fi
                    else 
                      if [[ "$DRIVE_path" == *"nvme"* ]]; then
                        export DRIVE_path_boot=""$DRIVE_path"p1"
                        export DRIVE_path_primary=""$DRIVE_path"p2"
                      else
                        export DRIVE_path_boot=""$DRIVE_path"1"
                        export DRIVE_path_primary=""$DRIVE_path"2"
                      fi
                    fi
                  fi 	  	   	  	
                done
                PROCEED="true"
              fi
            fi
            break
            ;;
          up)     
            ((active--)); 
            if [[ "$active" -lt "0" ]]; then 
              active=$((${#options[@]}-1)) 
            fi
            ;;
          down)   
            ((active++)); 
            if [[ "$active" -ge "$((${#options[@]}-1))" ]]; then 
              active=0
            fi
            ;;
        esac
      done
      cursor_to "$lastrow"
      printf "\n"
      cursor_blink_on
      eval $return_value='("${selected[@]}")'
    done
    PROCEED=""
    WRONG=""
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for checking user-input

  SIZE_check() {
    if ! [[ "$DRIVE_size" == "" ]]; then
      if ! [[ "$DRIVE_size" =~ ^[0-9]+$ ]]; then
        echo
        PRINT_MESSAGE "Only numbers please!"
        PROCEED="false"
      elif [[ "${user_choices[$val]}" == "1" ]]; then
        if [[ "$DRIVE_size" -le "300" ]]; then
          echo
          PRINT_MESSAGE "Minimum 300 MB is required for the boot-partition!"
          echo
          PROCEED="false"
        else
          export BOOT_size=$DRIVE_size
          PROCEED="true"
        fi
      else
        export SWAP_size=$DRIVE_size
        export SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
        PROCEED="true"
      fi
    else
      PROCEED="true"
    fi
}

  LABEL_check() {
    if ! [[ "$DRIVE_label" == "" ]]; then
      if [[ "${user_choices[$val]}" == "1" ]] && [[ "${#DRIVE_label}" -ge "11" ]]; then
        echo
        PRINT_MESSAGE "Maximum 11 characters is allowed for FAT32!"
        PROCEED="false"
      else
        if [[ "${user_choices[$val]}" == "1" ]]; then
          export BOOT_label=$DRIVE_label
        elif [[ "${user_choices[$val]}" == "2" ]]; then
          if [[ "$SWAP_partition" == "true" ]]; then
            export SWAP_label=$DRIVE_label
          else
            export PRIMARY_label=$DRIVE_label
          fi
        elif [[ "${user_choices[$val]}" == "3" ]]; then
          export PRIMARY_label=$DRIVE_label
        fi
        PROCEED="true"
      fi
    else
      PROCEED="true"
    fi
}

  ENCRYPTION_check() {
    if [[ "$ENCRYPTION_passwd_export" == "" ]]; then
      echo
      PRINT_MESSAGE "An empty encryption-password is... not so strong!"
      PROCEED="false"
    else
      export ENCRYPTION_passwd=$ENCRYPTION_passwd_export
      PROCEED="true"
    fi
}

  TIMEZONE_check() {
   if ! [[ -f "/usr/share/zoneinfo/"$TIMEZONE_export"" ]] && ! [[ "$TIMEZONE_export" == "" ]]; then
     PRINT_MESSAGE "Illegal timezone!"  
     PROCEED="false"   
   elif [[ "$TIMEZONE_export" == "" ]]; then
     PROCEED="true"
   else
     export TIMEZONE=$TIMEZONE_export
     PROCEED="true"
   fi
}

  LANGUAGE_check() {
    if [[ "$1" == "generate" ]]; then
      IFS=','
      read -ra languages <<< "$LANGUAGES_generate_export"
      if ! [[ "$LANGUAGES_generate_export" == "" ]]; then
        for ((val=0; val < "${#languages[@]}"; val++)); do 
          if grep -Eq "#${languages[$val]} UTF-8" /etc/locale.gen; then
            correct="true"
          else
            PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""   
            correct="false"  
          fi
        done
        if [[ "$correct" == "true" ]]; then
          export LANGUAGES_generate=$LANGUAGES_generate_export
          PROCEED="true"
        else 
          PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""   
          PROCEED="false"
        fi
      else
        PROCEED="true"
      fi
    elif [[ "$1" == "system" ]]; then
      if [[ $(grep -Eq "#$LANGUAGE_system_export UTF-8" /etc/locale.gen) ]] && ! [[ "$LANGUAGES_generate_export" == "" ]]; then 
        PROCEED="true"
        export LANGUAGE_system=$LANGUAGE_system_export
      elif [[ "$LANGUAGE_system_export" == "" ]]; then
        PROCEED="true"
      else
        PRINT_MESSAGE "Illegal language!"     
      fi
    fi
}

  KEYMAP_check() {
    if ! [[ $(loadkeys "$KEYMAP_system_export") ]] && ! [[ "$KEYMAP_system_export" == "" ]]; then
      PRINT_MESSAGE "Illegal keymap!" 
    elif [[ "$KEYMAP_system_export" == "" ]]; then
      PROCEED="true"
    else
      export KEYMAP_system=$KEYMAP_system_export 
      PROCEED="true"
    fi
}

  HOSTNAME_check() {
    if ! [[ "$HOSTNAME_system_export" == "" ]]; then
      export HOSTNAME_system=$HOSTNAME_system_export
      PROCEED="true"
    else
      PROCEED="true"
    fi
}

  USER_check() {
    if [[ "$1" == "password" ]]; then
      if [[ "$ROOT_passwd_export" == "" ]]; then
        PRINT_MESSAGE "Empty password!"   
      elif [[ "$USER_passwd_export" == "" ]] && ! [[ "$USERNAME_export" == "" ]]; then
        PRINT_MESSAGE "Empty password!"  
      else 
        PROCEED="true"
      fi
    elif [[ "$1" == "username" ]]; then
      if [[ "$USERNAME_export" == "" ]]; then
        PRINT_MESSAGE "Empty username!"  
      else  
        export USERNAME=$USERNAME_export
        PROCEED="true"
      fi    
    fi   
}

  PACKAGES_check() {
    if ! [[ "$PACKAGES_additional_export" == "NONE" ]]; then
      unavailable_packages="0"
      IFS=","
      read -ra packages_to_install <<< "$PACKAGES_additional_export"
      for ((val=0; val<"${#packages_to_install[@]}"; val++)); do 
        if ! [[ $(pacman -Si "${packages_to_install[$val]}") ]] ; then
          echo "${packages_to_install[$val]} is not found in repos!"
          unavailable_packages+=1
        fi
      done
      if ! [[ "$unavailable_packages" == "0" ]]; then
        PRINT_MESSAGE "Illegal packages!"
      elif [[ "$PACKAGES_additional_export" == "" ]]; then
        PROCEED="true"
      else
        PACKAGES_additional_export_clean=$(echo "$PACKAGES_additional_export" | tr "," " ")
        export PACKAGES_additional=$PACKAGES_additional_export_clean
        PROCEED="true"
      fi
    elif [[ "$PACKAGES_additional_export" == "NONE" ]]; then   
      export PACKAGES_additional=$PACKAGES_additional_export
      PROCEED="true"
    fi 
}

  POST_SCRIPT_check() {
    if [[ "$1" == "repo" ]]; then
      if ! [[ "$POST_script_export" == "SKIP" ]]; then
        if ! [[ "$POST_script_export" == "" ]]; then
          file="${POST_script_export##*/}"
          wget -q https://$POST_script_export > /dev/null 2>&1
          if [[ $? -ne 0 ]]; then
            PRINT_MESSAGE "Invalid git-repo!"
            rm -rf "$file" 
          else            
            export POST_install_script=$POST_script_export
            export basename=$(basename $POST_install_script)
            export basename_clean=${basename%.*}
            PROCEED="true"
          fi 
        elif [[ "$POST_script_export" == "" ]]; then
          PRINT_MESSAGE "No repo specified!"   
        fi   
      elif [[ "$POST_script_export" == "SKIP" ]]; then 
        export POST_install_script=NONE
        export POST_install_script_name=NONE
        PROCEED="true"  
      fi
    elif [[ "$1" == "path" ]]; then
      if ! [[ "$POST_script_name_export" == "" ]]; then
        if ! [[ -d "test" ]]; then
          mkdir test
          git clone -q https://$POST_install_script
        fi
        if [ -f "$basename_clean/$POST_script_name_export" ]; then
          export POST_install_script_name=$POST_script_name_export
          rm -rf test
          PROCEED="true"
        else
          PRINT_MESSAGE "Invalid path to script!"           
        fi
      elif [[ "$POST_script_name_export" == "" ]]; then
        PRINT_MESSAGE "Empty path to script!"   
      fi
    fi
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for customizing install

  CUSTOMIZING_INSTALL() {
    while ! [[ "$CONFIRM_proceed" == "true" ]]; do
      PROCEED="false"
      echo
      IFS=
      if [[ "$USERNAME_export" == "" ]] && [[ "$1" == "USERS" ]]; then
        CONFIRM="1,2,3,4"
      elif [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$ENCRYPTION_passwd_export" == "" ]] && [[ "$1" == "PARTITIONS_full" || "$1" == "PARTITIONS_without_swap"	 ]]; then
        if [[ "$SWAP_partition" == "true" ]]; then
          CONFIRM="3"
        else
          CONFIRM="2"
        fi
        ENCRYPTION_type_password="true"
      elif [[ "$POST_script" == "true" ]] && [[ "$POST_script_export" == "" ]] && [[ "$1" == "MISCELLANEOUS" ]]; then
        CONFIRM="3"
      else
        read -rp "Anything to modify? (1|1,2|A|N|RETURN TO START) " CONFIRM
      fi
      echo	
      if [[ "$CONFIRM" == "N" ]]; then
        CONFIRM_proceed="true"
      elif [[ "$CONFIRM" == "RETURN TO START" ]]; then
        ./$(basename "$0") restart && exit
      elif [[ "$CONFIRM" == "A" ]] || [[ "$CONFIRM" =~ [1-4,] ]]; then
        if [[ "$CONFIRM" == "A" ]]; then
          CONFIRM="1,2,3,4"
        fi
        if [[ "$1" == "PARTITIONS_full" ]] || [[ "$1" == "PARTITIONS_without_swap" ]]; then
          IFS=','
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "BOOT-partition size (leave empty for default): " DRIVE_size
                  SIZE_check
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "BOOT-partition label (leave empty for default): " DRIVE_label
                  LABEL_check
                done
                PROCEED="false"
                echo
                ;;
              2)
                if [[ "$SWAP_partition" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "SWAP-partition size (leave empty for default): " DRIVE_size
                    SIZE_check
                  done
                  PROCEED="false"
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "SWAP-partition label (leave empty for default): " DRIVE_label
                    LABEL_check
                  done
                  PROCEED="false"
                  echo
                else
                  if ! [[ "$ENCRYPTION_type_password" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "PRIMARY-label (leave empty for default): " DRIVE_label
                      LABEL_check
                    done
                  fi
                  PROCEED="false"
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "Encryption-password: " ENCRYPTION_passwd_export
                      ENCRYPTION_check
                    done
                    PROCEED="false"
                    ENCRYPTION_type_password=""
                  fi
                fi
                ;;
              3)
                if [[ "$SWAP_partition" == "true" ]]; then
                  if ! [[ "$ENCRYPTION_type_password" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "PRIMARY-label (leave empty for default): " DRIVE_label
                      LABEL_check
                    done
                  fi
                  PROCEED="false"
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "Encryption-password: " ENCRYPTION_passwd_export
                      ENCRYPTION_check
                    done
                    PROCEED="false"
                    ENCRYPTION_type_password=""
                  fi
                fi
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          if [[ "$SWAP_partition" == "true" ]]; then
            PRINT_TABLE ',' "$OUTPUT_partitions_full"
          else
            PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
          fi
        elif [[ "$1" == "LOCALS" ]]; then
          IFS=','
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "TIMEZONE (leave empty for default); e.g. \"Europe/Copenhagen\": " TIMEZONE_export
                  TIMEZONE_check
                done          
                PROCEED="false"
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Comma-separated languages to generate (leave empty for default); e.g. \"da_DK.UTF-8,en_GB.UTF-8\": " LANGUAGES_generate_export
                  LANGUAGE_check generate
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Systemwide language (leave empty for default): " LANGUAGE_system_export
                  LANGUAGE_check system
                done
                PROCEED="false"
                echo
                ;;
              3)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Systemwide keymap (leave empty for default): " KEYMAP_system_export
                  KEYMAP_check
                done   
                PROCEED="false"
                echo
                ;;
              4)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Systemwide hostname (leave empty for default): " HOSTNAME_system_export
                  HOSTNAME_check
                done 
                PROCEED="false"
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_locals"
        elif [[ "$1" == "USERS" ]]; then
          IFS=','
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)       
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Password for root: " ROOT_passwd_export
                  USER_check password
                done     
                PROCEED="false"
                export ROOT_passwd=$ROOT_passwd_export
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Username for personal user: " USERNAME_export
                  USER_check username
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Password for personal user: " USER_passwd_export
                  USER_check password
                done     
                PROCEED="false"
                export USER_passwd=$USER_passwd_export
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_users"
        elif [[ "$1" == "MISCELLANEOUS" ]]; then
          IFS=','	
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "BOOTLOADER-ID (leave empty for default): " BOOTLOADER_label_export 
                if ! [[ "$BOOTLOADER_label_export" == "" ]]; then
                  export BOOTLOADER_label=$BOOTLOADER_label_export
                fi
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Additional packages to install (separated by comma); e.g. \"firefox,kicad\" or \"NONE\": " PACKAGES_additional_export 
                  PACKAGES_check
                done   
                PROCEED="false"
                echo
                ;;
              3)
                if [[ "$POST_script" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "Git-repo that contains the script; e.g. \"gitlab.com/FabseGP02/artix-install-script.git\" or \"SKIP\": " POST_script_export
                    POST_SCRIPT_check repo
                  done
                  PROCEED="false"
                  if ! [[ "$POST_script_export" == "SKIP" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "Path to script within the cloned folder; e.g. \"install_artix.sh\": " POST_script_name_export
                      POST_SCRIPT_check path
                    done
                    PROCEED="false"
                    echo
                  fi
                fi
                ;; 
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_miscellaneous"
        fi
      else
        echo "WRONG CHOICE!"
      fi
    done	
    CONFIRM_proceed="false"
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions that installs the system

  SCRIPT_01_REQUIRED_PACKAGES() {
    if [[ -z "$(pacman -Qs lolcat)" ]]; then
      printf "%s" "Installing dependencies "
      local command="pacman -Sy --noconfirm --needed lolcat figlet parted wget"
      $command > /dev/null 2>&1 &
      while ! [[ $(pacman -Qs lolcat) ]]; do
        PRINT_PROGRESS_BAR 
        sleep 1
      done
      printf " [%s]\n" "Success!"
    fi
    if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
      chmod u+x scripts/repositories.sh
      if [[ "$INTERACTIVE_INSTALL" == "true" ]]; then
        scripts/repositories.sh > /dev/null 2>&1 &
      else
        scripts/repositories.sh
      fi
    fi
}
 
  SCRIPT_02_CHOICES() {
    eval "${messages[0]}"
    export ENTRY="intro"
    MULTISELECT_MENU "${intro[@]}"
    if [[ "$INIT_choice_runit" == "true" ]]; then
      export INIT_choice="runit"
    elif [[ "$INIT_choice_openrc" == "true" ]]; then
      export INIT_choice="openrc"
    elif [[ "$INIT_choice_dinit" == "true" ]]; then
      export INIT_choice="dinit"
    fi
}

  SCRIPT_03_CUSTOMIZING() {
    if [[ "$ENCRYPTION_partitions" == "false" ]]; then
      export ENCRYPTION_passwd="IGNORED"
    fi
    if [[ "$POST_script" == "false" ]]; then
      export POST_install_script="IGNORED"
      export POST_install_script_name="IGNORED"
    fi
    UPDATE_CHOICES
    MULTISELECT_MENU "${drive_selection[@]}"
    PRINT_MESSAGE "${messages[9]}" 
    if [[ "$SWAP_partition" == "true" ]]; then
      PRINT_TABLE ',' "$OUTPUT_partitions_full"
      CUSTOMIZING_INSTALL PARTITIONS_full
    else
      PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
      CUSTOMIZING_INSTALL PARTITIONS_without_swap
    fi
    PRINT_MESSAGE "${messages[10]}" 
    PRINT_TABLE ',' "$OUTPUT_locals"
    CUSTOMIZING_INSTALL LOCALS
    PRINT_MESSAGE "${messages[11]}" 
    PRINT_TABLE ',' "$OUTPUT_users"
    CUSTOMIZING_INSTALL USERS
    PRINT_MESSAGE "${messages[12]}" 
    PRINT_TABLE ',' "$OUTPUT_miscellaneous"
    CUSTOMIZING_INSTALL MISCELLANEOUS
}

  SCRIPT_04_UMOUNT_MNT() {
    if [[ "$(mountpoint /mnt)" ]]; then
      swapoff -a
      umount -A --recursive /mnt
    fi
}

  SCRIPT_05_CREATE_PARTITIONS() {
    if [[ "$SWAP_partition" == "true" ]]; then
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart SWAP linux-swap "$BOOT_size"MiB "$SWAP_size_allocated"MiB  \
        mkpart PRIMARY "$SWAP_size_allocated"MiB 100% 
    else
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart PRIMARY "$BOOT_size"MiB 100% 
    fi
}

  SCRIPT_06_FORMAT_AND_ENCRYPT_PARTITIONS() {
    mkfs.vfat -F32 -n "$BOOT_label" "$DRIVE_path_boot" 
    if [[ "$SWAP_partition" == "true" ]]; then
      mkswap -L "$SWAP_label" "$DRIVE_path_swap"
      swapon "$DRIVE_path_swap"
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
        echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
        mkfs.btrfs -f -L "$PRIMARY_label" /dev/mapper/cryptroot
        MOUNTPOINT="/dev/mapper/cryptroot"
      else
        mkfs.btrfs -f -L "$PRIMARY_label" "$DRIVE_path_primary"
        MOUNTPOINT="$DRIVE_path_primary"
      fi
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        bcachefs format -f --encrypted --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"
      else
        bcachefs format -f --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"        
      fi
    fi
}

  SCRIPT_07_CREATE_SUBVOLUMES_AND_MOUNT_PARTITIONS() {
    export UUID_1=$(blkid -s UUID -o value "$DRIVE_path_primary")
    export UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_path_primary" | awk '$1=="part"{print $2}' | tr -d -)
    mount -o noatime,compress=zstd "$MOUNTPOINT" /mnt
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        if ! [[ "${subvolumes[subvolume]}" == "@" ]]; then
          if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
            chattr +C "${subvolumes[subvolume]}"
          elif [[ "${subvolumes[subvolume]}" == ".snapshots" ]]; then
            btrfs subvolume create "/mnt/@/.snapshots"
            mkdir -p /mnt/@/.snapshots/1
          elif [[ "${subvolumes[subvolume]}" == "snapshot" ]]; then
            btrfs subvolume create "/mnt/@/.snapshots/1/snapshot"
          elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
            btrfs subvolume create "/mnt/@/boot/grub"
          else
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
          fi
        else
          btrfs subvolume create "/mnt/${subvolumes[subvolume]}"
          mkdir -p /mnt/@/{var,boot}
        fi
      elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
        bcachefs subvolume create "${subvolumes[subvolume]}"
      fi
    done
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      touch /mnt/@/.snapshots/1/info.xml
      date=$(date +"%Y-%m-%d %H:%M:%S")
      cat << EOF | tee -a /mnt/@/.snapshots/1/info.xml > /dev/null
<?xml version="1.0"?>
<snapshot>
<type>single</type>
	<num>1</num>
	<date>$date</date>
	<description>First snapshot created at installation</description>
</snapshot>
EOF
      btrfs subvolume set-default "$(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+')" /mnt
      btrfs quota enable /mnt
      btrfs qgroup create 1/0 /mnt
    fi
    umount /mnt
    mount "$MOUNTPOINT" -o noatime,compress=zstd /mnt
    mkdir -p /mnt/{etc/pacman.d/hooks,.secret}
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      subvolume_path=$(string="${subvolumes[subvolume]}"; echo "${string//@/}")
      if ! [[ "${subvolumes[subvolume]}" == "@" || "${subvolumes[subvolume]}" == "snapshot" ]]; then
        if ! [[ "${subvolumes[subvolume]}" == "grub" ]]; then
          mkdir -p /mnt/"${subvolumes[subvolume]}"
          if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
            mount -o noatime,nodatacow,discard=async,nodev,noexec,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
          elif [[ "${subvolumes[subvolume]}" == "home" ]]; then
            mount -o noatime,compress=zstd,discard=async,nodev,nosuid,subvol="@/home" "$MOUNTPOINT" /mnt/home
          elif [[ "${subvolumes[subvolume]}" == ".snapshots" ]] || [[ "${subvolumes[subvolume]}" == "srv" ]]; then
            mount -o noatime,compress=zstd,discard=async,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
          else
            mount -o noatime,compress=zstd,discard=async,nodev,noexec,nosuid,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
          fi  
        elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
          mkdir -p /mnt/boot/{efi,grub}
          mount -o noatime,compress=zstd,discard=async,nodev,noexec,nosuid,subvol="@/boot/grub" "$MOUNTPOINT" /mnt/boot/grub
        fi
      fi
    done
    sync
    cd "$BEGINNER_DIR" || exit
    mount -o nodev,nosuid,noexec "$DRIVE_path_boot" /mnt/boot/efi
}	
 
  SCRIPT_08_BASESTRAP_PACKAGES() {         
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      ucode="intel-ucode"
    elif grep -q AMD "/proc/cpuinfo"; then
      ucode="amd-ucode"
    fi
    if [[ "$REPLACE_sudo" == "true" ]]; then
      su="opendoas"
    else
      su="sudo"
    fi
    if [[ "$REPLACE_elogind" == "true" ]]; then
      seat="seatd-$INIT_choice"
    else
      seat="elogind-$INIT_choice"
    fi
    if [[ "$REPLACE_networkmanager" == "true" ]]; then
      network="connman-$INIT_choice"
    else
      network="networkmanager-$INIT_choice"
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      filesystem="grub-btrfs"
    else
      filesystem="bcachefs-tools"
    fi
      basestrap /mnt $INIT_choice cronie-$INIT_choice cryptsetup-$INIT_choice iwd-$INIT_choice backlight-$INIT_choice \
                     chrony-$INIT_choice booster zstd realtime-privileges efibootmgr grub base base-devel dosfstools \
                     iptables-nft pacman-contrib linux-zen linux-zen-headers linux-firmware git $ucode $seat $network \
                     $su $filesystem --ignore mkinitcpio
}

  SCRIPT_09_FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    sed -i 's/,subvolid=.*,subvol=\/@\/.snapshots\/1\/snapshot//' /mnt/etc/fstab
    if [[ "$SWAP_partition" == "true" ]]; then
      export DRIVE_path_swap_clean=$(echo '\'"${DRIVE_path_swap:0:4}"'\'"${DRIVE_path_swap:4:${#DRIVE_path_swap}}"'')
      sed -i '1,/'"$DRIVE_path_swap_clean"' LABEL='"$SWAP_label"'/!d' /mnt/etc/fstab
      UUID_swap=$(lsblk -no TYPE,UUID "$DRIVE_path_swap" | awk '$1=="part"{print $2}')
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
swap     UUID=$UUID_swap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512

EOF
      cat << EOF | tee -a /mnt/etc/fstab > /dev/null
/dev/mapper/swap	none	swap	defaults	0	0

EOF
    fi
}

  SCRIPT_10_CHROOT() {
    mkdir /mnt/install_script
    cp -r -- * /mnt/install_script
    for ((function=0; function < "${#functions[@]}"; function++)); do
      if [[ "${functions[function]}" == *"SYSTEM"* ]]; then
        export -f "${functions[function]}"
        artix-chroot /mnt /bin/bash -c "${functions[function]}"
      fi
    done
}

  SYSTEM_01_LOCALS() {
    # Timezone
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    hwclock --systohc
    # Language(s)
    j=1
    IFS=' ' 
    read -ra LANGUAGES_array <<< "$LANGUAGES_generate"
    for language in "${LANGUAGES_array[@]}"; do
      sed -i '/'"$language"'/s/^#//g' /etc/locale.gen
    done
    locale-gen
    echo "LANG="$LANGUAGE_system"" >> /etc/locale.conf
    echo "LC_ALL="$LANGUAGE_system"" >> /etc/locale.conf
    # Keymap
    echo "KEYMAP="$KEYMAP_system"" >> /etc/vconsole.conf
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "KEYMAP="$KEYMAP_system"" >> /etc/conf.d/keymaps
    fi
    # Hostname
    echo "$HOSTNAME_system" >> /etc/hostname
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "hostname='"$HOSTNAME_system"'" >> /etc/conf.d/hostname
    fi
    cat << EOF | tee -a /etc/hosts > /dev/null
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME_system.localdomain $HOSTNAME_system 
EOF
}

  SYSTEM_02_USERS() {
    echo "root:$ROOT_passwd" | chpasswd
    useradd -m -g users -G "$USER_groups" "$USERNAME"
    if [[ "$REPLACE_elogind" == "true" ]]; then
      usermod -a -G seatd "$USERNAME"
    fi
    ( echo "$USER_passwd" ; echo "$USER_passwd" ) | passwd -q "$USERNAME"
}

  SYSTEM_03_ADDITIONAL_PACKAGES() {
    cd /install_script/scripts || exit
    ./repositories.sh
    if ! [[ "$PACKAGES_additional" == "NONE" ]]; then
      pacman -S --noconfirm --needed "$PACKAGES_additional"
    fi
}

  SYSTEM_04_AUR() {
    cd /install_script/packages || exit
    PARU="$(ls -- *paru-*)"
    pacman -U --noconfirm $PARU
    touch /etc/bash.bashrc
    cat << EOF | tee -a /etc/bash.bashrc > /dev/null    
# Redirect yay to paru + making rm safer
alias yay=paru
alias rm='rm -i'

EOF
    mkdir -p /home/"$USERNAME"
    touch /home/"$USERNAME"/.bashrc      
    cat << EOF | tee -a /home/"$USERNAME"/.bashrc > /dev/null    
# Redirect yay to paru + making rm safer
alias yay=paru
alias rm='rm -i'

EOF
    cp /install_script/configs/paru.conf /etc/paru.conf # Links sudo to doas + more
    cp /install_script/configs/makepkg.conf /etc/makepkg.conf
    if [[ "$core_count" -gt 1 ]]; then 
      sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$core_count\"/g" /etc/makepkg.conf
    fi
}

  SYSTEM_05_SUPERUSER() {
    if [[ "$REPLACE_sudo" == "true" ]]; then
      touch /etc/doas.conf
      cat << EOF | tee -a /etc/doas.conf > /dev/null
permit persist setenv { XAUTHORITY LANG LC_ALL } :wheel
EOF
      chown -c root:root /etc/doas.conf
      chmod -c 0400 /etc/doas.conf
      cat << EOF | tee -a /etc/bash.bashrc > /dev/null 
# Redirect sudo to doas
alias sudo=doas   

# Adds tab-completion
complete -cf doas

EOF
      cat << EOF | tee -a /home/"$USERNAME"/.bashrc > /dev/null    
# Redirect sudo to doas
alias sudo=doas

# Adds tab-completion
complete -cf doas

EOF
    else
      sed -i -e "/Sudo = doas/s/^#*/;/" /etc/paru.conf
      echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)
    fi
}

  SYSTEM_06_SERVICES() {
    if [[ "$REPLACE_networkmanager" == "true" ]]; then
      export network_manager="connmand"
    else
      export network_manager="NetworkManager"
      touch /etc/NetworkManager/conf.d/wifi_backend.conf
      cat << EOF | tee -a /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null
[device]
wifi.backend=iwd
EOF
    fi
    for service in $network_manager iwd cronie backlight seatd chronyd; do
      if [[ "$REPLACE_elogind" == "true" && "$service" == "seatd" ]] || ! [[ "$service" == "seatd" ]]; then
        if [[ "$INIT_choice" == "dinit" ]]; then
          ln -s /etc/dinit.d/$service /etc/dinit.d/boot.d
        elif [[ "$INIT_choice" == "runit" ]]; then
          ln -s /etc/runit/sv/$service /etc/runit/runsvdir/default
        elif [[ "$INIT_choice" == "openrc" ]]; then
          rc-update add $service
        fi
      fi
    done
}

  SYSTEM_07_CRYPTKEY() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      dd bs=512 count=6 if=/dev/random of=/.secret/crypto_keyfile.bin iflag=fullblock
      chmod 600 /.secret/crypto_keyfile.bin
      chmod 600 /boot/booster-linux*
      echo "$ENCRYPTION_passwd" | cryptsetup luksAddKey "$DRIVE_path_primary" /.secret/crypto_keyfile.bin
    fi
}

  SYSTEM_08_SNAPPER() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      pacman -S --noconfirm snap-pac
      cd /install_script || exit
      umount /.snapshots
      rm -r /.snapshots
      snapper --no-dbus -c root create-config /
      cp configs/snapper.conf /etc/snapper/configs/root
      sed -i "s/USERNAME/$USERNAME/" /etc/snapper/configs/root
      btrfs subvolume delete /.snapshots
      mkdir /.snapshots
      mount -a
      chmod a+rx /.snapshots
      chown :wheel /.snapshots
      cp configs/snap-pac.ini /etc/snap-pac.ini
      sed -i 's/INIT/'"$INIT_choice"'/' hooks/05-snap-pac-pre.hook
      sed -i 's/INIT/'"$INIT_choice"'/' hooks/zz-snap-pac-post.hook
      sed -i 's/INIT/'"$INIT_choice"'/' hooks/zz_snap-pac-grub-post.hook
      cp hooks/{05-snap-pac-pre.hook,10-snap-pac-removal.hook,zz-snap-pac-post.hook,zz_snap-pac-grub-post.hook} /usr/share/libalpm/hooks
      cp hooks/{05-snap-pac-pre.hook,10-snap-pac-removal.hook,zz-snap-pac-post.hook,zz_snap-pac-grub-post.hook} /.secret
      cp hooks/snap-pac-config.hook /etc/pacman.d/hooks
    fi
}

  SYSTEM_09_BOOTLOADER() {
    cd /install_script || exit
    cp configs/10_linux /etc/grub.d/10_linux
    cp configs/10_linux /.secret
    sed -i 's/GRUB_GFXMODE="1024x768,800x600"/GRUB_GFXMODE="auto"/' /etc/default/grub
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      sed -i 's/rootflags=subvol=${rootsubvol}//' /etc/grub.d/20_linux_xen  
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then	
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ splash\ nowatchdog\ rd.luks.name='"$UUID_1"'=cryptroot\ root=\/dev\/mapper\/cryptroot\ rd.luks.allow-discards\ rd.luks.key=\/.secret\/crypto_keyfile.bin"/' /etc/default/grub
        sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt\ part_msdos\ luks2"/' /etc/default/grub
        sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
        touch grub-pre.cfg
        cat << EOF | tee -a grub-pre.cfg > /dev/null
cryptomount -u $UUID_2 
set root=crypto0
set prefix=(crypto0)/@/boot/grub
insmod normal
normal
EOF
        grub-mkimage -p '/boot/grub' -O x86_64-efi -c grub-pre.cfg -o /tmp/image luks2 btrfs part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha512
        cp /tmp/image /boot/efi/EFI/"$BOOTLOADER_label"/grubx64.efi
        grub-mkconfig -o /boot/grub/grub.cfg
        rm -rf {/tmp/image,grub-pre.cfg}
      fi
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      :
    fi
    if ! [[ "$ENCRYPTION_partitions" == "true" ]]; then
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ splash\ nowatchdog"/' /etc/default/grub
      grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
      grub-mkconfig -o /boot/grub/grub.cfg
    fi
    cp hooks/grub-booster.hook /etc/pacman.d/hooks
}

  SYSTEM_10_PACKAGES_INSTALL_AND_REMOVE() {
    cd /install_script/packages || exit   
    if [[ "$REPLACE_sudo" == "true" ]]; then
      pacman -Rns --noconfirm sudo
    fi
    if [[ "$REPLACE_elogind" == "true" ]]; then
      ELOGIND="$(ls -- *elogind-*)"
      pacman -U --noconfirm $ELOGIND
      pacman -S --noconfirm pam_rundir
    fi
}

  SYSTEM_11_MISCELLANEOUS() {
    cd /install_script || exit
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    sed -i 's/nullok//g' /etc/pam.d/system-auth
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/g' /etc/pam.d/su
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/g' /etc/pam.d/su-l
    echo 'PRUNENAMES = ".snapshots"' >> /etc/updatedb.conf # Prevent snapshots from being indexed
    cp hooks/{check-broken-packages.hook,pacman-cache-cleanup.hook} /usr/share/libalpm/hooks
    cp scripts/check-broken-packages /usr/bin
    chmod 755 /usr/bin/check-broken-packages
    touch /etc/tmpfiles.d/tmp.conf
    cat << EOF | tee -a /etc/tmpfiles.d/tmp.conf > /dev/null
D! /tmp 1777 root root 0
EOF
    if [[ "$INIT_choice" == "openrc" ]]; then
      sed -i 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf
      sed -i 's/#unicode="NO"/unicode="YES"/g' /etc/rc.conf
      sed -i 's/#rc_depend_strict="YES"/rc_depend_strict="NO"/g' /etc/rc.conf
    fi
    if [[ "$(lsblk --discard)" ]]; then
      cp scripts/ssd_trim.sh /etc/cron.weekly
      chmod u+x /etc/cron.weekly/ssd_trim.sh
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      cp scripts/btrfs_scrub.sh /etc/cron.monthly
      cp scripts/grub-mkconfig /usr/share/libalpm/scripts
      chmod u+x /etc/cron.monthly/btrfs_scrub.sh
      chmod 755 /usr/share/libalpm/scripts/grub-mkconfig
    fi

}

  SYSTEM_12_POST_SCRIPT() {
    if [[ "$POST_script" == "true" ]] && ! [[ "$POST_install_script" == "NONE" ]]; then
      pacman -S --noconfirm git
      export basename=$(basename $POST_install_script)
      export basename_clean=${basename%.*}
      if [[ "$REPLACE_sudo" == "true" ]]; then
        echo "permit nopass $USERNAME" | tee -a /etc/doas.conf > /dev/null
      else
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers > /dev/null
      fi
      su -l "$USERNAME" -c "git clone https://$POST_install_script; cd "$basename_clean"; chmod u+x "$POST_install_script_name"; bash "$POST_install_script_name""
      rm -rf /home/$USERNAME/$basename_clean
      if [[ "$REPLACE_sudo" == "true" ]]; then
        sed -i "/permit nopass $USERNAME/d" /etc/doas.conf
      else
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
      fi
    fi
}

  SYSTEM_13_CLEANUP() {
    rm -rf /install_script
}

  SCRIPT_11_FAREWELL() {
    echo
    PRINT_MESSAGE "${messages[13]}" 
    exec env --ignore-environment /bin/bash
    exit
}

  # Must be the last command in this section to export all defined functions
  mapfile -t functions < <( compgen -A function ) 

#----------------------------------------------------------------------------------------------------------------------------------

# Actual execution of commands

  if [[ "$INTERACTIVE_INSTALL" == "false" ]]; then
    if [[ "$DRIVE_path" == "ASK" ]]; then
      MULTISELECT_MENU "${drive_selection[@]}"
    else
      if [[ "$SWAP_partition" == "true" ]]; then
        if [[ "$DRIVE_path" == *"nvme"* ]]; then
          export DRIVE_path_boot=""$DRIVE_path"p1"
          export DRIVE_path_swap=""$DRIVE_path"p2"
          export DRIVE_path_primary=""$DRIVE_path"p3"
        else
          export DRIVE_path_boot=""$DRIVE_path"1"
          export DRIVE_path_swap=""$DRIVE_path"2"
          export DRIVE_path_primary=""$DRIVE_path"3"
        fi
      else 
        if [[ "$DRIVE_path" == *"nvme"* ]]; then
          export DRIVE_path_boot=""$DRIVE_path"p1"
          export DRIVE_path_primary=""$DRIVE_path"p2"
        else
          export DRIVE_path_boot=""$DRIVE_path"1"
          export DRIVE_path_primary=""$DRIVE_path"2"
        fi
      fi   
    fi        
  fi

  # Executing functions
  for ((function=0; function < "${#functions[@]}"; function++)); do
    if [[ "${functions[function]}" == "SCRIPT"* ]]; then
      if [[ "$INTERACTIVE_INSTALL" == "true" ]] && [[ "${functions[function]}" == "SCRIPT_02"* || "${functions[function]}" == "SCRIPT_03"* ]]; then
        "${functions[function]}"
      else
        "${functions[function]}"
      fi
    fi
  done

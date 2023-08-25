#!/usr/bin/bash

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
        if [[ "${options[0]}" == "INTRO" ]]; then PRINT_MESSAGE "${messages[2]}"; PRINT_MESSAGE "${messages[3]}"; selected=("true"); printf "\n";
        elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then PRINT_MESSAGE "${messages[7]}"; fi 
        echo
        for ((i=1; i<${#options[@]}; i++)); do selected+=("false"); printf "\n"; done
      else
        if [[ "${options[0]}" == "INTRO" ]]; then selected=("true"); printf "\n"; fi
        for ((i=1; i<${#options[@]}; i++)); do selected+=("${values[i]}"); printf "\n"; done
      fi
      lastrow=$(get_cursor_row) 
      startrow=$((lastrow - ${#options[@]}))
      trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
      cursor_blink_off
      key_input() { 
        local key
        IFS=""
        read -rsn1 key 2> /dev/null >&2
        if [[ "$key" = "" ]]; then echo enter;
        elif [[ "$key" = $'\x20' ]]; then echo space;
        elif [[ "$key" = $'\x1b' ]]; then read -rsn2 key;
          if [[ "$key" = "[A" ]]; then echo up;
          elif [[ "$key" = "[B" ]]; then echo down; fi
        fi 
      }
      toggle_option() {
        local option=$1
        if [[ "${selected[option]}" == "true" ]]; then selected[option]="false";
        else selected[option]="true"; fi
      }
      print_options() {
        local index=0
        for option in "${options[@]:1:${#options[@]}}"; do
          sorted=${option#*:}
          local prefix="[ ]"
          if [[ "${selected[index]}" == "true" ]]; then prefix="[\e[38;5;46m✔\e[0m]"; fi
          cursor_to $(("$startrow" + "$index"))
          if [[ "$index" -eq "$1" ]]; then print_active "$sorted" "$prefix";
          else print_inactive "$sorted" "$prefix"; fi
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
              COUNT_init=$(grep -o true <<< "${selected[@]:5:7}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:1}" | wc -l)
              COUNT_bootloader=$(grep -o true <<< "${selected[@]:8:9}" | wc -l)
              if [[ "$COUNT_init" -gt "0" ]] && [[ "$active" == @(5|6|7) ]]; then eval selected[{5..7}]=false; toggle_option $active
              elif [[ "$COUNT_bootloader" -gt "0" ]] && [[ "$active" == @(8|9) ]]; then eval selected[{8..9}]=false; toggle_option $active
              elif [[ "$BCACHEFS_implemented" == "true" ]] && [[ "$COUNT_filesystem" -eq 1 ]] && [[ "$active" == @(0|1) ]]; then eval selected[{0..1}]=false; toggle_option $active
              elif [[ "$BCACHEFS_implemented" == "false" ]] && [[ "$active" == @(0|1)	 ]]; then :;
              else toggle_option $active; fi
            elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then
              DRIVES="$((${#options[@]} - 2))" 
              COUNT_drive=$(grep -o true <<< "${selected[@]}" | wc -l)
              if [[ "$COUNT_drive" -eq "1" ]]; then
                for i in $(eval "echo {0..$DRIVES}"); do eval selected[i]=false; done 	  	
                toggle_option $active	
              else toggle_option $active; fi
            fi
            ;;
          enter)  
            print_options -1 
            if [[ "${options[0]}" == "INTRO" ]]; then
              export COUNT_intro="${#selected[@]}"
              export values=("${selected[@]}")
              export COUNT_init=$(grep -o true <<< "${selected[@]:5:7}" | wc -l)
              export COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              export COUNT_bootloader=$(grep -o true <<< "${selected[@]:8:9}" | wc -l)
              if [[ "$COUNT_init" == "0" ]] && [[ "$COUNT_filesystem" == "0" ]]; then WRONG="true"; echo; PRINT_MESSAGE "${messages[4]}";
              elif [[ "$COUNT_init" == "0" ]]; then WRONG="true"; echo; PRINT_MESSAGE "${messages[5]}";
              elif [[ "$COUNT_bootloader" == "0" ]]; then WRONG="true"; echo; PRINT_MESSAGE "${messages[15]}";
              elif [[ "$COUNT_filesystem" == "0" ]]; then WRONG="true"; echo; PRINT_MESSAGE "${messages[6]}";
              else
                INTRO_choices="$((${#selected[@]} - 1))"
                for ((i=0, j=1; i<INTRO_choices; i++, j++)); do VALUE=${selected[i]}; CHOICE=${options[j]%%:*}; export $CHOICE=$VALUE; done
                PROCEED="true"
              fi
            elif [[ "${options[0]}" == "DRIVE_SELECTION" ]]; then
              COUNT_drive=$(grep -o true <<< "${selected[@]}" | wc -l)
              if [[ "$COUNT_drive" == "0" ]]; then WRONG="true"; echo; PRINT_MESSAGE "${messages[8]}";
              else
                for i in $(eval "echo {0..$DRIVES}"); do
                  if [[ "${selected[i]}" == "true" ]]; then
                    j=$((i+1))
                    PATH_cleaned=$(echo "${options[j]}" | cut -d'|' -f 1)
                    export "DRIVE_path"="$PATH_cleaned"
                    if [[ "$DRIVE_path" == *"nvme"* ]]; then
                      if [[ "$HOME_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_swap=""$DRIVE_path"p2"; export DRIVE_path_home=""$DRIVE_path"p3"; export DRIVE_path_primary=""$DRIVE_path"p4";
                      else export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_swap=""$DRIVE_path"p2"; export DRIVE_path_primary=""$DRIVE_path"p3"; fi
                    else
                      if [[ "$HOME_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_swap=""$DRIVE_path"2"; export DRIVE_path_home=""$DRIVE_path"3"; export DRIVE_path_primary=""$DRIVE_path"4";
                      else export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_swap=""$DRIVE_path"2"; export DRIVE_path_primary=""$DRIVE_path"3"; fi
                    fi
                  fi 	  	   	  	
                done
                SIZE_decimal=$(lsblk --output SIZE -n -d "$DRIVE_path")
                SIZE_cleaned=$(awk -v v="$SIZE_decimal" 'BEGIN{printf "%d", v}')        
                PROCEED="true"
              fi
            fi
            break
            ;;
          up)     
            ((active--)); 
            if [[ "$active" -lt "0" ]]; then active=$((${#options[@]}-1)); fi
            ;;
          down)   
            ((active++)); 
            if [[ "$active" -ge "$((${#options[@]}-1))" ]]; then active=0; fi
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

# Functions for customizing install

  CUSTOMIZING_INSTALL() {
    while ! [[ "$CONFIRM_proceed" == "true" ]]; do
      PROCEED="false" 
      echo 
      IFS=
      read -rp "Anything to modify? (1|1,2|A|N|RETURN TO START) " CONFIRM
      echo	
      if [[ "$CONFIRM" == "N" ]]; then
	      if [[ "$1" == PARTITIONS_* ]]; then
          if [[ "$BOOT_size" == "" ]]; then
            PRINT_MESSAGE "PLEASE CHOOSE A SIZE FOR YOUR BOOT-PARTITION!"
            if [[ "$HOME_partition" == "true" ]]; then PRINT_TABLE ',' "OUTPUT_partitions_full";
            else PRINT_TABLE ',' "$OUTPUT_partitions_without_home"; fi
          elif [[ "$SWAP_partition" == "true" ]] && [[ "$SWAP_size" == "" ]]; then
            PRINT_MESSAGE "PLEASE CHOOSE A SIZE FOR YOUR SWAP-PARTITION!"
            if [[ "$HOME_partition" == "true" ]]; then PRINT_TABLE ',' "OUTPUT_partitions_full";
            else PRINT_TABLE ',' "$OUTPUT_partitions_without_home"; fi
          elif [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$ENCRYPTION_passwd" == "NOT CHOSEN" ]]; then
            PRINT_MESSAGE "PLEASE CHOOSE AN ENCRYPTION-PASSWORD!"
            if [[ "$HOME_partition" == "true" ]]; then PRINT_TABLE ',' "$OUTPUT_partitions_full";
            else PRINT_TABLE ',' "$OUTPUT_partitions_without_home"; fi   
          elif [[ "$HOME_partition" == "true" ]] && [[ "$HOME_size" == "NOT CHOSEN" ]]; then
            PRINT_MESSAGE "PLEASE CHOOSE A SIZE FOR YOUR HOME-PARTITION!"
            if [[ "$HOME_partition" == "true" ]]; then PRINT_TABLE ',' "$OUTPUT_partitions_full";
            else PRINT_TABLE ',' "$OUTPUT_partitions_without_home"; fi;
          else CONFIRM_proceed="true"; fi; fi
        elif [[ "$1" == "USERS" ]]; then
          if [[ "$ROOT_passwd" == "NOT CHOSEN" ]]; then PRINT_MESSAGE "PLEASE CHOOSE A PASSWORD FOR ROOT!"; PRINT_TABLE ',' "$OUTPUT_users";
          elif [[ "$USER_passwd" == "NOT CHOSEN" ]]; then PRINT_MESSAGE "PLEASE CONFIGURE YOUR REGULAR USER!"; PRINT_TABLE ',' "$OUTPUT_users"
          else CONFIRM_proceed="true"; fi
        else CONFIRM_proceed="true"; fi
      elif [[ "$CONFIRM" == "RETURN TO START" ]]; then ./$(basename "$0") restart; exit 2;
      elif [[ "$CONFIRM" == "A" ]] || [[ "$CONFIRM" =~ [1-4,] ]]; then
        if [[ "$CONFIRM" == "A" ]]; then CONFIRM="1,2,3,4"; fi
        if [[ "$1" == PARTITIONS_* ]]; then
          IFS=',' 
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                until [[ "$PROCEED" == "true" ]]; do read -rp "BOOT-partition size in MB (leave empty for default): " DRIVE_size; SIZE_check BOOT; done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do read -rp "BOOT-partition label (leave empty for default): " DRIVE_label; LABEL_check BOOT; done
                PROCEED="false"
                echo
                ;;
              2)
                if [[ "$HOME_partition" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do read -rp "HOME-partition size in GB: " DRIVE_size; SIZE_check HOME; done
                  PROCEED="false"
                  until [[ "$PROCEED" == "true" ]]; do read -rp "HOME-partition label (leave empty for default): " DRIVE_label; LABEL_check HOME; done
                  PROCEED="false" 
                  echo
                else
                  if ! [[ "$ENCRYPTION_partitions" == "true" ]]; then until [[ "$PROCEED" == "true" ]]; do read -rp "PRIMARY-label (leave empty for default): " DRIVE_label; LABEL_check PRIMARY; done; fi
                  PROCEED="false"
                  echo
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      if ! [[ "$ENCRYPTION_passwd" == "" ]] && ! [[ "$ENCRYPTION_passwd" == "NOT CHOSEN" ]]; then
                        read -rp "Encryption-password (leave empty for unchanged): " ENCRYPTION_passwd_export
                        if [[ "$ENCRYPTION_passwd_export" == "" ]]; then PROCEED="true";
                        else ENCRYPTION_check; fi
                      else read -rp "Encryption-password: " ENCRYPTION_passwd_export; ENCRYPTION_check; fi
                    done
                    PROCEED="false"
                    echo
                  fi
                fi
                ;;
              3)
                if [[ "$HOME_partition" == "true" ]]; then
                  export PRIMARY_size=$((SIZE_cleaned-HOME_size))
                  until [[ "$PROCEED" == "true" ]]; do read -rp "PRIMARY-label (leave empty for default): " DRIVE_label; LABEL_check PRIMARY; done
                  PROCEED="false"
                  echo
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      if ! [[ "$ENCRYPTION_passwd" == "" ]] && ! [[ "$ENCRYPTION_passwd" == "NOT CHOSEN" ]]; then
                        read -rp "Encryption-password (leave empty for unchanged): " ENCRYPTION_passwd_export
                        if [[ "$ENCRYPTION_passwd_export" == "" ]]; then PROCEED="true";
                        else ENCRYPTION_check; fi
                      else read -rp "Encryption-password: " ENCRYPTION_passwd_export; ENCRYPTION_check; fi
                    done
                    PROCEED="false"
                    echo
                  fi
                else
                  if [[ "$SWAP_partition" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do read -rp "SWAP-partition size in GB (leave empty for default): " DRIVE_size; SIZE_check SWAP; done
                    PROCEED="false"
                    until [[ "$PROCEED" == "true" ]]; do read -rp "SWAP-partition label (leave empty for default): " DRIVE_label; LABEL_check SWAP; done
                    PROCEED="false"
                    echo; fi
                fi
                ;;
              4)
                if [[ "$HOME_partition" == "true" ]] && [[ "$SWAP_partition" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do read -rp "SWAP-partition size in GB (leave empty for default): " DRIVE_size; SIZE_check SWAP; done
                  PROCEED="false"
                  until [[ "$PROCEED" == "true" ]]; do read -rp "SWAP-partition label (leave empty for default): " DRIVE_label; LABEL_check SWAP; done
                  PROCEED="false"
                  echo
                fi
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          if [[ "$HOME_partition" == "true" ]]; then PRINT_TABLE ',' "$OUTPUT_partitions_full";
          else PRINT_TABLE ',' "$OUTPUT_partitions_without_home"; fi
        elif [[ "$1" == "LOCALS" ]]; then
          IFS=',' 
          read -ra user_choices <<< "$CONFIRM"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)
                until [[ "$PROCEED" == "true" ]]; do read -rp "TIMEZONE (leave empty for default); e.g. \"Europe/Copenhagen\": " TIMEZONE_export; TIMEZONE_check; done          
                PROCEED="false"
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do read -rp "Comma-separated languages to generate (leave empty for default); e.g. \"da_DK.UTF-8,en_GB.UTF-8\": " LANGUAGES_generate_export; LANGUAGE_check generate; done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do read -rp "Systemwide language (leave empty for default): " LANGUAGE_system_export; LANGUAGE_check system; done
                PROCEED="false"
                echo
                ;;
              3)
                until [[ "$PROCEED" == "true" ]]; do read -rp "Systemwide keymap (leave empty for default): " KEYMAP_system_export; KEYMAP_check; done   
                PROCEED="false"
                echo
                ;;
              4)
                until [[ "$PROCEED" == "true" ]]; do read -rp "Systemwide hostname (leave empty for default): " HOSTNAME_system_export; HOSTNAME_check; done 
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
                until [[ "$PROCEED" == "true" ]]; do read -rp "Password for root: " ROOT_passwd_export; USER_check password; done     
                PROCEED="false"
                export ROOT_passwd=$ROOT_passwd_export
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do read -rp "Username for personal user: " USERNAME_export; USER_check username;done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do read -rp "Password for personal user: " USER_passwd_export; USER_check password; done     
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
                if ! [[ "$BOOTLOADER_label_export" == "" ]]; then export BOOTLOADER_label=$BOOTLOADER_label_export; fi
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do read -rp "Additional packages to install (separated by comma); e.g. \"firefox,kicad\" or \"NONE\": " PACKAGES_additional_export; PACKAGES_check; done   
                PROCEED="false"
                echo
                ;;
              3)
                if [[ "$POST_script" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do read -rp "Git-repo that contains the script; e.g. \"gitlab.com/FabseGP02/artix-install-script.git\" or \"SKIP\": " POST_script_export; POST_SCRIPT_check repo; done
                  PROCEED="false"
                  if ! [[ "$POST_script_export" == "SKIP" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do read -rp "Path to script within the cloned folder; e.g. \"install_artix.sh\": " POST_script_name_export; POST_SCRIPT_check path; done
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

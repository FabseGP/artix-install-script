#!/usr/bin/bash

# DO NOT TOUCH!

  BEGINNER_DIR=$(pwd)
  MODE="$1"
  source scripts/output.sh
  source scripts/check.sh
  source scripts/variables.sh
  source scripts/choices.sh
  source scripts/menu.sh
  source scripts/functions.sh
  set -a # Force export all variables; most relevant for answerfile
  if ! [[ "$MODE" == "interactive" ]]; then
    if [[ -f "/.encrypt/answer_encrypt.txt" ]]; then openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -in /.encrypt/answer_encrypt.txt -out /.decrypt/decrypt.txt -pass file:/.nothing/nothing.txt; source /.decrypt/decrypt.txt; 
    elif [[ -f "/.nothing/answerfile_wget.txt" ]]; then source /.nothing/answerfile_wget.txt;
    else source answerfile; fi
  else
    source answerfile; fi

#----------------------------------------------------------------------------------------------------------------------------------

# Source answerfile if conditions is met

  if [[ "$INTERACTIVE_INSTALL" == "false" ]]; then
    if [[ -f "/.decrypt/decrypt.txt" ]]; then source /.decrypt/decrypt.txt;
    else source answerfile; fi
    source scripts/variables.sh
  fi

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

# Actual execution of commands

  if [[ "$INTERACTIVE_INSTALL" == "false" ]]; then
    if [[ "$DRIVE_path" == "ASK" ]]; then
      MULTISELECT_MENU "${drive_selection[@]}"
    else
      if [[ "$DRIVE_path" == *"nvme"* ]]; then
        if [[ "$HOME_partition" == "true" ]]; then
          if [[ "$SWAP_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_swap=""$DRIVE_path"p2"; export DRIVE_path_home=""$DRIVE_path"p3"; export DRIVE_path_primary=""$DRIVE_path"p4";
          else export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_home=""$DRIVE_path"p2"; export DRIVE_path_primary=""$DRIVE_path"p3"; fi
        else 
          if [[ "$SWAP_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_swap=""$DRIVE_path"p2"; export DRIVE_path_primary=""$DRIVE_path"p3";
          else export DRIVE_path_boot=""$DRIVE_path"p1"; export DRIVE_path_primary=""$DRIVE_path"p2"; fi; fi
      else
        if [[ "$HOME_partition" == "true" ]]; then
          if [[ "$SWAP_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_swap=""$DRIVE_path"2"; export DRIVE_path_home=""$DRIVE_path"3"; export DRIVE_path_primary=""$DRIVE_path"4";
          else export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_home=""$DRIVE_path"2"; export DRIVE_path_primary=""$DRIVE_path"3"; fi
        else 
          if [[ "$SWAP_partition" == "true" ]]; then export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_swap=""$DRIVE_path"2"; export DRIVE_path_primary=""$DRIVE_path"3";
          else export DRIVE_path_boot=""$DRIVE_path"1"; export DRIVE_path_primary=""$DRIVE_path"2"; fi; fi
      fi
    fi  
    SIZE_decimal=$(df -h --output=size "$DRIVE_path")
    SIZE_integer=$(awk -v v="$SIZE_decimal" 'BEGIN{printf "%d", v}')        
    ARRAY_string="$SIZE_integer"
    IFS=' '
    SIZE_array=( $ARRAY_string )
    SIZE_extracted=$(echo "${SIZE_array[1]}")
    SIZE_cleaned=$(echo "${SIZE_extracted//G}")      
  fi

  # Executing functions
  for ((function=0; function < "${#functions[@]}"; function++)); do
    if [[ "${functions[function]}" == "SCRIPT"* ]]; then
      if [[ "${functions[function]}" == "SCRIPT_02"* || "${functions[function]}" == "SCRIPT_03"* ]]; then
        if [[ "$INTERACTIVE_INSTALL" == "true" ]]; then "${functions[function]}";
        else :; fi    
      else "${functions[function]}"; fi
    fi
  done

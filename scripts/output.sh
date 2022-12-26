#!/usr/bin/bash

# Parameters

  COLUMNS=$(tput cols) 

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
  if [[ "$1" == "SPACE" ]]; then echo; printf '%0.s-' $(seq 1 "$COLUMNS"); echo;
  else printf '%0.s-' $(seq 1 "$COLUMNS"); fi
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
          if [[ "${i}" -eq "1" ]]; then table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"; fi
          table="${table}\n"
          local j=1
          for ((j=1; j<="${numberOfColumns}"; j++)); do table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"; done
          table="${table}#|\n"
          if [[ "${i}" -eq "1" ]] || [[ "${numberOfLines}" -gt "1" && "${i}" -eq "${numberOfLines}" ]]; then table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"; fi
        done
        if [[ "$(EMPTY_STRING "${table}")" = "false" ]]; then echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'; fi
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
    if ! [[ "${string}" == "" ]] && [[ "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then local -r result="$(printf "%${numberToRepeat}s")"; echo -e "${result// /${string}}"; fi
}

  EMPTY_STRING() {
    local -r string="${1}"
    if [[ "$(TRIM_STRING "${string}")" = "" ]]; then echo 'true'; return 0; fi
    echo 'false' 
    return 1
}

  TRIM_STRING() {
    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

#----------------------------------------------------------------------------------------------------------------------------------

# Messages to print

  messages=(
    "figlet -c -t -k WELCOME | lolcat -a -d 3 && echo "" && figlet -c -t -k You are about to install Artix Linux! | lolcat -a -d 2" # Intro
    "figlet -c -t -k FAREWELL - THIS TIME FOR REAL! | lolcat -a -d 3 && echo """" # Goodbye
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
    "YOU NEED TO CHOOSE ONE OF THE LISTED BOOTLOADERS! " # If none of the init is chosen
)

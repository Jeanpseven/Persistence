#!/bin/bash

# Verifica se o arquivo grub.cfg existe
if [ ! -f "/boot/grub/grub.cfg" ]; then
    echo "Arquivo grub.cfg não encontrado. Baixando..."
    
    # Baixa o arquivo de configuração de exemplo do Kali Linux
    sudo wget -O /boot/grub/grub.cfg https://gitlab.com/kalilinux/packages/grub2/-/raw/kali/master/debian/config/normal

    # Cria o arquivo de persistência
    sudo dd if=/dev/zero of=/media/$(lsblk -o MOUNTPOINT,NAME | grep '/media' | awk '{print $1}')/persistent.img bs=1M count=2048 && sudo mkfs.ext4 /media/$(lsblk -o MOUNTPOINT,NAME | grep '/media' | awk '{print $1}')/persistent.img && sudo mkdir /mnt/persistent && sudo mount /media/$(lsblk -o MOUNTPOINT,NAME | grep '/media' | awk '{print $1}')/persistent.img /mnt/persistent

    # Adiciona a opção de persistência ao arquivo de configuração
    sudo sed -i "s/linux/linux persistent persistence=LABEL=$(lsblk -o MOUNTPOINT,LABEL | grep '/media' | awk '{print $2}')/" /boot/grub/grub.cfg

    echo "Arquivo grub.cfg configurado com sucesso."
else
    echo "Arquivo grub.cfg já existe. Nenhuma ação necessária."
fi

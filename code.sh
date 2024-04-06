#!/bin/bash

# Função para configurar o tamanho do cluster e tamanho do bloco
configure_cluster_block_sizes() {
    device_path="$1"
    device_filesystem="$2"

    # Determina o tamanho do dispositivo
    device_size=$(lsblk -b -o SIZE "$device_path" | tail -n1)

    # Determina o tamanho do cluster e tamanho do bloco com base no tamanho do dispositivo
    if (( device_size < (16 * 1024 * 1024 * 1024) )); then
        cluster_size="4k"
        block_size="4k"
    elif (( device_size < (64 * 1024 * 1024 * 1024) )); then
        cluster_size="8k"
        block_size="8k"
    else
        cluster_size="16k"
        block_size="16k"
    fi

    # Configura o tamanho do cluster e tamanho do bloco no sistema de arquivos
    if [[ "$device_filesystem" == "vfat" ]]; then
        fatresize "$device_path"1 -s "$cluster_size"
    else
        tune2fs "$device_path"1 -o "$block_size"
    fi

    echo "Configuração de tamanho de cluster e tamanho de bloco concluída com sucesso."
}

# Verifica se o sistema é o Kali Linux
if ! grep -q 'Kali' /etc/os-release; then
    echo "Este script é destinado apenas ao Kali Linux."
    exit 1
fi

# Detecta dispositivos USB conectados e filtra os que contêm o Kali Live
kali_live_devices=($(lsblk -rno NAME,MODEL | grep -e 'KALI LIVE' | awk '{print "/dev/"$1}'))

if [[ ${#kali_live_devices[@]} -eq 0 ]]; then
    echo "Nenhum dispositivo USB com Kali Live foi encontrado."
    exit 1
elif [[ ${#kali_live_devices[@]} -eq 1 ]]; then
    kali_live_device="${kali_live_devices[0]}"
else
    echo "Vários dispositivos USB com Kali Live foram encontrados."
    echo -e "\nSelecione o dispositivo USB que contém o Kali Live:"
    for ((i=0; i<${#kali_live_devices[@]}; i++)); do
        echo "$((i+1)). ${kali_live_devices[i]}"
    done

    read -p $'\nEscolha uma opção: ' choice

    if [[ ! "$choice" =~ ^[0-9]+$ || "$choice" -lt 1 || "$choice" -gt ${#kali_live_devices[@]} ]]; then
        echo "Opção inválida."
        exit 1
    fi

    kali_live_device="${kali_live_devices[$((choice-1))]}"
fi

# Adiciona persistência ao Kali Live
mkdir -p /mnt/usb-persistence
mount -o remount,rw /lib/live/mount/persistence/Kali
cp -r /lib/live/mount/persistence/Kali/* /mnt/usb-persistence

# Cria o arquivo persistence.conf com "/ union"
echo "/ union" > /mnt/usb-persistence/persistence.conf
echo "Persistência adicionada com sucesso."

# Verifica se o usuário deseja configurar o tamanho do cluster e tamanho do bloco
read -p $'Deseja configurar o tamanho do cluster e tamanho do bloco? (s/n): ' configure_choice
if [[ "$configure_choice" =~ ^[Ss]$ ]]; then
    configure_cluster_block_sizes "$kali_live_device" "ext4"
fi

exit 0
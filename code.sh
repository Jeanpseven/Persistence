#!/bin/bash

# Função para configurar o tamanho do cluster e tamanho do bloco
configure_cluster_block_sizes() {
    # Identifica o sistema de arquivos e tamanho do dispositivo
    DEVICE_FILESYSTEM=$(lsblk -o FSTYPE "/dev/${USB_DEVICE}" | tail -n1)
    DEVICE_SIZE=$(lsblk -b -o SIZE "/dev/${USB_DEVICE}" | tail -n1)

    # Determina o tamanho do cluster e tamanho do bloco com base no tamanho do dispositivo
    CLUSTER_SIZE=""
    BLOCK_SIZE=""
    if [ "$DEVICE_SIZE" -lt $((16 * 1024 * 1024 * 1024)) ]; then
        CLUSTER_SIZE="4k"
        BLOCK_SIZE="4k"
    elif [ "$DEVICE_SIZE" -lt $((64 * 1024 * 1024 * 1024)) ]; then
        CLUSTER_SIZE="8k"
        BLOCK_SIZE="8k"
    else
        CLUSTER_SIZE="16k"
        BLOCK_SIZE="16k"
    fi

    # Configura o tamanho do cluster e tamanho do bloco no sistema de arquivos
    if [ "$DEVICE_FILESYSTEM" == "vfat" ]; then
        fatresize "/dev/${USB_DEVICE}1" -s "$CLUSTER_SIZE"
    else
        tune2fs "/dev/${USB_DEVICE}1" -o "$BLOCK_SIZE"
    fi

    echo "Configuração de tamanho de cluster e tamanho de bloco concluída com sucesso."
}

# Verifica se o sistema é o Kali Linux
if [ "$(grep 'Kali' /etc/os-release)" == "" ]; then
    echo "Este script é destinado apenas ao Kali Linux."
    exit 1
fi

# Função para selecionar manualmente o dispositivo USB
select_usb_device() {
    # Lista os dispositivos USB disponíveis
    echo "Dispositivos USB disponíveis:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -i "disk" | awk '$4=="" {print NR".", $1, "\t", $2}'
    echo

    # Solicita ao usuário para selecionar o dispositivo USB
    read -p "Selecione o número do dispositivo USB: " choice
    echo

    # Valida a escolha do usuário
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le $usb_device_count ]; then
        USB_DEVICE=${usb_devices[$((choice-1))]}
    else
        echo "Escolha inválida."
        select_usb_device
    fi
}

# Detecta automaticamente o dispositivo USB conectado
usb_devices=($(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -i "disk" | awk '$4=="" {print $1}'))
usb_device_count=${#usb_devices[@]}
if [ "$usb_device_count" -eq 0 ]; then
    echo "Dispositivo USB não encontrado."
    exit 1
elif [ "$usb_device_count" -eq 1 ]; then
    USB_DEVICE=${usb_devices[0]}
else
    echo "Vários dispositivos USB foram encontrados."
    echo
    echo "Selecione o dispositivo USB manualmente ou escolha a opção de execução automática:"
    echo "1. Selecionar dispositivo USB manualmente"
    echo "2. Executar todo o processo automaticamente"
    echo

    # Solicita ao usuário para selecionar uma opção
    read -p "Escolha uma opção: " choice
    echo

    case $choice in
        1)
            select_usb_device
            ;;
        2)
            USB_DEVICE=${usb_devices[0]}
            ;;
        *)
            echo "Opção inválida."
            exit 1
            ;;
    esac
fi

# Verifica se o dispositivo USB possui uma partição montada
if grep -qs "/dev/${USB_DEVICE}" /proc/mounts; then
    echo "O dispositivo USB está montado. Desmontando..."
    umount "/dev/${USB_DEVICE}"* 2>/dev/null
fi

# Desmonta qualquer partição existente no dispositivo USB
umount "/dev/${USB_DEVICE}"* 2>/dev/null

# Determina o tipo de partição mais recomendado para o pendrive
PARTITION_TYPE=""
USB_SIZE=$(lsblk -b -o SIZE "/dev/${USB_DEVICE}" | tail -n1)
if [ "$USB_SIZE" -lt 2147483648 ]; then
    PARTITION_TYPE="fat32"
else
    PARTITION_TYPE="ext4"
fi

# Cria uma partição para persistência
parted -s "/dev/${USB_DEVICE}" mklabel msdos mkpart primary $PARTITION_TYPE 1M -1s set 1 boot on

# Formata a partição com o tipo apropriado
if [ "$PARTITION_TYPE" == "fat32" ]; then
    mkfs.vfat "/dev/${USB_DEVICE}1"
else
    mkfs.ext4 "/dev/${USB_DEVICE}1"
fi

# Monta a partição persistente
PERSISTENT_MOUNT_POINT="/mnt/usb-persistent"
mkdir -p "$PERSISTENT_MOUNT_POINT"
mount "/dev/${USB_DEVICE}1" "$PERSISTENT_MOUNT_POINT"

# Configura o arquivo /etc/fstab para montar a partição persistente na inicialização
echo "/dev/${USB_DEVICE}1    $PERSISTENT_MOUNT_POINT    $PARTITION_TYPE    defaults    0    0" >> /etc/fstab

echo "Partição persistente configurada com sucesso."

# Verifica se o usuário deseja configurar o tamanho do cluster e tamanho do bloco
read -p "Deseja configurar o tamanho do cluster e tamanho do bloco? (s/n): " configure_choice
echo

if [ "$configure_choice" == "s" ] || [ "$configure_choice" == "S" ]; then
    configure_cluster_block_sizes
fi

exit 0

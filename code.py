import subprocess

# Função para configurar o tamanho do cluster e tamanho do bloco
def configure_cluster_block_sizes(device_path, device_filesystem):
    # Determina o tamanho do dispositivo
    device_size = int(subprocess.check_output(['lsblk', '-b', '-o', 'SIZE', device_path]).decode().splitlines()[-1])

    # Determina o tamanho do cluster e tamanho do bloco com base no tamanho do dispositivo
    cluster_size = ""
    block_size = ""
    if device_size < (16 * 1024 * 1024 * 1024):
        cluster_size = "4k"
        block_size = "4k"
    elif device_size < (64 * 1024 * 1024 * 1024):
        cluster_size = "8k"
        block_size = "8k"
    else:
        cluster_size = "16k"
        block_size = "16k"

    # Configura o tamanho do cluster e tamanho do bloco no sistema de arquivos
    if device_filesystem == "vfat":
        subprocess.run(['fatresize', device_path + "1", "-s", cluster_size])
    else:
        subprocess.run(['tune2fs', device_path + "1", "-o", block_size])

    print("Configuração de tamanho de cluster e tamanho de bloco concluída com sucesso.")

# Verifica se o sistema é o Kali Linux
with open('/etc/os-release', 'r') as f:
    if 'Kali' not in f.read():
        print("Este script é destinado apenas ao Kali Linux.")
        exit(1)

# Detecta automaticamente o dispositivo USB conectado
devices = subprocess.check_output(['lsblk', '-o', 'NAME,SIZE,TYPE,MOUNTPOINT']).decode().splitlines()
usb_devices = [line.split()[0] for line in devices if 'disk' in line and len(line.split()) < 4]
usb_device_count = len(usb_devices)

if usb_device_count == 0:
    print("Dispositivo USB não encontrado.")
    exit(1)
elif usb_device_count == 1:
    usb_device = usb_devices[0]
else:
    print("Vários dispositivos USB foram encontrados.")
    print("\nSelecione o dispositivo USB manualmente ou escolha a opção de execução automática:")
    for i, device in enumerate(usb_devices):
        print(f"{i + 1}. {device}")

    choice = input("\nEscolha uma opção: ")
    try:
        choice = int(choice)
        if choice < 1 or choice > usb_device_count:
            raise ValueError
    except ValueError:
        print("Opção inválida.")
        exit(1)

    usb_device = usb_devices[choice - 1]

# Verifica se o dispositivo USB possui uma partição montada
if any(usb_device in line for line in devices if usb_device in line and len(line.split()) == 4):
    print("O dispositivo USB está montado. Desmontando...")
    subprocess.run(['umount', f"/dev/{usb_device}*"], stderr=subprocess.DEVNULL)

# Desmonta qualquer partição existente no dispositivo USB
subprocess.run(['umount', f"/dev/{usb_device}*"], stderr=subprocess.DEVNULL)

# Determina o tipo de partição mais recomendado para o pendrive
partition_type = ""
usb_size = int(subprocess.check_output(['lsblk', '-b', '-o', 'SIZE', f"/dev/{usb_device}"]).decode().splitlines()[-1])

if usb_size < 2147483648:
    partition_type = "fat32"
else:
    partition_type = "ext4"

# Cria uma partição para persistência
subprocess.run(['parted', '-s', f"/dev/{usb_device}", 'mklabel', 'msdos', 'mkpart', 'primary', partition_type, '1M', '-1s', 'set', '1', 'boot', 'on'])

# Formata a partição com o tipo apropriado
if partition_type == "fat32":
    subprocess.run(['mkfs.vfat', f"/dev/{usb_device}1"])
else:
    subprocess.run(['mkfs.ext4', f"/dev/{usb_device}1"])

# Monta a partição persistente
persistent_mount_point = "/mnt/usb-persistent"
subprocess.run(['mkdir', '-p', persistent_mount_point])
subprocess.run(['mount', f"/dev/{usb_device}1", persistent_mount_point])

# Configura o arquivo /etc/fstab para montar a partição persistente na inicialização
with open('/etc/fstab', 'a') as f:
    f.write(f"/dev/{usb_device}1    {persistent_mount_point}    {partition_type}    defaults    0    0\n")

print("Partição persistente configurada com sucesso.")

# Verifica se o usuário deseja configurar o tamanho do cluster e tamanho do bloco
configure_choice = input("Deseja configurar o tamanho do cluster e tamanho do bloco? (s/n): ")
if configure_choice.lower() == "s":
    configure_cluster_block_sizes(f"/dev/{usb_device}", partition_type)

exit(0)

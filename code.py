import subprocess
import pyudev

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

# Detecta dispositivos USB conectados
context = pyudev.Context()
usb_devices = [device for device in context.list_devices(subsystem='block', DEVTYPE='disk') if 'ID_MODEL' in device]

# Filtra os dispositivos que contêm o Kali Live
kali_live_devices = []
for device in usb_devices:
    partitions = [part for part in device.children if part.get('ID_FS_LABEL') == 'KALI LIVE']
    if partitions:
        kali_live_devices.append(device.device_node)

if not kali_live_devices:
    print("Nenhum dispositivo USB com Kali Live foi encontrado.")
    exit(1)
elif len(kali_live_devices) == 1:
    kali_live_device = kali_live_devices[0]
else:
    print("Vários dispositivos USB com Kali Live foram encontrados.")
    print("\nSelecione o dispositivo USB que contém o Kali Live:")
    for i, device in enumerate(kali_live_devices):
        print(f"{i + 1}. {device}")

    choice = input("\nEscolha uma opção: ")
    try:
        choice = int(choice)
        if choice < 1 or choice > len(kali_live_devices):
            raise ValueError
    except ValueError:
        print("Opção inválida.")
        exit(1)

    kali_live_device = kali_live_devices[choice - 1]

# Adiciona persistência ao Kali Live
subprocess.run(['mkdir', '-p', '/mnt/usb-persistence'])
subprocess.run(['mount', '-o', 'remount,rw', '/lib/live/mount/persistence/Kali'])
subprocess.run(['cp', '-r', '/lib/live/mount/persistence/Kali/*', '/mnt/usb-persistence'])

# Cria o arquivo persistence.conf com "/ union"
with open('/mnt/usb-persistence/persistence.conf', 'w') as f:
    f.write("/ union\n")

print("Persistência adicionada com sucesso.")

# Verifica se o usuário deseja configurar o tamanho do cluster e tamanho do bloco
configure_choice = input("Deseja configurar o tamanho do cluster e tamanho do bloco? (s/n): ")
if configure_choice.lower() == "s":
    configure_cluster_block_sizes(kali_live_device, "ext4")

exit(0)
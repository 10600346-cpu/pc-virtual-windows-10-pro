#!/usr/bin/env bash
# name: scripts/create_win10_vbox.sh
# Crea una VM Windows 10 Pro en VirtualBox con: 8 GB RAM, 64 GB disco, 4 CPUs.
# Uso: editar las variables ISO_PATH y VM_DIR abajo y ejecutar:
#   chmod +x scripts/create_win10_vbox.sh
#   ./scripts/create_win10_vbox.sh
set -euo pipefail

# --- Configuración: edita según tu entorno ---
VM_NAME="Win10-Pro"
ISO_PATH="/ruta/a/Win10_Pro_x64.iso"   # <- cambia a la ruta real del ISO
VM_DIR="$HOME/VirtualBox VMs/$VM_NAME"
VDI_PATH="$VM_DIR/${VM_NAME}.vdi"
RAM_MB=8192
CPUS=4
VRAM_MB=128
DISK_SIZE_MB=$((64 * 1024))   # 64 GB en MB

# Comprueba que VBoxManage está disponible
if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "ERROR: VBoxManage no encontrado. Instala VirtualBox y vuelve a intentarlo." >&2
  exit 1
fi

echo "Creando carpeta de VM: $VM_DIR"
mkdir -p "$VM_DIR"

echo "1) Crear la VM y registrar"
VBoxManage createvm --name "$VM_NAME" --ostype "Windows10_64" --register || true

echo "2) Configurar CPU y memoria"
VBoxManage modifyvm "$VM_NAME" --cpus $CPUS --memory $RAM_MB --vram $VRAM_MB --ioapic on --pae on --nic1 nat

echo "3) Crear disco virtual VDI $VDI_PATH (${DISK_SIZE_MB}MB)"
VBoxManage createmedium disk --filename "$VDI_PATH" --size $DISK_SIZE_MB --format VDI

echo "4) Añadir controlador SATA y adjuntar el disco"
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci || true
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VDI_PATH"

echo "5) Añadir controlador IDE y montar ISO de instalación"
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide || true
VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"

echo "6) Ajustar orden de arranque (DVD -> Disco)"
VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk

# Opcional: habilitar nested virtualization (útil para WSL2 o para pasar CPU features)
read -p "¿Deseas habilitar virtualización anidada (nested) si el host la soporta? [y/N]: " enable_nested || true
if [[ "$enable_nested" =~ ^[Yy] ]]; then
  VBoxManage modifyvm "$VM_NAME" --nested-hw-virt on || true
  echo "Virtualización anidada activada (si el host la soporta)."
fi

echo "Lista de configuración final para $VM_NAME:"
VBoxManage showvminfo "$VM_NAME" --details

echo "Hecho. Inicia la VM desde VirtualBox GUI o con:
  VBoxManage startvm \"$VM_NAME\" --type gui
"

echo "Notas importantes:
- No se puede 'fijar' la frecuencia física del CPU (por ejemplo 3.10 GHz) desde la VM; puedes asignar 4 vCPUs pero la velocidad depende del hardware host.
- Asegúrate de usar un ISO oficial de Microsoft y una clave válida para activar Windows 10 Pro.
- Para mejor rendimiento en Windows, instala Guest Additions tras la instalación.
"

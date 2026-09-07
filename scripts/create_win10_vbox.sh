#!/usr/bin/env bash
# name: scripts/create_win10_vbox.sh
# Crea una VM Windows 10 Pro en VirtualBox con: 8 GB RAM, 64 GB disco, 4 CPUs.
# Soporta modo "online": habilita VRDE (RDP) y arranca la VM en background.
# Uso:
#  - Edita ISO_PATH si es necesario.
#  - Opcionalmente controla el comportamiento por variables de entorno:
#      VRDE_ENABLE (true|false) - si se debe habilitar VRDE/RDP (por defecto: true)
#      VRDE_PORT (número)       - puerto RDP a usar (por defecto: 5000)
#      AUTO_START (true|false)  - si debe arrancar la VM automáticamente en modo headless (por defecto: true)
#  - Ejecuta:
#      chmod +x scripts/create_win10_vbox.sh
#      VRDE_ENABLE=true VRDE_PORT=5000 AUTO_START=true ./scripts/create_win10_vbox.sh
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

# Comportamiento "online" (puedes sobreescribir con variables de entorno)
VRDE_ENABLE=${VRDE_ENABLE:-true}
VRDE_PORT=${VRDE_PORT:-5000}
AUTO_START=${AUTO_START:-true}

# Normalize boolean helper
is_true() {
  case "${1,,}" in
    1|true|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

# Comprueba que VBoxManage está disponible
if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "ERROR: VBoxManage no encontrado. Instala VirtualBox y vuelve a intentarlo." >&2
  exit 1
fi

echo "Creando carpeta de VM: $VM_DIR"
mkdir -p "$VM_DIR"

echo "1) Crear la VM y registrar (si no existe)"
VBoxManage createvm --name "$VM_NAME" --ostype "Windows10_64" --register || true

echo "2) Configurar CPU y memoria"
VBoxManage modifyvm "$VM_NAME" --cpus $CPUS --memory $RAM_MB --vram $VRAM_MB --ioapic on --pae on --nic1 nat

# Crear disco sólo si no existe
if [ ! -f "$VDI_PATH" ]; then
  echo "3) Crear disco virtual VDI $VDI_PATH (${DISK_SIZE_MB}MB)"
  VBoxManage createmedium disk --filename "$VDI_PATH" --size $DISK_SIZE_MB --format VDI
else
  echo "3) El disco $VDI_PATH ya existe, se reutilizará."
fi

echo "4) Añadir controlador SATA y adjuntar el disco"
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci || true
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VDI_PATH" || true

echo "5) Añadir controlador IDE y montar ISO de instalación"
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide || true
VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH" || true

echo "6) Ajustar orden de arranque (DVD -> Disco)"
VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk || true

# Habilitar VRDE (RDP) si se desea
if is_true "$VRDE_ENABLE"; then
  echo "Habilitando VRDE (RDP) en el puerto $VRDE_PORT"
  VBoxManage modifyvm "$VM_NAME" --vrde on --vrdeport $VRDE_PORT || true
  # Asegurarse de que NAT permite conexión desde host (por defecto VRDE escucha en host)
else
  echo "VRDE deshabilitado por configuración (VRDE_ENABLE=$VRDE_ENABLE)"
  VBoxManage modifyvm "$VM_NAME" --vrde off || true
fi

# Mostrar resumen
echo "Lista de configuración final para $VM_NAME:"
VBoxManage showvminfo "$VM_NAME" --details || true

# Arrancar automáticamente en modo headless si AUTO_START=true
if is_true "$AUTO_START"; then
  if is_true "$VRDE_ENABLE"; then
    echo "Iniciando VM en modo headless (VRDE activo en puerto $VRDE_PORT)..."
  else
    echo "Iniciando VM en modo headless..."
  fi
  VBoxManage startvm "$VM_NAME" --type headless
  echo "VM iniciada. Conéctate por RDP a localhost:$VRDE_PORT (o al host donde corre VirtualBox)."
else
  echo "AUTO_START deshabilitado (AUTO_START=$AUTO_START). Para iniciar manualmente:
  - GUI: abre VirtualBox y ejecuta 'Win10-Pro'
  - CLI: VBoxManage startvm \"$VM_NAME\" --type headless
  Para habilitar VRDE manualmente: VBoxManage modifyvm \"$VM_NAME\" --vrde on --vrdeport $VRDE_PORT"
fi

echo "Notas importantes:
- La VM expuesta por VRDE estará accesible en el host que ejecuta VirtualBox; si quieres acceso remoto desde otra máquina, abre/encamina el puerto $VRDE_PORT en el firewall/NAT del host.
- No se puede 'fijar' la frecuencia física del CPU (por ejemplo 3.10 GHz) desde la VM; puedes asignar 4 vCPUs pero la velocidad depende del hardware host.
- Asegúrate de usar un ISO oficial de Microsoft y una clave válida para activar Windows 10 Pro.
- Para mejor rendimiento en Windows, instala Guest Additions tras la instalación.
"

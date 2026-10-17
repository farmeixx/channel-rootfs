# Motorola Moto G7 Play (channel) — guia rápido

Comandos para usar o Linux no aparelho. Execute os comandos de administração como `root`.

## SSH por USB

Conecte o cabo USB ao computador com suporte a RNDIS:

```sh
ssh root@172.16.42.1
```

O SSH está disponível pela rede USB, não pelo Wi-Fi. Use um computador/cabo confiável.

## Wi-Fi

```sh
nmcli device status
nmcli device wifi list
nmcli --ask device wifi connect "SSID" ifname wlan0
```

Substitua `SSID` pelo nome da rede. A senha é solicitada interativamente.

## Corrigir data e hora

Ajuste para a **hora UTC correta**:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

## Expandir o ext4 na userdata

Identifique **a partição real** que contém `/`, sem adivinhar o dispositivo:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
findmnt -n -o SOURCE /
grep ' / ' /proc/mounts
command -v resize2fs
```

Se faltar `resize2fs`: no Alpine, `apk add e2fsprogs-extra`; no Debian/Ubuntu, `apt install e2fsprogs`.

**Somente após confirmar a partição raiz correta**, substitua o caminho de exemplo:

```sh
resize2fs /dev/PARTICAO_RAIZ
df -h /
```

Isso expande o **sistema de arquivos** até o tamanho já disponível na partição; não aumenta a partição. `/dev/root` pode ser apenas um apelido. Não use `resize2fs -M` na raiz montada e nunca escolha partições como `modem`, `vendor` ou `modemst`.

## Diagnóstico USB

**Alpine (OpenRC):**

```sh
rc-service usb-gadget status
rc-service usb-sshd status
rc-service dnsmasq status
ip -br addr show usb0
```

**Debian/Ubuntu (systemd):**

```sh
systemctl status usb-gadget.service usb-dhcp.service ssh.service
ip -br addr show usb0
```

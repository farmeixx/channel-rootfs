# Moto G7 Play (channel) — guia rápido

Este branch **help** é somente para consulta. Para compilar, use a branch `main` (build automática) ou `manual-deps` (dependências do host instaladas por você).

## Arquivos de build

No **Actions**, o workflow **Build mainline kernel** fornece o kernel, DTB, boot image e módulos correspondentes. Os rootfs **Alpine**, **Debian** e **Ubuntu** usam o checkpoint desse kernel — não recompilam outro kernel.

| Distribuição | Imagem ext4 comprimida |
| --- | --- |
| Alpine | `alpine-channel-rootfs.ext4.zst` |
| Debian | `debian-channel-rootfs.ext4.zst` |
| Ubuntu | `ubuntu-channel-rootfs.ext4.zst` |

Use sempre os módulos correspondentes ao kernel do mesmo checkpoint.

## Conectar por SSH (USB)

Com o Channel ligado e o USB Gadget ativo:

```sh
ssh root@172.16.42.1
```

## Wi-Fi no Channel

Listar as redes e conectar sem expor a senha no comando:

```sh
nmcli device wifi list
nmcli --ask device wifi connect "SSID" ifname wlan0
```

Troque `SSID` pelo nome da sua rede.

## Corrigir data e hora

Quando o relógio estiver errado, ajuste **a hora UTC verdadeira**:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

Substitua `YYYY-MM-DD HH:MM:SS` pela data e hora UTC atuais.

## Expandir o ext4 (resize2fs)

Execute no Channel **como root**. Primeiro descubra qual partição ext4 está montada em `/`:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
grep ' / ' /proc/mounts
command -v resize2fs
```

Se `resize2fs` não estiver instalado: use o pacote `e2fsprogs-extra` no Alpine ou `e2fsprogs` no Debian/Ubuntu.

**Somente depois de identificar com certeza a partição raiz**, substitua `/dev/ROOT_PARTITION` pelo dispositivo correto e execute:

```sh
resize2fs /dev/ROOT_PARTITION
df -h /
```

> **Atenção:** `resize2fs` expande o sistema de arquivos até o tamanho **já disponível na partição**; não redimensiona a partição em si. Não execute na partição errada, em `modem`, `vendor` ou `modemst`. Não adivinhe o caminho.

## Referência

- Formato do rootfs: **ext4** (imagem bruta compactada com zstd).
- UUID ext4 usado pelo projeto: `89530000-6320-4000-8000-000000000001`.
- Projeto de builds: [branch main](https://github.com/farmeixx/channel-rootfs/tree/main).

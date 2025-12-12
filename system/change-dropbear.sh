#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Sila jalankan sebagai root (sudo)." >&2
  exit 1
fi

# Pasang jq jika belum ada, sembunyikan log output
if ! command -v jq >/dev/null 2>&1; then
  echo "Memasang jq secara automatik..."
  apt-get update -y > /dev/null 2>&1
  apt-get install -y jq > /dev/null 2>&1 || { echo "Gagal pasang jq, keluar."; exit 1; }
fi

# Buang dropbear lama di /usr/local/sbin agar tidak diguna
if [[ -f /usr/local/sbin/dropbear ]]; then
  echo "Membuang /usr/local/sbin/dropbear lama..."
  rm -f /usr/local/sbin/dropbear || echo "Gagal buang /usr/local/sbin/dropbear"
fi

# Buat symlink ke /usr/sbin/dropbear kalau belum ada supaya perintah dropbear -V tidak error
if [[ ! -f /usr/local/sbin/dropbear && -x /usr/sbin/dropbear ]]; then
  echo "Membuat symlink /usr/local/sbin/dropbear -> /usr/sbin/dropbear"
  ln -s /usr/sbin/dropbear /usr/local/sbin/dropbear || echo "Gagal buat symlink di /usr/local/sbin/dropbear"
fi

detect_latest_version() {
  local api_url="https://api.github.com/repos/mkj/dropbear/releases/latest"
  local latest_ver=""
  latest_ver="$(curl -fsSL "$api_url" | jq -r '.tag_name' | sed -E 's/^DROPBEAR_//')"
  if [[ "$latest_ver" =~ ^[0-9]{4}\.[0-9]{1,2}$ ]]; then
    echo "$latest_ver"
    return 0
  else
    return 1
  fi
}

echo "Mencuba kesan versi terbaru dari upstream..."
LATEST_VER="$(detect_latest_version || true)"
if [[ -n "${LATEST_VER:-}" ]]; then
  echo "Versi terbaru dikesan: ${LATEST_VER}"
else
  echo "Gagal mengesan versi terbaru (Latest will show as unknown)."
fi

while true; do
  echo
  echo "=== Change Dropbear Version ==="
  if [[ -n "${LATEST_VER:-}" ]]; then
    latest_label="Latest (${LATEST_VER})"
  else
    latest_label="Latest (unknown)"
  fi

  PS3="Pilih versi (masukkan nombor): "
  options=("2019.78" "2020.81" "2022.82" "${latest_label}" "Cancel")
  select opt in "${options[@]}"; do
    case "$opt" in
      "${latest_label}")
        if [[ -n "${LATEST_VER:-}" ]]; then
          VER="${LATEST_VER}"
          break
        else
          echo "Versi terbaru tidak dapat dikesan; sila pilih versi manual."
          break
        fi
        ;;
      "2019.78"|"2020.81"|"2022.82")
        VER="$opt"
        break
        ;;
      "Cancel")
        echo "Dibatalkan oleh pengguna."
        exit 0
        ;;
      *)
        echo "Pilihan tidak sah; cuba lagi."
        ;;
    esac
  done

  if [[ -z "${VER:-}" ]]; then
    continue
  fi

  read -rp "Letakkan pakej pada hold selepas pemasangan apt-managed? (y/N): " yn
  if [[ "${yn,,}" =~ ^(y|yes)$ ]]; then HOLD_AFTER="1"; else HOLD_AFTER="0"; fi

  read -rp "Path fail checksums (sha256sum format) untuk verify (biar kosong untuk lompat): " checks
  if [[ -n "${checks:-}" ]]; then CHECKSUMS_FILE="$checks"; else CHECKSUMS_FILE=""; fi

  read -rp "Simpan temporary files selepas selesai? (y/N): " kt
  if [[ "${kt,,}" =~ ^(y|yes)$ ]]; then KEEP_TMP="1"; else KEEP_TMP="0"; fi

  echo
  echo "Pengesahan akhir:"
  echo "  Versi yang dipilih: ${VER}"
  echo "  Hold package (apt): ${HOLD_AFTER}"
  echo "  Checksums file: ${CHECKSUMS_FILE:-<none>}"
  echo "  Keep tmp files: ${KEEP_TMP}"
  read -rp "Teruskan pemasangan? (y/N): " ok
  if [[ ! "${ok,,}" =~ ^(y|yes)$ ]]; then
    echo "Batal; kembali ke menu."
    VER=""
    continue
  fi

  break
done

BACKUP_DIR="/root/dropbear-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Membuat backup /etc/dropbear (jika ada) -> $BACKUP_DIR"
cp -a /etc/dropbear "$BACKUP_DIR/" 2>/dev/null || true
cp -a /etc/default/dropbear "$BACKUP_DIR/" 2>/dev/null || true
dpkg -l | egrep 'dropbear|dropbear-bin' > "$BACKUP_DIR/installed-packages.txt" || true

stop_dropbear_if_running() {
  echo "Menghentikan perkhidmatan dropbear jika sedang berjalan..."
  if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    if systemctl list-units --full -all | grep -q '[d]ropbear'; then
      systemctl stop dropbear || true
    fi
  else
    service dropbear stop || true
  fi
}

find_dropbear_binary() {
  local cands=(/usr/sbin/dropbear /sbin/dropbear /usr/bin/dropbear)
  for p in "${cands[@]}"; do
    if [[ -x "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  echo "/usr/sbin/dropbear"
  return 0
}

read_port_and_extra_from_default() {
  local port="22"
  local extra=""
  if [[ -f /etc/default/dropbear ]]; then
    if grep -q '^DROPBEAR_PORT=' /etc/default/dropbear 2>/dev/null; then
      port="$(sed -nE "s/^DROPBEAR_PORT=[\"']?([0-9]+)[\"']?.*/\1/p" /etc/default/dropbear | head -n1 || true)"
      if [[ -z "$port" ]]; then port="22"; fi
    fi
    if grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear 2>/dev/null; then
      extra="$(sed -nE "s/^DROPBEAR_EXTRA_ARGS=[\"']?(.*)[\"']?.*/\1/p" /etc/default/dropbear | head -n1 || true)"
    fi
  fi
  echo "${port}:::${extra}"
}

restart_dropbear_service() {
  echo
  echo "Mencuba restart/start perkhidmatan dropbear..."
  if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    systemctl daemon-reload || true
    if systemctl list-unit-files | grep -q '^dropbear.service'; then
      if systemctl restart dropbear; then
        echo "systemctl: dropbear restarted."
      else
        echo "systemctl: restart gagal, cuba start." >&2
        systemctl start dropbear || true
      fi
    else
      if service dropbear restart 2>/dev/null; then
        echo "service: dropbear restarted."
      else
        service dropbear start || true
        echo "service: restart/start attempted."
      fi
    fi
    if systemctl is-active --quiet dropbear; then
      echo "Status: dropbear is active (running)."
    else
      echo "Status: dropbear is NOT active (check logs)." >&2
    fi
  else
    if service dropbear restart 2>/dev/null; then
      echo "service: dropbear restarted."
    else
      service dropbear start 2>/dev/null || true
      echo "service: restart/start attempted."
    fi
  fi
  echo
}

fix_statoverride_for_dropbear() {
  echo "Membaiki dpkg-statoverride (jika wujud) untuk Dropbear..."
  if ! command -v dpkg-statoverride >/dev/null 2>&1; then
    echo "dpkg-statoverride tidak ditemui; langkau."
    return 0
  fi
  if ! dpkg-statoverride --list >/dev/null 2>&1; then
    echo "AMARAN: Tidak dapat membaca pangkalan data statoverride."
    echo "Sila pertimbang pulih daripada sandaran di /var/backups/ (cth: dpkg.statoverride.0)."
    return 0
  fi
  local paths=(
    "/usr/sbin/dropbear"
    "/usr/bin/dbclient"
    "/usr/bin/dropbearkey"
    "/usr/bin/dropbearconvert"
    "/usr/bin/scp"
    "/etc/dropbear"
  )
  local listed=""
  listed="$(dpkg-statoverride --list 2>/dev/null || true)"
  if [[ -n "$listed" ]]; then
    local p
    for p in "${paths[@]}"; do
      if echo "$listed" | awk '{print $4}' | grep -Fxq "$p"; then
        echo "Membuang override: $p"
        dpkg-statoverride --remove "$p" || true
      fi
    done
  fi
  echo "Selesai pembersihan statoverride."
  return 0
}

success_exit() {
  local msg="$1"
  echo
  echo "$msg"
  local readpe
  readpe="$(read_port_and_extra_from_default)"
  local port="${readpe%%:::*}"
  local extra_args="${readpe#*:::}"
  local binpath
  binpath="$(find_dropbear_binary)"
  if systemctl list-unit-files | grep -q '^dropbear.service'; then
    echo "Systemd unit detected: installer will NOT create or modify a drop-in file. Binary: ${binpath} Port: ${port}."
  else
    if [[ ! -f /etc/systemd/system/dropbear.service ]]; then
      echo "No systemd unit found; creating minimal /etc/systemd/system/dropbear.service"
      cat > /etc/systemd/system/dropbear.service <<'UNIT_EOF'
[Unit]
Description=Dropbear SSH server (installed by installer)
After=network.target
[Service]
Type=forking
ExecStart=/usr/sbin/dropbear -F -p 22 -P /var/run/dropbear.pid
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT_EOF
      systemctl daemon-reload || true
      systemctl enable --now dropbear || true
    fi
  fi
  fix_statoverride_for_dropbear
  restart_dropbear_service
  if [[ "${KEEP_TMP:-0}" == "0" && -n "${TMPDIR:-}" ]]; then
    rm -rf "${TMPDIR}" || true
  fi
  exit 0
}

download_try() {
  local fname="$1"; shift
  local bases=( "$@" )
  for base in "${bases[@]}"; do
    base="${base%/}"
    url="${base}/${fname}"
    echo "Mencuba: $url"
    if command -v wget >/dev/null 2>&1; then
      if wget -q --timeout=20 --tries=2 -O "$fname" "$url"; then echo "Muat turun: $fname"; return 0; fi
    elif command -v curl >/dev/null 2>&1; then
      if curl -sSL --max-time 20 -o "$fname" "$url"; then echo "Muat turun: $fname"; return 0; fi
    else
      echo "Perlu wget atau curl untuk muat turun." >&2
      return 2
    fi
  done
  return 1
}

verify_checksums_for_local_files() {
  local checks="$1"
  if [[ -z "${checks:-}" ]]; then return 0; fi
  if [[ ! -f "$checks" ]]; then echo "Fail checksums tidak ditemui: $checks" >&2; return 4; fi
  echo "Memeriksa checksums menggunakan $checks ..."
  : > sha256check.txt
  while read -r sum fname; do
    if [[ -f "${fname:-}" ]]; then echo "$sum  $fname" >> sha256check.txt; fi
  done < <(awk '{print $1" "$2}' "$checks")
  if [[ -s sha256check.txt ]]; then
    if ! sha256sum -c sha256check.txt; then echo "Checksum failed" >&2; return 5; fi
    echo "Checksums OK."
  else
    echo "Tiada fail untuk diverify berdasarkan input checksums."
  fi
  return 0
}

check_versions_post_install() {
  local used_deb_path="${1:-}"
  local wantver="${2:-}"
  echo "==== Pemeriksaan versi ===="
  local ok="0"
  if [[ "${used_deb_path:-}" == "yes" ]]; then
    for pkg in dropbear dropbear-bin dropbear-initramfs dropbear-run; do
      if dpkg -s "$pkg" >/dev/null 2>&1; then dpkg-query -W -f='${Package} ${Version}\n' "$pkg" || true; else echo "Package $pkg: TIDAK TERPASANG (apt)"; fi
    done
  else
    echo "Bukan pemasangan apt-managed (mungkin dari source)."
  fi
  echo
  echo "Memeriksa output versi binary di lokasi biasa:"
  local BINPATHS=(/usr/sbin/dropbear /sbin/dropbear /usr/bin/dropbear)
  for b in "${BINPATHS[@]}"; do
    if [[ -x "${b}" ]]; then
      echo "Binary: $b"
      out="$("${b}" -V 2>&1 || true)"
      echo "$out"
      if [[ -n "${wantver:-}" ]] && echo "$out" | grep -q "${wantver}"; then
        echo "-> Binary di $b memaparkan versi ${wantver} (OK)."
        ok="1"
      else
        echo "-> Binary di $b TIDAK memaparkan ${wantver}."
      fi
      echo "----"
    fi
  done
  if [[ "${used_deb_path:-}" == "yes" ]]; then
    if dpkg-query -W -f='${Package} ${Version}\n' dropbear 2>/dev/null | grep -q "${wantver}" \
       || dpkg-query -W -f='${Package} ${Version}\n' dropbear-bin 2>/dev/null | grep -q "${wantver}"; then
      echo "Versi pakej mengandungi ${wantver} -> INSTALL VERIFIED (apt-managed)."
      return 0
    fi
  fi
  if [[ "${ok}" == "1" ]]; then
    echo "Pengesahan binary: ${wantver} ditemui -> VERIFIED."
    return 0
  fi
  echo "AMARAN: Gagal sahkan bahawa ${wantver} dipasang. Sila semak output di atas."
  return 10
}

install_debs_and_fix_deps() {
  echo "Memasang .deb di direktori kerja..."
  dpkg -i ./*.deb || true
  apt-get update -y > /dev/null 2>&1
  apt-get -f install -y > /dev/null 2>&1
}

build_from_source_generic() {
  local tag="$1"
  echo "Membangun dari source untuk ${tag}..."
  apt-get update -y > /dev/null 2>&1
  apt-get install -y build-essential autoconf automake libtool pkg-config libssl-dev zlib1g-dev wget curl jq > /dev/null 2>&1 || true
  local tarfile="dropbear-${tag}.tar.bz2"
  local urls=( "https://matt.ucc.asn.au/dropbear/releases/${tarfile}" "https://mirror.dropbear.nl/mirror/${tarfile}" "https://download.savannah.gnu.org/releases/${tarfile}" )
  local found="0"
  for u in "${urls[@]}"; do
    if download_try "$tarfile" "${u%/*}"; then found="1"; break; fi
  done
  if [[ "${found}" != "1" ]]; then
    echo "ERROR: Gagal muat turun tarball ${tarfile}. Sila dapatkan secara manual dan jalankan semula." >&2
    return 6
  fi
  tar xf "$tarfile"
  cd "dropbear-${tag}" || { echo "Tidak dapat masuk direktori source"; return 7; }
  ./configure --prefix=/usr --sysconfdir=/etc || true
  make -j"$(nproc)" || true
  make install || true
  if [[ -f /etc/systemd/system/dropbear.service ]]; then
    echo "Notis: /etc/systemd/system/dropbear.service wujud. Skrip TIDAK akan menulis atau menimpa fail ini."
  fi
  return 0
}

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"
echo "Bekerja di: $TMPDIR"
stop_dropbear_if_running

case "${VER}" in
  2019.78)
    TARGET_TAG="2019.78"
    ARCH="amd64"
    DEB_FILES=( "dropbear-bin_${TARGET_TAG}-1_${ARCH}.deb" "dropbear-bin_${TARGET_TAG}_${ARCH}.deb" "dropbear_${TARGET_TAG}-1_all.deb" "dropbear_${TARGET_TAG}_all.deb" )
    MIRRORS=( "https://old-releases.ubuntu.com/ubuntu/pool/universe/d/dropbear" "https://ftp.debian.org/debian/pool/main/d/dropbear" "https://deb.debian.org/debian/pool/main/d/dropbear" "https://snapshot.debian.org/archive/debian/pool/main/d/dropbear" )
    ;;

  2020.81)
    TARGET_TAG="2020.81"
    ARCH="amd64"
    DEB_FILES=( "dropbear-bin_${TARGET_TAG}-3+deb11u3_${ARCH}.deb" "dropbear_${TARGET_TAG}-3+deb11u3_all.deb" "dropbear-initramfs_${TARGET_TAG}-3+deb11u3_all.deb" "dropbear-run_${TARGET_TAG}-3+deb11u3_all.deb" )
    MIRRORS=( "https://deb.debian.org/debian-security/pool/updates/main/d/dropbear" "https://ftp.debian.org/debian/pool/main/d/dropbear" )
    ;;

  2022.82)
    TARGET_TAG="2022.82"
    ARCH="amd64"
    DEB_FILES=( "dropbear-bin_${TARGET_TAG}-4_${ARCH}.deb" "dropbear_${TARGET_TAG}-4_all.deb" "dropbear-initramfs_${TARGET_TAG}-4_all.deb" "dropbear-run_${TARGET_TAG}-4_all.deb" )
    MIRRORS=( "https://old-releases.ubuntu.com/ubuntu/pool/universe/d/dropbear" "https://ftp.debian.org/debian/pool/main/d/dropbear" "https://deb.debian.org/debian/pool/main/d/dropbear" "https://snapshot.debian.org/archive/debian/pool/main/d/dropbear" )
    ;;

  *)
    if [[ "${VER}" =~ ^[0-9]{4}\.[0-9]{1,2}$ ]]; then
      TARGET_TAG="${VER}"
      ARCH="amd64"
      DEB_FILES=( "dropbear-bin_${TARGET_TAG}-1_${ARCH}.deb" "dropbear-bin_${TARGET_TAG}_${ARCH}.deb" "dropbear_${TARGET_TAG}-1_all.deb" "dropbear_${TARGET_TAG}_all.deb" )
      MIRRORS=( "https://matt.ucc.asn.au/dropbear/releases" "https://mirror.dropbear.nl/mirror" "https://deb.debian.org/debian/pool/main/d/dropbear" )
    else
      echo "Versi tidak disokong: ${VER}. Sila pilih manual atau gunakan auto-detect." >&2
      [[ "${KEEP_TMP:-0}" == "0" ]] && rm -rf "$TMPDIR" || true
      exit 4
    fi
    ;;
esac

DEB_DOWNLOADED="0"
for f in "${DEB_FILES[@]}"; do
  if [[ -f "$f" ]]; then DEB_DOWNLOADED="1"; continue; fi
  if download_try "$f" "${MIRRORS[@]}"; then DEB_DOWNLOADED="1"; else echo "Tidak ditemui: $f"; fi
done

if [[ -n "${CHECKSUMS_FILE:-}" ]]; then
  verify_checksums_for_local_files "$CHECKSUMS_FILE" || { echo "Checksum verify gagal; batalkan."; exit 5; }
fi

if [[ "${DEB_DOWNLOADED}" == "1" ]]; then
  install_debs_and_fix_deps
  if [[ "${HOLD_AFTER:-0}" == "1" ]]; then apt-mark hold dropbear dropbear-bin dropbear-initramfs dropbear-run || true; fi
  if ! check_versions_post_install "yes" "${TARGET_TAG}"; then
    echo "Pengesahan pakej gagal untuk ${VER}. Mencuba fallback build-from-source..."
    if build_from_source_generic "${TARGET_TAG}"; then
      if ! check_versions_post_install "no" "${TARGET_TAG}"; then echo "Pengesahan selepas build gagal"; [[ "${KEEP_TMP:-0}" == "0" ]] && rm -rf "$TMPDIR" || true; exit 13; fi
      success_exit "Build-from-source berjaya dan disahkan untuk ${VER}."
    else
      echo "Fallback build gagal." >&2
      [[ "${KEEP_TMP:-0}" == "0" ]] && rm -rf "$TMPDIR" || true
      exit 14
    fi
  else
    success_exit "Pemasangan .deb untuk ${VER} disahkan."
  fi
else
  echo "Tiada .deb ditemui untuk ${VER}; melakukan build-from-source..."
  if build_from_source_generic "${TARGET_TAG}"; then
    if ! check_versions_post_install "no" "${TARGET_TAG}"; then echo "Pengesahan selepas build gagal"; [[ "${KEEP_TMP:-0}" == "0" ]] && rm -rf "$TMPDIR" || true; exit 15; fi
    success_exit "Build-from-source berjaya dan disahkan untuk ${VER}."
  else
    echo "Build-from-source gagal." >&2
    [[ "${KEEP_TMP:-0}" == "0" ]] && rm -rf "$TMPDIR" || true
    exit 16
  fi
fi

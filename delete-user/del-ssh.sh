#!/bin/bash

clear

# Ambil senarai user biasa (UID >= 1000) dan bukan 'nobody'
mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)

if [ ${#USERS[@]} -eq 0 ]; then
  echo "Tiada user (UID >= 1000) dijumpai."
  exit 0
fi

echo "=============================="
echo "   SENARAI USER SSH "
echo "=============================="

for i in "${!USERS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${USERS[$i]}"
done

echo " 0) Keluar"
echo

# Minta pilihan nombor
while true; do
  read -rp "Pilih nombor user untuk delete: " choice

  # Pastikan input nombor
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Sila masukkan nombor sahaja."
    continue
  fi

  # Keluar
  if [ "$choice" -eq 0 ]; then
    echo "Batal."
    exit 0
  fi

  # Valid range
  if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#USERS[@]}" ]; then
    echo "Nombor tidak sah. Pilih 1 hingga ${#USERS[@]}."
    continue
  fi

  Pengguna="${USERS[$((choice-1))]}"
  break
done

echo
echo "User dipilih: $Pengguna"

# Confirm
read -rp "Confirm delete user '$Pengguna'? (y/N): " confirm
confirm="${confirm,,}"  # lowercase

if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
  echo "Batal delete."
  exit 0
fi

# Delete
if getent passwd "$Pengguna" > /dev/null 2>&1; then
  userdel "$Pengguna"
  if [ $? -eq 0 ]; then
    echo "User $Pengguna berjaya dibuang."
  else
    echo "Gagal buang user $Pengguna (mungkin perlu sudo / user sedang digunakan)."
  fi
else
  echo "Failure: User $Pengguna tidak wujud."
fi
echo ""
read -n 1 -s -r -p "Press any key to back on menu SSH"
ssh2

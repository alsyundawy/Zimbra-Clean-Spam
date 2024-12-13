#!/bin/bash
## Author: HARRI DERTIN SUTISNA
## Dibuat: 13 Desember 2024
## Penggunaan: zimbra-clean-spam-queue.sh [opsi]
##
## Opsi:
##     -m  --maxlogins      Jumlah login maksimum yang diizinkan untuk periode tertentu (default: 50)
##     -s  --status         Status akun yang akan disetel (closed, blocked, maintenance)
##     -y  --yes            Konfirmasi otomatis untuk semua tindakan

# Variabel
zimbra_log="/var/log/zimbra.log"
domain="domain.tld"

zmprov="/opt/zimbra/bin/zmprov"
postqueue="/opt/zimbra/postfix/sbin/postqueue"
postsuper="/opt/zimbra/postfix/sbin/postsuper"

tanggal=$(date '+%Y-%m-%d-%H%M%S')

maxlogins=50
status_akun="closed"
konfirmasi_otomatis=false

# Fungsi
penggunaan() {
    echo "Penggunaan: $0 [-m maxlogins] [-s status_akun] [-y]"
    echo "  -m, --maxlogins      Jumlah login maksimum untuk periode tertentu (default: 50)"
    echo "  -s, --status         Status akun yang akan disetel (closed, blocked, maintenance)"
    echo "  -y, --yes            Konfirmasi otomatis untuk semua tindakan"
    exit 1
}

# Memproses argumen
while [[ "$1" != "" ]]; do
    case $1 in
        -m | --maxlogins)
            shift
            maxlogins=$1
            ;;
        -s | --status)
            shift
            status_akun=$1
            if [[ ! $status_akun =~ ^(closed|blocked|maintenance)$ ]]; then
                echo "Status akun tidak valid: $status_akun"
                penggunaan
            fi
            ;;
        -y | --yes)
            konfirmasi_otomatis=true
            ;;
        -h | --help)
            penggunaan
            ;;
        *)
            echo "Opsi tidak dikenal: $1"
            penggunaan
            ;;
    esac
    shift
done

# Memastikan file log ada
if [[ ! -f $zimbra_log ]]; then
    echo "Error: File log $zimbra_log tidak ditemukan."
    exit 1
fi

# Pesan pembuka
echo ""
echo "Memindai log untuk login pengguna yang berlebihan."
echo "Perilaku ini sering dikaitkan dengan akun yang telah disusupi."
echo "Akun yang melebihi $maxlogins login akan ditandai untuk ditinjau."
echo "Status akun akan diubah menjadi $status_akun jika dikonfirmasi."
echo ""

# Memproses login
declare -a daftar_login
daftar_login=($(sed -n 's/.*sasl_username=//p' "$zimbra_log" | sort | uniq -c | sort -rn))

for ((i = 0; i < ${#daftar_login[@]}; i+=2)); do
    jumlah_login=${daftar_login[$i]}
    nama_pengguna=${daftar_login[$i+1]}

    if [[ $jumlah_login -gt $maxlogins ]]; then
        echo "Pengguna: $nama_pengguna"
        echo "Jumlah Login: $jumlah_login"

        if $konfirmasi_otomatis; then
            jawaban="y"
        else
            echo -n "Apakah Anda ingin memblokir akun dan membersihkan antrian untuk $nama_pengguna? (y/n): "
            read jawaban
        fi

        if [[ $jawaban == "y" || $jawaban == "yes" ]]; then
            echo "Memblokir akun dan membersihkan antrian email untuk $nama_pengguna..."

            # Memblokir akun
            sudo -Hu zimbra $zmprov ma "$nama_pengguna@$domain" zimbraAccountStatus "$status_akun"

            # Membersihkan antrian email
            sudo -Hu zimbra $postqueue -p | awk -v user="$nama_pengguna" '$0 ~ user {print $1}' | sudo -Hu zimbra $postsuper -d -

            echo "Akun $nama_pengguna telah diblokir dan antrian dibersihkan."
        else
            echo "Melewati $nama_pengguna."
        fi
    fi

done

echo "SELESAI *********************************"

#!/bin/bash
# ============================================================
#   FINANSIAL APP v3.1 by Cliff — Launcher untuk macOS
#   Double-klik file ini untuk menjalankan aplikasi
# ============================================================

# Pindah ke folder tempat file ini berada
cd "$(dirname "$0")"

echo ""
echo "======================================================"
echo "   FINANSIAL APP v3.1 by Cliff"
echo "   Sistem Akuntansi untuk UMKM"
echo "======================================================"
echo ""

# ── Cek Python 3 ──────────────────────────────────────────
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 tidak ditemukan di sistem Anda."
    echo ""
    echo "Langkah install Python 3:"
    echo "  1. Buka https://www.python.org/downloads/"
    echo "  2. Download versi terbaru untuk macOS"
    echo "  3. Install, lalu jalankan file ini kembali"
    echo ""
    echo "Tekan Enter untuk keluar..."
    read
    exit 1
fi

PY=$(command -v python3)
echo "Python ditemukan: $PY"
echo ""

# ── Install / update library yang dibutuhkan ──────────────
echo "Memeriksa library yang dibutuhkan..."
"$PY" -m pip install flask openpyxl --quiet --user 2>/dev/null
if [ $? -ne 0 ]; then
    # Coba tanpa --user (jika pakai venv atau system python)
    "$PY" -m pip install flask openpyxl --quiet 2>/dev/null
fi
echo "Library siap."
echo ""

# ── Buka browser otomatis setelah 2 detik ─────────────────
(sleep 2.5 && open "http://127.0.0.1:5000") &

echo "======================================================"
echo "  Aplikasi berjalan di: http://127.0.0.1:5000"
echo ""
echo "  Login default:"
echo "    Username : admin"
echo "    Password : admin123"
echo ""
echo "  Tekan Ctrl+C untuk menghentikan aplikasi"
echo "======================================================"
echo ""

# ── Jalankan Flask app ─────────────────────────────────────
"$PY" app.py

echo ""
echo "Aplikasi dihentikan. Tutup jendela ini."
read

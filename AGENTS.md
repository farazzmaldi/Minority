# Minority — aturan pengembangan

## Konteks yang perlu dibaca

- `README.md`: cara menjalankan aplikasi dan status implementasi.
- `docs/MASTERPLAN.md`: arah keseluruhan, batas fitur, dan dependensi tahap.
- `docs/REQUIREMENTS.md`: kebutuhan ber-ID serta kriteria penerimaan.
- `docs/DECISIONS.md`: sumber keputusan, struktur aktual, dan batas tanggung jawab kode.
- `docs/PROGRESS.md`: tugas, status, bukti pemeriksaan, dan commit.
- Baca bagian yang relevan dengan tugas; perluas pemeriksaan jika ada ketergantungan atau kegagalan yang memerlukannya.
- Permintaan terbaru pengguna menentukan pekerjaan yang diizinkan. Item roadmap dan usulan di dokumen bukan izin untuk mengimplementasikan semua fitur.

## Cara bekerja

Ikuti DEC-017 yang CONFIRMED: interaksi pengguna melalui Codex dalam GUI ChatGPT Desktop pada repository lokal Minority yang sudah ada, tanpa kewajiban pengguna mengoperasikan Codex CLI. Eksekusi build/test internal mengikuti instruksi tugas; kebutuhan verifikasi native lokal mengikuti DEC-013. Jangan mengatribusikan kesimpulan audit atau usulan klasifikasi rilis asisten sebagai konfirmasi pengguna.

1. Periksa status Git dan kode terkait sebelum mengubah file. Pertahankan perubahan pengguna yang sudah ada.
2. Tautkan tugas ke requirement dan keputusan yang relevan. Tentukan hasil yang bisa diamati, kriteria selesai, dan cakupan perubahan. Sampaikan rencana singkat untuk pekerjaan yang melibatkan beberapa bagian.
3. Cari implementasi yang dapat dipakai ulang. Buat perubahan terkecil yang menyelesaikan kebutuhan secara utuh.
4. Jalankan pemeriksaan yang sesuai, periksa diff, dan perbaiki kegagalan yang disebabkan perubahanmu.
5. Perbarui tugas terkait dalam `docs/PROGRESS.md`, lalu laporkan hasil, file yang berubah, pemeriksaan yang benar-benar dilakukan, dan keterbatasan yang masih ada.

Lanjutkan pekerjaan rutin yang sudah diizinkan sampai selesai. Tanyakan hanya ketidakjelasan yang memengaruhi aturan produk, keamanan data, atau keputusan yang sulit dibalik. Jangan berhenti untuk meminta persetujuan pada setiap file atau langkah kecil.

Baseline governance G0 telah dipublikasikan. TASK-D-001 diterima untuk scope Plan; WF-01 planning disetujui dan diterima terbatas melalui DEC-022/023. Cakupan Product MVP disetujui melalui DEC-025, tetapi implementasi, penerimaan hasil, dan kesiapan rilis tetap dilacak terpisah; OPEN-008 belum terpenuhi. Sebelum memulai fitur berikutnya, kaitkan scope tugas serta kriterianya dengan permintaan pengguna dan keputusan yang berlaku. Pernyataan asisten lama bahwa suatu rancangan disetujui bukan bukti persetujuan pengguna; pertahankan status sumbernya. Implementasi, hasil pemeriksaan, penerimaan pengguna, commit, dan push adalah status yang berbeda. Jangan melanjutkan fitur di luar cakupan yang disetujui hanya karena item tersebut ada di roadmap.

Hormati cakupan keputusan CONFIRMED: pilihan model hybrid tidak sekaligus menyetujui semua aturan target, versi, atau evaluasi. Saat mengubah arah produk, catat sumber konfirmasi serta dampak requirement yang relevan. Sebelum penggunaan rutin data pribadi penting, penuhi gerbang backup, pemulihan, dan peningkatan database dalam masterplan.

## Menjaga kode tetap sederhana

- Pertahankan Swift, SwiftUI, Swift Package Manager, dan SQLite melalui GRDB sesuai arsitektur saat ini.
- Setiap file, tipe, fungsi, dan dependensi baru harus mempunyai pemakai atau kebutuhan nyata dalam tugas saat ini.
- Jangan menambahkan fitur spekulatif, placeholder, direktori kosong, atau implementasi alternatif yang ditinggalkan.
- Gunakan tipe konkret dan fungsi langsung sebagai awal. Tambahkan protocol, wrapper, generic, atau lapisan service jika ada kebutuhan yang dapat dijelaskan.
- Ekstrak logika bersama ketika tanggung jawabnya memang sama. Jangan memaksakan abstraksi untuk kode yang hanya terlihat mirip.
- Alasan dependensi baru harus menjelaskan kebutuhan, alternatif yang sudah tersedia, kompatibilitas, dan biaya pemeliharaannya. Jangan memperbarui dependensi lain bersamaan tanpa kebutuhan.
- Ikuti format kode sekitar. Hindari pemformatan seluruh proyek ketika mengerjakan fitur lokal.
- Bersihkan import, kode sementara, dan jalur lama yang menjadi tidak diperlukan akibat perubahanmu.
- Sebelum menghapus kode yang diduga tidak terpakai, periksa entry point, konfigurasi package, pemanggilan tidak langsung, dan penggunaan saat runtime.
- Komentar menjelaskan alasan atau batasan penting. Hindari komentar yang mengulang isi kode.
- Ubah dokumentasi yang terdampak. Gunakan dokumen yang sudah ada sebelum membuat dokumen baru.

## Batas arsitektur dan data

- SwiftUI menangani tampilan dan interaksi. Jangan menaruh SQL atau aturan bisnis hanya di dalam view.
- `MinorityPersistence` menangani penyimpanan; modul ini tidak bergantung pada SwiftUI.
- Model planning saat ini berada di target persistence. Pemisahan target baru harus menyelesaikan kebutuhan nyata, bukan sekadar mengikuti template arsitektur.
- Hindari salinan state yang bisa diturunkan dari sumber data yang sama. Jangan membuat cache atau global state tanpa kebutuhan.
- Propagasikan error dengan konteks yang dapat ditindaklanjuti. Jangan mengubah kegagalan baca menjadi hasil kosong atau memakai `try?` untuk menyembunyikan kegagalan penting.
- Gunakan parameter SQL untuk data masukan, foreign key untuk relasi, dan transaksi untuk perubahan yang harus berhasil bersama.
- Pertahankan data pengguna. Kegagalan database tidak boleh memicu reset atau penghapusan otomatis.
- Tambahkan migrasi untuk perubahan skema yang sudah dipakai. Jangan menulis ulang migrasi lama tanpa memastikan status distribusi dan jalur peningkatan datanya.
- Pemeriksaan persistence menggunakan database sementara; jangan memakai database pribadi di Application Support.
- Jangan memasukkan database pribadi, dokumen pengguna, kredensial, atau hasil build ke Git.

## Pemeriksaan sesuai perubahan

| Perubahan | Pemeriksaan yang diperlukan |
| --- | --- |
| Dokumentasi | Ketepatan fakta terhadap kode, tautan lokal, dan `git diff --check` |
| Swift atau konfigurasi package | `swift build --force-resolved-versions` |
| Domain, persistence, atau migrasi | Build, lalu `swift run --skip-build MinorityPersistenceChecks`; tambahkan kasus perilaku atau regresi yang relevan |
| Tampilan atau interaksi | Build dan pemeriksaan langsung alur yang berubah, termasuk kondisi kosong dan gagal yang relevan |
| Pengemasan aplikasi | `./scripts/package-app.sh` dan pemeriksaan bundle yang dihasilkan |

- `MinorityPersistenceChecks` adalah executable pemeriksaan yang sudah tersedia. `swift test` belum memiliki test target; jangan melaporkannya sebagai pengganti pemeriksaan ini.
- Jangan membuat tes yang hanya menyalin implementasi. Uji hasil, aturan data, dan kasus gagal yang bermakna.
- Tidak perlu membangun atau menjalankan tes aplikasi untuk perubahan dokumentasi saja.
- Jangan mengklaim tampilan sudah diperiksa jika aplikasi belum dibuka. Jika lingkungan tidak mendukung pemeriksaan, sebutkan bagian yang belum diverifikasi.
- Keberhasilan persistence saja tidak membuktikan UI offline. Periksa kinerja UI dasar/startup/database secara terpisah dari benchmark pencarian semantik sesuai requirement yang relevan.
- Workflow `.github/workflows/quality.yml` menjalankan build dan pemeriksaan persistence. Pemeriksaan UI dan notarization memerlukan verifikasi tersendiri.

## Kriteria selesai dan Git

- Hasil memenuhi permintaan dan kriteria penerimaannya; tidak ada perubahan di luar cakupan tanpa alasan yang berkaitan langsung.
- Tidak ada kode percobaan atau implementasi ganda yang tertinggal dari tugas tersebut.
- Pemeriksaan yang relevan lulus, atau hambatan dilaporkan dengan jujur tanpa menyatakan pekerjaan sudah terverifikasi.
- Tinjau diff akhir, termasuk file baru. Jangan menyertakan perubahan pengguna lain dalam commit tugasmu.
- Buat commit, push, publikasi, atau perubahan pengaturan GitHub hanya jika termasuk permintaan pengguna atau otorisasi sesi.
- Pisahkan checkpoint C1 dan governance. Setelah commit/push benar-benar terjadi, perbarui progres dan status README berdasarkan SHA serta bukti remote; gunakan commit dan hasil pemeriksaan sebagai bukti utama, tanpa mewajibkan checksum manual setiap file.
- Jika membuat branch baru, gunakan awalan `codex/` kecuali pengguna menentukan nama lain.

## Code Review Rules

- Tandai SQL dalam view, kebocoran dependensi SwiftUI ke persistence, atau error penyimpanan yang disembunyikan.
- Tandai risiko kehilangan data, perubahan migrasi yang merusak jalur peningkatan, dan relasi data tanpa perlindungan yang sesuai.
- Tandai abstraksi atau dependensi baru yang tidak mempunyai kebutuhan nyata dalam perubahan yang ditinjau. Jelaskan dampaknya; jangan menuntut pemecahan file berdasarkan jumlah baris saja.

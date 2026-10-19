# Minority — masterplan

Versi baseline 0.3 · 19 Oktober 2026 · Prioritas saat ini: finalisasi checkpoint C1 dan publikasi G0 yang diotorisasi melalui U4. Kesimpulan audit dokumentasi merupakan penilaian asisten; Product MVP belum disetujui.

Dokumen ini menyatukan arah proyek dari kode dan riwayat yang diberikan pengguna. Cakupan yang belum diputuskan tetap terbuka. Penulisan masterplan tidak merupakan persetujuan otomatis atas fitur, formula, atau seluruh rancangan domain.

## Visi dan alur utama

Minority adalah aplikasi native macOS untuk pengelolaan kehidupan pribadi melalui perencanaan, instruksi operasional, pencatatan pelaksanaan, evaluasi, serta pengelolaan informasi. Data utama disimpan lokal; fungsi inti dapat berjalan tanpa internet.

Alur yang tercatat dalam riwayat adalah sasaran → rencana → kegiatan → jadwal eksplisit → pelaksanaan → evaluasi. Perintah Induk dan Perintah Harian mendukung alur tersebut; kegiatan terjadwal dan pencatatan pelaksanaan tidak harus bergantung pada penerbitan perintah. Pengelolaan dokumen, pencarian, dan impor terstruktur mendukung proses utama.

Pengguna awal diasumsikan pemilik aplikasi untuk pemakaian pribadi. Kolaborasi, banyak akun, backend, sinkronisasi, dan platform tambahan belum ditetapkan sebagai kebutuhan. Jangan membangun infrastrukturnya sebelum ada kebutuhan tersendiri.

## Tempat mencari informasi

| Dokumen | Tanggung jawab |
| --- | --- |
| `MASTERPLAN.md` | Visi, batas keseluruhan, dependensi tahap, risiko, dan gerbang pengembangan |
| `REQUIREMENTS.md` | Kebutuhan ber-ID, aturan, kriteria penerimaan, dan status dasar kebutuhannya |
| `DECISIONS.md` | Keputusan beserta sumber, alasan, konsekuensi, dan batas arsitektur |
| `PROGRESS.md` | Status aktual, tugas aktif, bukti pemeriksaan, serta referensi commit |
| `../AGENTS.md` | Instruksi kerja agen dan pemeriksaan per jenis perubahan |
| `../README.md` | Gambaran singkat, setup, build, menjalankan, dan pengemasan |

Kebutuhan tidak disalin menjadi spesifikasi berbeda di setiap dokumen. Roadmap merujuk ID kebutuhan; progres merujuk ID tugas dan bukti.

## Sumber dan tingkat kepastian

- **U1 — Permintaan langsung pengguna:** proyek harus rapi, minim kode sampah, mempunyai masterplan tertulis, dan mudah dilacak. Termasuk keberatan pengguna tentang tidak adanya masterplan dalam riwayat yang dilampirkan.
- **U2 — Pilihan hybrid pengguna:** kutipan “Model kombinasi keduanya.”, disampaikan kembali dalam audit G0 bagian P0-02 yang diberikan pengguna pada 19 Oktober 2026. Konteksnya pemilihan Perintah Induk sebagai dokumen formal sekaligus pengendali kegiatan. Tanggal ucapan asli tidak tersedia; cakupan konfirmasi hanya pilihan model, bukan semua aturan turunannya. Ringkasan bukti dipertahankan di `DECISIONS.md`.
- **U3 — Workflow yang dikonfirmasi langsung pengguna, 19 Oktober 2026:** gunakan Codex melalui GUI ChatGPT Desktop, kerjakan repository lokal Minority yang sudah ada, dan jangan mewajibkan pengguna mengoperasikan Codex CLI. Konfirmasi ini terbatas pada tiga pilihan workflow tersebut; kesimpulan audit dan klasifikasi rilis bukan persetujuan produk pengguna.
- **U4 — Otorisasi finalisasi langsung pengguna, 19 Oktober 2026:** koreksi provenance; verifikasi, commit, dan push C1 secara terpisah; sinkronkan lalu commit/push G0; periksa CI dan catat hasilnya melalui commit dokumentasi terpisah bila diperlukan. Otorisasi ini menerima publikasi checkpoint, tanpa menyetujui Product MVP atau memulai fitur baru.
- **K1 — Repository dan checkpoint:** dasar dokumentasi awal `3c668f25e39854ec8d6ba544453e2fa7e6bd74cd`; C1 kemudian di-commit dan dipublikasikan sebagai `7e268be9b3230675fccc34ff06e038f6651c149f`. Remote `main` diverifikasi menunjuk SHA C1 pada 19 Oktober 2026. Status publikasi governance dan CI dicatat di `PROGRESS.md`.
- **H1 — Riwayat lampiran:** percakapan tentang Foundation A/B/C1, hybrid Perintah Induk, empat keputusan domain, tiga penyesuaian, dan usulan roadmap. Disampaikan kembali pada 19 Oktober 2026. Teks mengandung laporan serta pernyataan persetujuan asisten; pernyataan tersebut bukan bukti persetujuan langsung pengguna.
- **V1 — Pemeriksaan G0 awal:** build dan executable persistence dijalankan pada kode lokal sebelum audit. Rinciannya dicatat di `PROGRESS.md`; revisi dokumentasi ini tidak mengulang build aplikasi.
- **A1 — Audit G0:** audit yang diberikan pengguna pada 19 Oktober 2026, bagian P0-01..03, P1-01..05, dan P2-01..03 beserta instruksi revisi terdahulu yang mempertahankan C1 dan melarang staging/commit/push pada tahap itu. Finalisasi saat ini diotorisasi terpisah melalui U4. Rekomendasi produk dalam audit tetap usulan kecuali konfirmasi spesifik U2.
- **A2 — Penilaian dan usulan asisten dalam tindak lanjut G0:** kesimpulan bahwa P0 telah ditangani pada tingkat dokumentasi, klasifikasi Technical Alpha/Product MVP/Extended Releases, serta penjelasan batas verifikasi. Dicatat pada 19 Oktober 2026 sebagai penilaian atau usulan desain asisten, bukan konfirmasi langsung pengguna atas kesimpulan audit maupun cakupan rilis.

Status kebutuhan: `CONFIRMED` untuk arahan langsung pengguna; `RECORDED` untuk kebutuhan atau keputusan yang tercatat dalam riwayat; `PROPOSED` untuk usulan baru; `OPEN` untuk detail yang belum tersedia. Status implementasi dan verifikasi dicatat terpisah. Sebuah kebutuhan dapat sudah diimplementasikan tanpa dinyatakan diterima sebagai produk final.

## Peta kemampuan dan roadmap

Urutan berikut adalah rancangan berdasarkan dependensi, tanpa tenggat atau persentase selesai yang dibuat-buat. Kriteria rinci berada di daftar kebutuhan.

| ID | Tahap | Ketergantungan | Hasil dan gerbang selesai |
| --- | --- | --- | --- |
| G0 | Tata kelola proyek | U1, K1, H1 | Empat dokumen terhubung, aturan agen tersedia, status berbukti, dan keputusan terbuka terlihat — `REQ-GOV-001..003` |
| A | Fondasi aplikasi | Platform macOS | Aplikasi dapat dibangun dan startup ditangani — `REQ-FND-001` |
| B | Fondasi penyimpanan | A | Database lokal, migrasi, integritas operasi, dan fungsi inti offline — `REQ-DAT-001..003` |
| C | Spesifikasi domain | G0 dan H1 | Identitas entitas, relasi, serta aturan terkait tahap berikutnya cukup jelas untuk diimplementasikan |
| C1 | Core planning persistence | B, bagian C yang relevan | Plan, Activity, relasi, dan occurrence tersimpan serta tervalidasi — `REQ-PLN-001..003`, `REQ-SCH-001..002` |
| D | Planning yang dapat dipakai | C1; keputusan antarmuka | Alur membuat dan melihat rencana, kegiatan, serta jadwal; Objective ditambahkan setelah kebutuhannya dirinci — `REQ-PLN-004`, `REQ-OBJ-001` |
| E | Perintah operasional | C1, spesifikasi publikasi, koreksi, dan keluaran dokumen | Perintah Induk hybrid serta Perintah Harian dengan versi, snapshot, dan representasi dokumen — `REQ-CMD-001..007` |
| F | Pelaksanaan | C1, spesifikasi status pelaksanaan | Pencatatan mandiri dengan satu identitas pelaksanaan per occurrence — `REQ-EXE-001..002` |
| G | Evaluasi | F, rubrik dan formula yang ditetapkan | Penilaian manual/otomatis dan penjelasannya dapat ditelusuri; data kurang dan sejarah koreksi terjaga — `REQ-EVA-001..005` |
| H | Impor planning terstruktur | Skema domain yang akan diimpor stabil | JSON divalidasi, ditinjau pengguna, dan diimpor tanpa perubahan parsial — `REQ-IMP-001` |
| I | Pengelolaan dokumen | Kebijakan berkas dan ekstraksi | Dokumen lokal dapat dikelola; ekstraksi serta OCR punya batas yang jelas — `REQ-DOC-001` |
| J | Pencarian | I dan/atau domain yang hendak dicari | Pencarian terstruktur; FTS dan semantik hanya setelah kebutuhan serta biaya sumber daya ditetapkan — `REQ-SRC-001..002` |
| K | Penguatan produk | Berlaku lintas tahap; gate rilis setelah fitur terpilih | Peningkatan skema, pemulihan data, responsivitas, dan distribusi terverifikasi — `REQ-REL-001..002` |

Istilah lama **C2 = E**, **C3 = F**, dan **C4 = G**. **C1** tetap berarti model dan persistence dasar, sehingga kelulusannya tidak berarti seluruh Planning System atau UI selesai. F dapat berjalan tanpa E; urutan E/F dapat ditukar setelah prioritas pengguna jelas. H/I tidak wajib menunggu seluruh G. Perlindungan data berlaku sejak B, bukan baru pada K.

## Strategi rilis

### Technical Alpha — kandidat terbatas, PROPOSED

Cakupan planning dan penjadwalan lokal yang pada v0.2 disebut Candidate MVP dicatat sebagai usulan asisten (A2) untuk **Technical Alpha**, guna memvalidasi fondasi teknis dan alur UI dasar. Alpha dapat divalidasi dengan data uji; penggunaan rutin data pribadi penting tetap harus memenuhi gerbang perlindungan data. Usulan ini belum menetapkan Product MVP.

| Cakupan kandidat | Acuan dan batas |
| --- | --- |
| Membuat dan melihat Plan serta Activity, menghubungkan keduanya, lalu membuat dan melihat jadwal eksplisit | `REQ-PLN-001..004`, `REQ-SCH-001..002`; alur WF-01. Koreksi masukan dan kebijakan edit/hapus data tersimpan harus dijelaskan sebelum rilis melalui OPEN-001 |
| Kondisi kosong, validasi, kegagalan simpan/baca, dan data yang tetap tersedia setelah restart | `REQ-PLN-004`, `REQ-DAT-001..002` |
| Fungsi inti tanpa jaringan setelah aplikasi dan dependensinya tersedia | `REQ-DAT-003`; build awal dapat memerlukan unduhan dependensi |
| Perlindungan data yang cukup untuk penggunaan rutin | `REQ-REL-001`: strategi backup, restore, serta peningkatan database ditetapkan dan diuji sebelum data pribadi penting digunakan |
| Alur UI serta bundle yang dapat dijalankan sesuai cara distribusi yang dipilih | `REQ-FND-001`, `REQ-REL-002`; belum ada janji signing, notarization, atau target kinerja tertentu |

### Product MVP — scope memerlukan persetujuan

**Candidate Product MVP Scope: OPEN. Approved Product MVP Scope: belum ditetapkan.** Product MVP adalah produk Minority terkecil yang berguna bagi pengguna, dengan cakupan yang memerlukan persetujuan eksplisit. Hasil Technical Alpha dapat menjadi masukan untuk memilih kemampuan tersebut. Pemilihan perintah, pelaksanaan, evaluasi, atau kemampuan lain untuk Product MVP dicatat beserta sumber dan tanggalnya; konfirmasi model hybrid saja belum menentukan pembagian rilis.

### Extended Releases — pemilihan melalui roadmap

Extended Releases memuat kemampuan tambahan yang dipilih melalui roadmap dan persetujuan cakupan terkait. Objective, planning lanjutan, perintah/ekspor, pelaksanaan, evaluasi, impor JSON, dokumen/OCR, serta pencarian tetap berada dalam roadmap. Penempatan setiap kemampuan pada Product MVP atau rilis lanjutan belum dikunci; seluruh fitur yang direncanakan tidak otomatis wajib pada rilis pertama.

### Release Acceptance Criteria — usulan gerbang penerimaan

- Jenis rilis, cakupan yang dipilih, dan keputusan yang memengaruhinya dinyatakan jelas; Product MVP memerlukan persetujuan eksplisit, dengan bukti untuk acceptance criteria terkait.
- Technical Alpha memvalidasi WF-01 melalui UI sesuai cakupan yang dipilih, termasuk masukan salah, kondisi kosong, kegagalan, dan pembukaan ulang aplikasi. Product MVP memvalidasi seluruh alur yang masuk cakupan persetujuannya.
- Fungsi offline UI diuji melalui interaksi aplikasi tanpa jaringan pada alur yang dirilis. SQLite persistence checks membuktikan perilaku penyimpanan yang diuji dan tidak secara mandiri membuktikan UI offline. Gerbang data penting tetap berlaku; backup harus benar-benar dapat dipulihkan.
- Kinerja UI dasar, startup, dan operasi database dasar dinilai dengan beban serta kriteria tersendiri melalui OPEN-008. Kinerja pencarian semantik memiliki kriteria terpisah melalui OPEN-007 dan REQ-SRC-002; target numerik keduanya belum ditetapkan.
- Build serta pemeriksaan persistence lulus pada versi yang akan dirilis; hasil UI, packaging/signing yang relevan, dan hasil GitHub Actions dicatat terpisah. CI disebut lulus setelah ada run berhasil yang menunjuk commit terkait.
- Pengguna menerima hasil dan keterbatasan rilis. Versi sumber diidentifikasi dengan commit, status publikasi, dan bukti pemeriksaan; tidak ada klaim selesai berdasarkan daftar file saja.

Keputusan rilis yang masih terbuka: penerimaan cakupan Technical Alpha, cakupan Product MVP, pembagian Extended Releases, kebijakan koreksi/hapus, bahasa dan navigasi UI, kriteria kinerja dasar, mekanisme backup/restore, cara distribusi, serta tenggat. Detail terkait merujuk OPEN-001/008 dalam `DECISIONS.md`; pertanyaan untuk fitur berikutnya diselesaikan sebelum fitur tersebut dibangun.

## Peta alur produk

Langkah serta acuan requirement setiap alur disimpan sekali di [End-to-End User Workflows](REQUIREMENTS.md#end-to-end-user-workflows). Peta ini tidak merupakan izin implementasi seluruh alur.

| Alur | Hasil pengguna dan acuan |
| --- | --- |
| WF-01 — Planning | Membuat rencana dan kegiatan, menghubungkannya, lalu menjadwalkan serta melihatnya kembali — `REQ-PLN-001..004`, `REQ-SCH-001..003` |
| WF-02 — Perintah operasional | Membuat draft, meninjau, menerbitkan, dan merevisi perintah serta keluarannya — `REQ-CMD-001..007` |
| WF-03 — Pelaksanaan | Mencatat pekerjaan yang dilakukan dengan identitas occurrence yang stabil — `REQ-EXE-001..002` |
| WF-04 — Evaluasi | Mengisi atau meninjau hasil penilaian, melihat dasar perhitungan, dan menjaga koreksi historis — `REQ-EVA-001..005` |
| WF-05 — Informasi | Menyimpan dan membaca dokumen, mengekstrak informasi, lalu mencari sumbernya — `REQ-DOC-001`, `REQ-SRC-001..002` |
| WF-06 — Impor planning | Meninjau rancangan terstruktur, memvalidasi, dan menyetujui impor — `REQ-IMP-001`, `REQ-DAT-002` |

## Gerbang perlindungan data

Sebelum Minority dipakai rutin untuk data pribadi yang penting, strategi backup, pemulihan, dan peningkatan database harus ditetapkan serta diuji sesuai `REQ-REL-001`. Tetapkan data yang dilindungi, cara membuat salinan konsisten, lokasi/akses salinan, dan langkah pemulihannya. Verifikasi restore dan upgrade dari database lama pada salinan atau fixture; jangan memakai data pribadi sebagai bahan percobaan.

Gerbang ini berlaku untuk rilis awal dan tidak menunggu seluruh tahap K. Revisi G0 mendokumentasikan syarat tersebut; implementasi backup dan penetapan mekanismenya memerlukan tugas terpisah.

## Kronologi dan batas checkpoint

Urutan historis adalah A → B → pembaruan README pada `3c668f2` → implementasi C1 lokal → penyusunan G0 → audit dan revisi G0 → publikasi checkpoint C1 `7e268be`. **Implementasi C1 mendahului penyelesaian tata kelola G0.** Bukti teknis C1 yang sudah ada dipertahankan; penerapan proses baru dimulai pada pekerjaan berikutnya.

Checkpoint C1 terpisah dari G0: empat file implementasi dipublikasikan dalam `7e268be9b3230675fccc34ff06e038f6651c149f`. Kelompok berkas, SHA governance, bukti publikasi, dan run CI dicatat di [progres](PROGRESS.md#batas-checkpoint-dan-publikasi). U4 mengotorisasi publikasi governance dan pencatatan CI melalui commit dokumentasi tersendiri; otorisasi ini tidak menerima Product MVP atau mengubah keputusan OPEN/PROPOSED.

## Syarat penyelesaian milestone

| Dimensi | Bukti yang diperlukan |
| --- | --- |
| Implemented | Perubahan terkait tersedia dan memenuhi cakupan tugas; daftar berkas atau commit dapat ditunjukkan |
| Verified | Pemeriksaan acceptance criteria yang relevan, tanggal, versi sumber, hasil, serta batas yang belum diuji tercatat |
| Accepted | Pernyataan penerimaan pengguna dengan tanggal dan cakupannya; rekomendasi asisten tidak menggantikannya |
| Committed | SHA commit lokal yang benar-benar memuat berkas terkait, dengan pemeriksaan isi commit |
| Pushed | Bukti pemeriksaan remote setelah publikasi; ref lokal tersimpan saja belum membuktikan keadaan remote terbaru |

Hindari label “milestone selesai” tanpa cakupan. Gunakan kelima dimensi dalam progres. Sebutan “baseline resmi dipublikasikan” memerlukan acceptance, verifikasi yang relevan, commit, dan bukti remote; hasil CI tetap memiliki identitas run sendiri dan tidak membuktikan UI atau packaging.

## Batas implementasi saat ini

Pekerjaan aktif adalah penyusunan G0 dan pencatatan kondisi C1 yang sudah ada. Pengembangan fitur berikutnya dimulai ketika kebutuhan terkait memiliki kriteria penerimaan dan keputusan yang cukup jelas. Jangan melanjutkan C2/E, membuat seluruh tabel rancangan lama, atau memilih model embedding hanya karena tercantum dalam roadmap.

Stack aktual adalah Swift, SwiftUI, Swift Package Manager, serta SQLite melalui GRDB. Build dan pengemasan native membutuhkan lingkungan macOS yang sesuai. Mesin sasaran MacBook Air M3 dengan RAM 8 GB tercatat di H1, tetapi spesifikasi mesin dan anggaran kinerja belum diverifikasi dalam sesi ini. Hindari menetapkan janji kinerja atau model AI berdasarkan asumsi tersebut.

Workflow pengembangan yang dikonfirmasi melalui U3/DEC-017 menggunakan Codex dalam GUI ChatGPT Desktop pada repository lokal Minority. Pengguna tidak perlu mengoperasikan Codex CLI. Codex boleh menjalankan perintah build/test secara internal ketika diperlukan; verifikasi build native macOS tetap dilakukan lokal. CI GitHub dicatat sebagai bukti tambahan dengan statusnya sendiri.

Impor rancangan dari ChatGPT tanpa ketergantungan API berbayar tercatat dalam H1. Detail skema dan interaksinya masih perlu ditetapkan; jangan menambahkan integrasi API secara otomatis.

## Gerbang setiap tugas

1. Tautkan permintaan ke `REQ-*` dan `DEC-*` yang relevan. Kebutuhan kecil baru dapat dicatat ringkas pada dokumen yang sama.
2. Tetapkan hasil, batas tugas, dan acceptance criteria. Selesaikan hanya pertanyaan terbuka yang memengaruhi tugas tersebut.
3. Periksa perubahan lokal, gunakan kembali kode yang ada, dan implementasikan hasil yang diminta tanpa memperluas fitur.
4. Jalankan pemeriksaan yang bermakna dan tinjau diff, termasuk file baru serta dampaknya terhadap data lama.
5. Perbarui baris tugas di `PROGRESS.md` dengan implementasi, bukti, dan commit bila tersedia. Push serta penerimaan produk merupakan status terpisah.

Pembersihan lokal yang rutin dan perbaikan yang sudah diizinkan tidak memerlukan rapat atau dokumen baru. Perubahan arah produk, aturan domain, dependensi utama, atau risiko kehilangan data perlu keputusan yang tercatat.

## Risiko dan pertanyaan yang harus dijaga

| Risiko atau ketidakpastian | Penanganan |
| --- | --- |
| Pernyataan asisten dianggap persetujuan pengguna | Simpan sumber serta status; jangan mempromosikan `RECORDED` menjadi `CONFIRMED` secara otomatis |
| Model/tabel dianggap fitur siap dipakai | Lacak persistence, integrasi UI, verifikasi, dan acceptance secara terpisah |
| Rancangan sekitar 20 tabel langsung diimplementasikan | Tambahkan tabel untuk kebutuhan aktif; schema masa depan tetap konseptual |
| Duplikasi Activity atau Execution akibat revisi perintah | Pertahankan identitas master dan occurrence; gunakan snapshot dokumen historis |
| Formula evaluasi atau skala prioritas dikarang | Buka spesifikasi rubrik, data hilang, dan agregasi sebelum G |
| Perubahan jadwal merusak sejarah perintah | Tetapkan koreksi occurrence dan revisi eksplisit perintah terkait sebelum E |
| Dokumen pribadi hilang atau bocor | Tetapkan kebijakan penyimpanan, backup, penghapusan, serta indeks sebelum I/J |
| OCR dan embeddings membebani mesin sasaran | Ukur terhadap dataset dan anggaran yang disepakati sebelum memilih solusi |
| Dokumentasi menjadi pekerjaan ganda | Satu tempat per informasi; revisi hanya bagian yang terdampak |

Kesiapan rilis fungsional dinilai dari cakupan yang disetujui, alur yang benar-benar dapat dipakai, integritas data, dan pemeriksaan yang tercatat. Kandidat Technical Alpha tersedia di atas; cakupan Product MVP, pembagian Extended Releases, dan tenggat masih terbuka.

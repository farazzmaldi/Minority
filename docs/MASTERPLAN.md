# Minority — masterplan

Versi baseline 0.3 · diperbarui 20 Oktober 2026 · TASK-D-001, TASK-D-002, dan WF-01 diterima pengguna untuk scope terbatasnya. Cakupan Product MVP juga telah disetujui melalui DEC-025; implementasi dan kesiapan rilis masih berjalan/menunggu gerbang OPEN-008. Kesimpulan audit dokumentasi merupakan penilaian asisten.

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
- **U5 — Keputusan bahasa UI langsung pengguna, 19 Oktober 2026:** Minority mendukung English dan Bahasa Indonesia; pengguna memilih bahasa secara manual melalui Settings; pilihan tersimpan antar-peluncuran; bahasa tidak mengikuti system language macOS; dan pergantian bahasa tidak mengubah konten buatan pengguna. Dicatat sebagai `DEC-018`/`REQ-UI-001`; tidak mengotorisasi implementasi lokalisasi.
- **U6 — Otorisasi TASK-D-001 dan keputusan navigasi terbatas, 19 Oktober 2026:** pengguna meminta implementasi pembuatan/daftar Plan dan pengaturan bahasa, lalu memilih daftar Plan, sheet tambah, dan jendela Settings standar macOS. Dicatat sebagai `DEC-019`. Otorisasi ini hanya untuk TASK-D-001 dan tidak menerima kandidat Technical Alpha atau Product MVP.
- **U7 — Otorisasi TASK-D-002, 20 Oktober 2026:** pengguna menjawab “lanjut” atas scope Activity → hubungkan ke Plan → jadwalkan satu kali. Dicatat sebagai `DEC-020`; pada saat itu persetujuan hanya untuk TASK-D-002, bukan Technical Alpha, Product MVP, atau seluruh REQ-PLN-004.
- **U8 — Penerimaan TASK-D-002 dan persetujuan scope WF-01, 20 Oktober 2026:** pengguna menjawab “anggap aja aku setuju” setelah diminta menerima implementasi D-002 dan menyetujui WF-01 sebagai cakupan berikutnya, termasuk pemeriksaan offline UI. Dicatat sebagai `DEC-021`/`DEC-022`. Ini menerima D-002 dan menyetujui implementasi/verifikasi Technical Alpha terbatas WF-01; pada saat itu belum menyatakan Alpha siap rilis atau menyetujui Product MVP, distribusi publik, maupun penggunaan rutin data pribadi penting.
- **U9 — Penerimaan WF-01, 20 Oktober 2026:** setelah meminta verifikasi ulang bukti, pengguna menginstruksikan agar penerimaan dicatat untuk WF-01 saja. Dicatat sebagai `DEC-023`; penerimaan historis ini tidak menyatakan Technical Alpha siap rilis atau seluruh `REQ-PLN-004` selesai. Persetujuan scope MVP datang kemudian melalui U11/DEC-025.
- **U10 — Mandat otonomi penyelesaian produk, 20 Oktober 2026:** pengguna meminta pekerjaan diteruskan secara lokal sampai produk yang ditentukan requirement dan roadmap yang disetujui selesai, dengan disiplin pencatatan progres. Ini mengizinkan pilihan implementasi rutin yang aman, tetapi tidak mengubah requirement berstatus `OPEN`/`PROPOSED` atau melewati gate keamanan data dan keputusan produk yang belum disetujui.
- **U11 — Persetujuan cakupan Product MVP, 20 Oktober 2026:** setelah menerima usulan cakupan yang merinci WF-01 ditambah pencatatan manual satu pelaksanaan per occurrence dan tampilan riwayatnya, pengguna menjawab “setuju usulan MVP”. Persetujuan ini mengunci cakupan MVP yang tercantum di bagian Strategi Rilis; tidak menyatakan fitur sudah selesai/diterima atau siap dirilis, tidak menaikkan status seluruh `REQ-PLN-004` maupun `REQ-EXE-001..002`, dan tidak menutup gate OPEN-008.
- **U12 — Otorisasi penyelesaian seluruh roadmap sebelum pemeriksaan manual, 20 Oktober 2026:** pengguna meminta seluruh fungsi yang tercantum di plan sudah tersedia sebelum ia memeriksa aplikasi secara manual. Dicatat sebagai `DEC-026`. Ini memperluas target implementasi melewati Product MVP yang disetujui; tidak mengubah requirement source/status, tidak memberi izin menambah fitur di luar plan, dan tidak menghapus gate keamanan data atau rilis.
- **K1 — Repository dan checkpoint:** dasar dokumentasi awal `3c668f25e39854ec8d6ba544453e2fa7e6bd74cd`; C1 dipublikasikan sebagai `7e268be9b3230675fccc34ff06e038f6651c149f`; TASK-D-002 dipublikasikan sebagai `dc8ea7dfe4bfe086e69b09a0ce6239f89b9573a4` dan remote `main` diverifikasi menunjuk SHA tersebut pada 20 Oktober 2026. Status publikasi governance dan CI dicatat di `PROGRESS.md`.
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
| D | Planning yang dapat dipakai | C1; keputusan navigasi UI | Alur membuat dan melihat rencana, kegiatan, jadwal, serta Objective bersama lintas Plan — `REQ-PLN-004`, `REQ-OBJ-001`; pilihan bahasa mengikuti `REQ-UI-001` |
| E | Perintah operasional | C1, spesifikasi publikasi, koreksi, dan keluaran dokumen | Perintah Induk hybrid serta Perintah Harian dengan versi, snapshot, dan representasi dokumen — `REQ-CMD-001..007` |
| F | Pelaksanaan | C1, spesifikasi status pelaksanaan | Pencatatan manual satu kali per occurrence dan melihat waktunya dicatat; evaluasi tetap tahap G — `REQ-EXE-001..002` |
| G | Evaluasi | F, rubrik dan formula yang ditetapkan | Penilaian manual/otomatis dan penjelasannya dapat ditelusuri; data kurang dan sejarah koreksi terjaga — `REQ-EVA-001..005` |
| H | Impor planning terstruktur | Skema domain yang akan diimpor stabil | JSON divalidasi, ditinjau pengguna, dan diimpor tanpa perubahan parsial — `REQ-IMP-001` |
| I | Pengelolaan dokumen | Kebijakan berkas dan ekstraksi | Dokumen lokal dapat dikelola; ekstraksi serta OCR punya batas yang jelas — `REQ-DOC-001` |
| J | Pencarian | I dan/atau domain yang hendak dicari | Pencarian terstruktur, teks penuh, dan semantik multilingual lokal; model dipilih setelah lisensi, ukuran, biaya sumber daya, dan relevansi diverifikasi — `REQ-SRC-001..002` |
| K | Penguatan produk | Berlaku lintas tahap; gate rilis setelah fitur terpilih | Peningkatan skema, pemulihan data, responsivitas, dan distribusi terverifikasi — `REQ-REL-001..002` |

Istilah lama **C2 = E**, **C3 = F**, dan **C4 = G**. **C1** tetap berarti model dan persistence dasar, sehingga kelulusannya tidak berarti seluruh Planning System atau UI selesai. F dapat berjalan tanpa E; urutan E/F dapat ditukar setelah prioritas pengguna jelas. H/I tidak wajib menunggu seluruh G. Perlindungan data berlaku sejak B, bukan baru pada K.

## Strategi rilis

### Technical Alpha — WF-01 disetujui, kesiapan rilis belum diverifikasi

Cakupan planning dan penjadwalan lokal yang pada v0.2 disebut Candidate MVP awalnya dicatat sebagai usulan asisten (A2). Pengguna menyetujui cakupan Technical Alpha terbatas pada **WF-01**, termasuk verifikasi UI offline (U8/DEC-022), guna memvalidasi fondasi teknis dan alur UI dasar. Implementasi D-001 dan D-002 tersedia; alur WF-01 termasuk penautan Activity yang sudah ada ke Plan lain telah diperiksa melalui UI offline (EV-UI-005 di `PROGRESS.md`) dan diterima untuk scope WF-01 saja (DEC-023). Persetujuan Product MVP yang terpisah tercatat di U11/DEC-025. Persetujuan scope tidak menetapkan distribusi atau kesiapan penggunaan rutin data pribadi penting.

| Cakupan kandidat | Acuan dan batas |
| --- | --- |
| Alur WF-01 saja: membuat Plan dan Activity, menghubungkan keduanya, membuat occurrence secara eksplisit, lalu melihat data planning kembali | `REQ-PLN-001..004`, `REQ-SCH-001..002`; bukan keputusan untuk menambah Objective atau planning bertingkat |
| Kondisi kosong, validasi input, kegagalan simpan/baca yang terlihat, dan data tetap tersedia setelah aplikasi dibuka ulang | `REQ-PLN-004`, `REQ-DAT-001..002`; kegagalan tidak ditampilkan sebagai sukses atau hasil kosong |
| Penggunaan lokal tanpa jaringan setelah aplikasi dan dependensinya tersedia, diverifikasi melalui UI | `REQ-DAT-003`; persistence checks saja tidak cukup |
| UI mendukung English dan Bahasa Indonesia melalui pilihan manual pada Settings; pilihan tersimpan dan tidak mengubah konten | `REQ-UI-001`; implementasi ini diterima bersama TASK-D-001 untuk scope Plan. TASK-D-002 acceptance melalui DEC-021 terpisah |
| Rekomendasi batas operasional untuk evaluasi awal: data uji/non-kritis; penggunaan rutin data pribadi penting menunggu strategi backup, restore, dan upgrade yang sudah diuji | `REQ-REL-001`; rekomendasi ini konservatif untuk evaluasi lokal dan tidak menetapkan kebijakan produk/distribusi |
| Aplikasi dapat dijalankan secara lokal untuk evaluasi sesuai cara distribusi yang dipilih | `REQ-FND-001`, `REQ-REL-002`; signing, notarization, target kinerja, dan Product MVP tidak termasuk dalam persetujuan scope ini |

**Rekomendasi operasional sementara untuk evaluasi lokal — bukan keputusan produk atau distribusi:** gunakan hanya data uji/non-kritis di komputer lokal, pada bundle verifikasi sementara yang mempunyai lokasi database dan preferensi terisolasi; bersihkan setelah pemeriksaan. Ini mengikuti batas DEC-022 dan pola uji WF-01 yang telah berhasil. Bundle `dist/Minority.app` memakai path database tetap `~/Library/Application Support/Minority/minority.sqlite`, sehingga bundle ID lain saja tidak mengisolasi database. Cara sementara ini tidak mengizinkan distribusi publik atau penggunaan data penting, dan tidak menyelesaikan OPEN-008.

**Di luar Technical Alpha WF-01:** Perintah Induk/Harian, pelaksanaan, evaluasi, impor, dokumen/OCR, pencarian, Objective, prioritas terurut, pengulangan jadwal, kebijakan koreksi/hapus, distribusi publik, dan penggunaan rutin data pribadi penting. Scope WF-01 diterima melalui DEC-023 dan pemeriksaan UI offline lulus (EV-UI-005). Kesiapan rilis masih menunggu penilaian kinerja dasar, keputusan distribusi, backup/restore, dan batas terkait OPEN-008.

**TASK-D-001 — pembuatan dan daftar Plan:** pengguna secara langsung meminta slice ini, menggunakan `PlanningRepository` yang ada serta pengaturan bahasa pada Settings. Kriteria selesai: Plan valid dapat dibuat dan ditampilkan setelah aplikasi dibuka ulang; input judul/tanggal yang tidak valid dapat diperbaiki; keadaan kosong dibedakan dari kegagalan baca; kegagalan simpan tidak ditampilkan sebagai sukses; pengguna dapat memilih English/Bahasa Indonesia secara manual, pilihan bertahan setelah peluncuran ulang, dan konten buatan pengguna tidak berubah; tidak ada migration atau dependensi baru tanpa kebutuhan yang ditemukan. Navigasi untuk slice ini diputuskan terbatas melalui U6/DEC-019. Otorisasi task tidak menerima kandidat Technical Alpha atau Product MVP dan tidak mencakup edit/hapus.

Keputusan bahasa untuk TASK-D-001 sudah CONFIRMED melalui U5; pola navigasi minimum TASK-D-001 diputuskan melalui U6. Scope Technical Alpha WF-01 disetujui melalui U8/DEC-022; kesiapan rilis belum diverifikasi. Kebijakan edit/hapus dikecualikan dari scope ini dan harus diputuskan sebelum cakupan alpha yang lebih luas diterima. Implementasi juga memeriksa kemampuan baca daftar pada repository dan menambahkannya hanya karena alur ini memerlukannya.

**TASK-D-003 — Objective bersama lintas Plan:** Objective memiliki satu identitas master yang dapat ditautkan ke beberapa Plan. Pengguna dapat membuat Objective dari pustaka, menautkannya ke Plan, mengubah judul/rincian yang sama untuk semua Plan, dan melepas tautan tanpa menghapus master. Penghapusan hanya tersedia setelah seluruh tautan dilepas; constraint database tetap mencegah penghapusan selama masih tertaut. Kebijakan ini adalah pilihan implementasi asisten DEC-027 berstatus RECORDED, bukan keputusan produk CONFIRMED. Verifikasi persistence mencakup constraint, duplikasi tautan, rollback, pembukaan ulang, dan upgrade dari database planning yang sudah berisi data; UI terisolasi memeriksa pembuatan, tautan ke dua Plan, perubahan master, serta persistensi sesudah aplikasi dibuka ulang.

### Product MVP — cakupan disetujui, hasil belum selesai

Product MVP adalah produk Minority terkecil yang berguna bagi pengguna. Pengguna menyetujui cakupan berikut pada 20 Oktober 2026 (U11/DEC-025): satu alur lokal dari membuat Plan, membuat atau memakai Activity yang ditautkan, menjadwalkan occurrence satu kali secara eksplisit, mencatat secara manual satu pelaksanaan untuk occurrence tersebut, lalu melihat kembali rencana, jadwal, dan catatan setelah aplikasi dibuka ulang. Alur inti harus menampilkan validasi/kegagalan dengan jelas dan bekerja offline setelah aplikasi tersedia. Bahasa UI mengikuti pilihan manual English/Bahasa Indonesia yang telah dikonfirmasi.

Persetujuan ini adalah persetujuan **cakupan**, bukan penerimaan implementasi atau kesiapan rilis. Catatan pelaksanaan awal menyimpan waktu pencatatan, bukan waktu kejadian; ketiadaan catatan bukan kegagalan. Kebijakan koreksi/penghapusan catatan belum disepakati dan keterbatasan implementasi harus tetap terlihat. `REQ-PLN-004` yang lebih luas tetap PROPOSED; requirement berstatus RECORDED tidak otomatis berubah menjadi CONFIRMED hanya karena masuk cakupan MVP.

**Ditunda dari Product MVP:** Perintah Induk/Harian, Objective, evaluasi/skor/rule engine, jadwal berulang, prioritas berurutan, impor JSON, dokumen/OCR, dan pencarian. Item tersebut dapat dipilih untuk Extended Releases melalui roadmap; tidak otomatis wajib pada rilis pertama.

### Extended Releases — pemilihan melalui roadmap

Objective, planning lanjutan, Perintah Induk/Harian, evaluasi, impor JSON, dokumen/OCR, dan pencarian tetap dikecualikan dari Product MVP yang disetujui DEC-025. Namun, atas otorisasi pengguna U12/DEC-026, semua kemampuan yang sudah tercantum dalam roadmap D–J serta penguatan K kini termasuk target implementasi sebelum pemeriksaan manual akhir. Urutkan berdasarkan dependensi dan risiko; jangan menambah fitur di luar plan. Persetujuan target implementasi tidak mengubah status requirement, menyatakan hasil diterima, atau mengizinkan distribusi publik.

### Release Acceptance Criteria — usulan gerbang penerimaan

- Jenis rilis, cakupan yang dipilih, dan keputusan yang memengaruhinya dinyatakan jelas; cakupan Product MVP yang disetujui tercatat di DEC-025 dan harus mempunyai bukti untuk acceptance criteria terkait.
- Technical Alpha memvalidasi WF-01 melalui UI sesuai cakupan yang dipilih, termasuk masukan salah, kondisi kosong, kegagalan, dan pembukaan ulang aplikasi. Product MVP memvalidasi seluruh alur yang masuk cakupan persetujuannya.
- Fungsi offline UI diuji melalui interaksi aplikasi tanpa jaringan pada alur yang dirilis. SQLite persistence checks membuktikan perilaku penyimpanan yang diuji dan tidak secara mandiri membuktikan UI offline. Gerbang data penting tetap berlaku; backup harus benar-benar dapat dipulihkan.
- Kinerja UI dasar, startup, dan operasi database dasar dinilai dengan beban serta kriteria tersendiri melalui OPEN-008. Kinerja pencarian semantik memiliki kriteria terpisah melalui OPEN-007 dan REQ-SRC-002; target numerik keduanya belum ditetapkan.
- Build serta pemeriksaan persistence lulus pada versi yang akan dirilis; hasil UI, packaging/signing yang relevan, dan hasil GitHub Actions dicatat terpisah. CI disebut lulus setelah ada run berhasil yang menunjuk commit terkait.
- Pengguna menerima hasil dan keterbatasan rilis. Versi sumber diidentifikasi dengan commit, status publikasi, dan bukti pemeriksaan; tidak ada klaim selesai berdasarkan daftar file saja.

Keputusan detail yang masih terbuka mencakup kebijakan koreksi/hapus, klasifikasi/rubrik/formula evaluasi, format dan penerbitan dokumen perintah, skema impor, pengelolaan berkas/OCR, model dan kinerja pencarian, navigasi, backup/restore, distribusi, serta tenggat. U12/DEC-026 mengizinkan penyelesaian semua kemampuan roadmap yang sudah tercatat; detail dipilih dengan pendekatan lokal, aman, dan dapat ditelusuri sesuai requirement, lalu dicatat sebelum implementasi yang bergantung padanya. Product MVP tetap sub-cakupan tersendiri; penerimaan fitur dan kesiapan rilis tetap dilacak terpisah. Rujuk OPEN-001..008 dalam `DECISIONS.md`.

## Peta alur produk

Langkah serta acuan requirement setiap alur disimpan sekali di [End-to-End User Workflows](REQUIREMENTS.md#end-to-end-user-workflows). Implementasi seluruh alur yang tercantum kini diotorisasi secara eksplisit melalui U12/DEC-026; tiap alur tetap harus memenuhi requirement, batas data, dan pemeriksaan yang relevan.

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

TASK-D-002 diterima pengguna untuk slice membuat Activity, menghubungkannya ke Plan, dan menjadwalkan occurrence non-berulang. Technical Alpha WF-01 telah disetujui, diimplementasikan, diverifikasi, dan diterima pengguna untuk scope tersebut (DEC-022/023); penerimaan itu sendiri tidak menetapkan Product MVP. Cakupan Product MVP kemudian disetujui secara terpisah melalui DEC-025; implementasi dan penerimaannya masih berjalan, dan kesiapan rilis menunggu gerbang OPEN-008. Jangan membuat seluruh tabel rancangan lama atau memilih model embedding hanya karena tercantum dalam roadmap.

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

Kesiapan rilis fungsional dinilai dari cakupan yang disetujui, alur yang benar-benar dapat dipakai, integritas data, dan pemeriksaan yang tercatat. Cakupan Product MVP disetujui melalui DEC-025, tetapi implementasi, penerimaan, dan kesiapan rilisnya belum selesai. Pembagian Extended Releases dan tenggat masih terbuka.

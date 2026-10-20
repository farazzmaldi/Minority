# Minority — kebutuhan dan kriteria penerimaan

Gunakan definisi sumber dan status dalam [masterplan](MASTERPLAN.md). `RECORDED` mempertahankan substansi riwayat tanpa mengarang persetujuan pengguna. Status kode, hasil tes, dan commit berada di [progres](PROGRESS.md).

Kolom status hanya memakai `CONFIRMED`, `RECORDED`, `PROPOSED`, atau `OPEN`. Kode yang sudah tersedia tidak menaikkan status persetujuan kebutuhan. Rincian yang belum diputuskan disebut dalam kriteria atau catatan; kondisi implementasinya tetap berada di progres.

## Tata kelola dan fondasi

| ID | Kebutuhan | Kriteria penerimaan | Dasar; status |
| --- | --- | --- | --- |
| REQ-GOV-001 | Masterplan dan tracking permanen | Visi, tahap, dependensi, kebutuhan, keputusan terbuka, bukti, dan commit dapat ditemukan melalui dokumen proyek | U1; CONFIRMED |
| REQ-GOV-002 | Perubahan kode terarah dan mudah dirawat | Perubahan mempunyai tujuan; penggunaan ulang diperiksa; dependensi dan abstraksi baru mempunyai alasan; kode sementara dari tugas dibersihkan | U1; CONFIRMED |
| REQ-GOV-003 | Implementasi dapat ditelusuri | Tugas menunjuk requirement, keputusan, acceptance criteria, hasil pemeriksaan, serta commit atau status belum di-commit | U1; CONFIRMED |
| REQ-UI-001 | Antarmuka tersedia dalam English dan Bahasa Indonesia dengan pilihan pengguna | Pengguna memilih bahasa secara manual melalui Minority Settings; aplikasi menyimpan pilihan dan menggunakannya setelah peluncuran berikutnya; bahasa UI tidak mengikuti bahasa sistem macOS otomatis; mengubah bahasa tidak mengubah konten yang dibuat pengguna | U5/DEC-018; CONFIRMED |
| REQ-FND-001 | Aplikasi native macOS | Package mendukung macOS 15+; aplikasi dapat dibangun; startup menampilkan hasil inisialisasi atau kegagalan yang dapat dipahami | K1/H1; RECORDED |
| REQ-DAT-001 | Penyimpanan lokal dan migrasi yang menjaga data | Pembukaan database berulang tidak menggandakan migrasi; data bertahan saat dibuka kembali; gagal migrasi tidak memicu reset otomatis | K1/H1; RECORDED |
| REQ-DAT-002 | Integritas relasi dan operasi | Masukan diparameterkan; foreign key dan keunikan ditegakkan; transaksi yang gagal tidak meninggalkan perubahan parsial | K1/H1; RECORDED |
| REQ-DAT-003 | Fungsi inti offline | Setelah aplikasi dan dependensi tersedia, startup serta alur inti yang dirilis dapat dipakai tanpa jaringan dan data tetap dapat dibuka; verifikasi dilakukan melalui UI tanpa jaringan, termasuk interaksi dan pembukaan ulang pada cakupan rilis; SQLite persistence checks saja tidak membuktikan UI offline; kebutuhan unduhan saat build/setup dijelaskan terpisah | K1/H1, diperjelas A2; RECORDED |

Requirement fondasi yang teramati pada kode tetap diberi sumber K1; bukti implementasi dan verifikasinya merujuk tahap A/B/C1 di `PROGRESS.md`.

## Planning dan jadwal

| ID | Kebutuhan | Kriteria penerimaan | Dasar; status |
| --- | --- | --- | --- |
| REQ-PLN-001 | Plan memiliki identitas, judul, dan rentang tanggal | Identitas tetap saat dibuka kembali; judul kosong, tanggal tidak valid, dan rentang terbalik ditolak | K1/H1; RECORDED |
| REQ-PLN-002 | Activity adalah satu master kegiatan | Activity tersimpan mandiri dan tidak disalin hanya karena dipakai oleh rencana atau jadwal lain | K1/H1; RECORDED |
| REQ-PLN-003 | Plan dan Activity memiliki relasi banyak ke banyak | Satu Activity dapat terhubung ke beberapa Plan; pasangan sama ditolak; target yang tidak ada ditolak | K1/H1; RECORDED |
| REQ-PLN-004 | Pengguna dapat membuat dan melihat data planning | Melalui UI, pengguna dapat membuat Plan dan Activity, menghubungkannya, menjadwalkan serta melihat hasilnya, dan membukanya kembali setelah restart; input salah dapat diperbaiki; kondisi kosong dibedakan dari error; gagal simpan tidak ditampilkan sebagai sukses atau merusak data lama | Usulan alur fungsional; PROPOSED |
| REQ-OBJ-001 | Objective dapat digunakan beberapa Plan | Sasaran yang sama berbagi satu identitas master di beberapa rencana; perubahan judul/rincian berlaku pada semua tautan; melepas tautan tidak menghapus Objective; penghapusan hanya tersedia setelah seluruh tautan dilepas dan ditolak oleh database jika masih tertaut | H1; RECORDED; perilaku implementasi tercatat pada DEC-027 |
| REQ-SCH-001 | Penjadwalan selalu eksplisit | Membuat Activity atau menghubungkannya ke Plan tidak menghasilkan jadwal; satu Activity dapat memiliki beberapa occurrence dengan ID berbeda | K1/H1; RECORDED |
| REQ-SCH-002 | Occurrence menyimpan tanggal serta jam dan prioritas operasional opsional | Tanggal valid wajib; kedua jam diisi bersama atau dikosongkan; untuk batas C1, jam selesai sesudah jam mulai pada tanggal sama; prioritas tersimpan pada occurrence; skala prioritas masih OPEN-002 | K1/H1; RECORDED |
| REQ-SCH-003 | Koreksi jadwal menjaga identitas pekerjaan yang sama | Koreksi occurrence mempertahankan ID; sesi tambahan membuat ID baru; setelah publikasi, perubahan tidak menulis ulang snapshot dan revisi tanggal asal/tujuan ditangani eksplisit | H1; RECORDED |

Skala prioritas, pengulangan, konflik jadwal, zona waktu, jadwal lintas hari, hierarki Plan tahunan/bulanan, serta edit dan hapus belum terspesifikasi. Batas satu tanggal dalam C1 bukan keputusan untuk semua penjadwalan masa depan.

## Perintah operasional

| ID | Kebutuhan | Kriteria penerimaan | Dasar; status |
| --- | --- | --- | --- |
| REQ-CMD-001 | Perintah Induk memakai model hybrid | Perintah Induk berfungsi sebagai dokumen komando formal sekaligus pengendali kegiatan operasional; rincian target mengikuti REQ-CMD-007 dengan status tersendiri | U2; CONFIRMED |
| REQ-CMD-002 | Perintah Harian mengambil occurrence yang sudah terjadwal | Item hanya berasal dari occurrence untuk tanggal perintah; generasi perintah tidak menciptakan jadwal; ID occurrence tersimpan dalam item | H1; RECORDED |
| REQ-CMD-003 | Hubungan item dengan Perintah Induk eksplisit dan opsional | Setiap item dapat tanpa induk atau menunjuk versi induk yang telah diterbitkan; tidak disimpulkan dari Plan, Activity, atau keanggotaan target; beberapa induk dapat muncul dalam satu perintah harian | H1; RECORDED |
| REQ-CMD-004 | Identitas perintah dan versi terpisah | Maksimal satu identitas logis Perintah Harian per tanggal, tanpa kewajiban penerbitan setiap hari; koreksi menghasilkan versi baru dan penggantian versi berlangsung konsisten | H1; RECORDED |
| REQ-CMD-005 | Publikasi mempertahankan sejarah | Konten dan snapshot versi terbit tidak diubah di tempat; judul, rincian, tanggal/jam, klasifikasi, prioritas, urutan, serta target yang relevan disimpan; perubahan sumber tidak menulis ulang sejarah | H1; RECORDED |
| REQ-CMD-006 | Representasi dan keluaran dokumen perintah | Pengguna dapat meninjau representasi dokumen dan versi yang dipilih, lalu mencetak atau mengekspor PDF dari snapshot versi tersebut; template lokal yang sama digunakan untuk pratinjau/cetak/PDF; kegagalan keluaran tidak mengubah riwayat | A1 P1-03; RECORDED melalui DEC-028, belum CONFIRMED |
| REQ-CMD-007 | Target operasional Perintah Induk bersifat opsional dan merujuk data yang ada | Dokumen dapat berdiri tanpa target atau merujuk Plan, Activity, dan Objective yang sudah ada; referensi tidak membuat, menggandakan, atau mengambil kepemilikan master kegiatan | H1; RECORDED |

REQ-CMD-001 mempertahankan makna pilihan hybrid. Rincian target yang sebelumnya tercampur di kriterianya dipisahkan ke REQ-CMD-007 agar konfirmasi model tidak sekaligus mengonfirmasi aturan target. REQ-CMD-002..005 tetap RECORDED.

Format, penomoran, draft, penarikan publikasi, perubahan tanggal, dan transaksi publikasi memiliki baseline implementasi tercatat pada DEC-028. Status versi dapat menunjuk versi pengganti; konten historis tetap terlindungi. Detail itu belum CONFIRMED oleh pengguna dan dapat direvisi berdasarkan bukti implementasi tanpa menulis ulang sejarah.

## Pelaksanaan dan evaluasi

| ID | Kebutuhan | Kriteria penerimaan | Dasar; status |
| --- | --- | --- | --- |
| REQ-EXE-001 | Satu catatan pelaksanaan otoritatif per occurrence | Keunikan occurrence ditegakkan; pencatatan dapat dimulai tanpa Perintah Harian; revisi dan penghapusan item versi berikutnya tidak menggandakan atau menghapus catatan pelaksanaan | H1, penyesuaian atas proposal awal; RECORDED |
| REQ-EXE-002 | Evaluasi mengikuti identitas pelaksanaan yang stabil | Evaluasi merujuk execution record, sehingga perubahan versi perintah tidak membuat evaluasi baru atau yatim | H1; RECORDED |
| REQ-EVA-001 | Evaluasi menggunakan klasifikasi dan rubrik berversi | Kriteria dan versi rubrik yang dipakai dapat ditelusuri; perubahan rubrik tidak mengganti dasar penilaian historis | H1; RECORDED |
| REQ-EVA-002 | Data yang belum dinilai tetap dinyatakan kurang | Input hilang tidak diubah menjadi nilai buatan; agregat ditandai belum lengkap jika input wajib belum tersedia | H1; RECORDED |
| REQ-EVA-003 | Hasil final mempunyai riwayat koreksi | Koreksi penilaian final menyimpan versi atau audit koreksi; hasil lama tidak ditimpa diam-diam | H1; RECORDED |
| REQ-EVA-004 | Batas penilaian manual dan otomatis terlihat | Spesifikasi menetapkan input yang diisi pengguna, hasil yang boleh dihitung otomatis, serta kewenangan koreksi; UI membedakan nilai manual, hasil perhitungan, dan data kurang; input wajib yang hilang tidak menghasilkan nilai otomatis buatan; koreksi mengikuti REQ-EVA-003 | A1 P1-03; PROPOSED |
| REQ-EVA-005 | Dasar penilaian, agregasi, dan rekomendasi dapat dijelaskan | Hasil menunjukkan input/bukti, aturan serta versi rubrik yang dipakai, kontribusi kriteria, dan kelengkapan data; rekomendasi bila tersedia menyebut aturan serta pemicunya; pengguna dapat menelusuri hasil tanpa menebak formula atau nilai yang disembunyikan | A1 P1-03; PROPOSED |

Status pelaksanaan, dimensi completion/timeliness/quality, skala kualitas 0–100, bobot prioritas, formula agregasi, dan batas penilaian otomatis disebut dalam riwayat tetapi belum cukup rinci untuk implementasi. Jangan memilih formula atau angka bobot sendiri.

## Impor, dokumen, pencarian, dan kesiapan produk

| ID | Kebutuhan | Kriteria penerimaan sebelum dinyatakan selesai | Dasar; status |
| --- | --- | --- | --- |
| REQ-IMP-001 | Impor JSON planning dengan pemeriksaan pengguna | Skema, ID, tanggal, relasi, duplikasi, dan input salah divalidasi; ada preview dan persetujuan pengguna; kegagalan tidak menyisakan impor parsial; pemakaian dasar tidak memerlukan API berbayar; skema dan kebijakan duplikasi masih OPEN-005 | H1; RECORDED |
| REQ-DOC-001 | Pengelolaan dokumen pribadi serta ekstraksi/OCR | Baseline PDF/gambar disalin ke penyimpanan lokal; PDF berteskstrak diekstrak langsung dan PDF scan/gambar memakai OCR on-device; teks ekstraksi ditampilkan terpisah dari berkas asli; error terlihat; Sampah dapat dipulihkan. Penghapusan permanen, enkripsi, dan kontrol keamanan tambahan masih OPEN-006 | H1/README; DEC-031; RECORDED |
| REQ-SRC-001 | Pencarian data serta teks lokal | Cakupan sumber, perilaku pencocokan, hasil, dan kasus tanpa hasil ditetapkan; perubahan atau penghapusan sumber tercermin di indeks; detail masih OPEN-007 | H1; RECORDED |
| REQ-SRC-002 | Pencarian semantik multilingual lokal | Baseline Apple NaturalLanguage contextual embeddings untuk English/Bahasa Indonesia tercatat pada DEC-032; indeks/kueri lokal dan fallback teks tersedia. Relevansi dataset, ketentuan aset OS, ukuran unduhan, memori, dan waktu indeks/kueri masih perlu dinilai pada OPEN-007 sebelum penerimaan | H1; DEC-032; RECORDED |
| REQ-REL-001 | Peningkatan dan pemulihan data aman | Paket backup/restore lokal mencakup database dan berkas dokumen, integritas divalidasi, migrasi ke skema kini dan recovery backup sebelum restore tersedia; build/persistence/UI fixture diuji. Paket plaintext tanpa retensi otomatis; lokasi, penjagaan backup, dan penerimaan untuk pemakaian data penting tetap OPEN-008 | K1/H1, diperjelas A1 P1-02; DEC-033; RECORDED |
| REQ-REL-002 | Kesiapan penggunaan dinilai terpisah dari build | Alur UI yang dirilis diperiksa; kinerja UI dasar, startup, dan operasi database dasar dinilai terhadap beban serta kriteria tersendiri yang masih OPEN-008; operasi berat tidak membekukan UI pada beban sasaran; benchmark pencarian semantik mengikuti REQ-SRC-002/OPEN-007 dan tidak menggantikan pemeriksaan kinerja dasar; bundle dan signing/distribusi diuji sesuai cara distribusinya; target numerik belum ditetapkan | H1 dan usulan gate rilis, diperjelas A2; PROPOSED |

Pengguna mengotorisasi implementasi seluruh kemampuan yang tercantum dalam roadmap melalui DEC-026. Baseline H–K tersedia pada aplikasi kanonis dan dipublikasikan bersama roadmap D–K pada `main` di commit `81aaf7f1237856facfad0cb834837c198b0c642b`; bukti build, persistence, UI, dan bundle tercatat di `docs/PROGRESS.md`. Kasus tersisa pada OPEN-005..008 tetap terbuka untuk kebijakan dan kesiapan rilis. Status RECORDED/PROPOSED bukan bukti fitur diterima; penerimaan akhir masih menunggu review manual pengguna.

## End-to-End User Workflows

Peta konseptual berikut menghubungkan hasil pengguna dengan requirement yang sama di atas. Cakupan MVP yang disetujui melalui DEC-025 memakai WF-01 ditambah pencatatan manual terbatas dari WF-03. Secara terpisah, pengguna mengotorisasi implementasi keenam workflow dalam roadmap sebelum pemeriksaan manual akhir melalui DEC-026. Status requirement RECORDED/PROPOSED/OPEN tetap seperti sumbernya; otorisasi implementasi tidak berarti semua detail telah diputuskan atau hasilnya diterima.

| ID | Langkah konseptual dan hasil pengguna | Requirement acuan |
| --- | --- | --- |
| WF-01 | Membuat Plan → membuat atau memilih Activity → menghubungkan → membuat occurrence secara eksplisit → melihat rencana/jadwal kembali setelah restart; Objective dapat dikelola dan ditautkan ke beberapa Plan tanpa duplikasi; masukan salah dan gagal simpan dapat ditangani | REQ-PLN-001..004, REQ-SCH-001..003, REQ-OBJ-001, REQ-DAT-003 |
| WF-02 | Membuat draft Perintah Induk atau memilih occurrence untuk Perintah Harian → meninjau isi/asosiasi → menerbitkan versi → melihat dokumen → merevisi tanpa mengubah sejarah; cetak/ekspor mengikuti format yang nanti dipilih | REQ-CMD-001..007 |
| WF-03 | Memilih occurrence → mulai mencatat pelaksanaan, dengan atau tanpa perintah → menyimpan dan melihat realisasi; revisi perintah memakai execution record yang sama | REQ-SCH-001, REQ-EXE-001..002 |
| WF-04 | Memilih pelaksanaan → meninjau klasifikasi/rubrik dan bukti → mengisi input manual atau meninjau hitungan otomatis yang diizinkan → membaca alasan/kelengkapan → memfinalisasi atau mengoreksi dengan riwayat | REQ-EVA-001..005, REQ-EXE-002 |
| WF-05 | Menyimpan atau mereferensikan dokumen sesuai kebijakan → membaca → mengekstrak teks/OCR bila diperlukan → mencari → membuka sumber; data tidak terbaca dan tanpa hasil ditampilkan jelas | REQ-DOC-001, REQ-SRC-001..002, REQ-REL-001 |
| WF-06 | Memasukkan JSON → memvalidasi struktur/relasi/duplikasi → meninjau preview dan masalah → menyetujui → mengimpor secara utuh → memeriksa hasil; penolakan atau gagal validasi tidak mengubah data | REQ-IMP-001, REQ-DAT-002 |

## Cara memperbarui

Pertahankan ID ketika redaksi diperjelas. Catat keputusan yang mengubah perilaku di `DECISIONS.md`, lalu sesuaikan tugas dan bukti dalam `PROGRESS.md`. Jangan menaikkan status persetujuan hanya karena kode atau tes sudah tersedia. Permintaan pengguna yang secara jelas menerima kebutuhan dapat menjadi bukti konfirmasi, dengan tanggal dan cakupan dicatat.

# Minority — keputusan dan arsitektur

Dokumen awal dicatat pada 19 Oktober 2026 dan direvisi berdasarkan audit serta finalisasi G0 pada tanggal yang sama; DEC-020..023 ditambahkan pada 20 Oktober 2026. Tanggal keputusan dalam riwayat tidak selalu tersedia; tanggal pencatatan ini bukan tanggal persetujuan. Sumber U1/U2/U3/U4/U5/U6/U7/U8/U9/K1/H1/A1/A2 dan status dijelaskan di [masterplan](MASTERPLAN.md). `OBSERVED` menunjukkan struktur aktual dalam kode, tanpa mengklaim persetujuan produk.

## Register keputusan

| ID | Keputusan atau arah yang tercatat | Alasan dan konsekuensi | Sumber; status |
| --- | --- | --- | --- |
| DEC-001 | Native macOS, SwiftUI, Swift Package Manager | Sudah menjadi fondasi proyek; target minimal macOS 15, Swift tools 6.0 | K1; OBSERVED |
| DEC-002 | Penyimpanan lokal SQLite melalui GRDB | Mendukung fungsi inti offline; tanggung jawab migrasi dan pemulihan tetap perlu dijaga | K1; OBSERVED |
| DEC-003 | Satu aplikasi dengan target aplikasi dan persistence terpisah | Batas dependensi tersedia tanpa layanan terpisah; domain belum memerlukan target tambahan | K1; OBSERVED |
| DEC-004 | Plan, Activity, relasi, dan occurrence adalah entitas berbeda | Activity tidak digandakan antar-Plan atau antar-jadwal; jadwal dibuat eksplisit dan mempunyai identitas stabil | H1, didukung kode C1; RECORDED |
| DEC-005 | Perintah Induk memakai model hybrid: dokumen komando formal sekaligus pengendali kegiatan | Pilihan kombinasi dikonfirmasi pengguna melalui kutipan U2. Rincian referensi target opsional dipisahkan ke DEC-016 dengan status tersendiri | U2; CONFIRMED |
| DEC-006 | Item Perintah Harian memiliki asosiasi induk eksplisit dan opsional | Referensi menunjuk versi terbit; keanggotaan target tidak diinferensikan atau diwajibkan; item dalam satu hari dapat memakai induk berbeda | H1; RECORDED |
| DEC-007 | Identitas perintah dipisahkan dari versi terbit | Maksimal satu identitas logis harian per tanggal; versi memelihara snapshot dan sejarah, bukan penimpaan konten lama | H1; RECORDED |
| DEC-008 | Identitas pelaksanaan ditambatkan pada occurrence | Satu execution record otoritatif; dapat dibuat tanpa perintah; revisi dokumen tidak menggandakan pelaksanaan atau evaluasi | H1, penyesuaian yang menggantikan usulan pembuatan hanya saat publikasi; RECORDED |
| DEC-009 | Prioritas operasional berada pada occurrence | Versi Perintah Harian mengambil snapshot; tidak membuat nilai prioritas lain dengan makna identik | H1, didukung kode C1; RECORDED; skala OPEN |
| DEC-010 | Koreksi jadwal pekerjaan yang sama mempertahankan identitas | Sesi tambahan membuat occurrence baru; sejarah publikasi dipertahankan dan revisi terkait harus eksplisit | H1; RECORDED |
| DEC-011 | Objective dapat dipakai beberapa Plan | Menghindari sasaran ganda hanya karena perbedaan periode | H1; RECORDED |
| DEC-012 | Rubrik berversi, data kurang tetap kurang, hasil final mempunyai sejarah koreksi | Dasar penilaian dan perubahan hasil dapat ditelusuri; formula tidak boleh dikarang | H1; RECORDED; formula OPEN |
| DEC-013 | Pengembangan dan verifikasi native dilakukan di lingkungan macOS | Source saat ini memerlukan SwiftUI dan API Apple; tidak menuntut instalasi Xcode IDE baru. Kapabilitas lingkungan lain harus diverifikasi sebelum dipakai untuk klaim build | K1/H1; OBSERVED untuk kebutuhan native, RECORDED untuk preferensi kerja lokal |
| DEC-014 | Tata kelola tertulis sebelum perluasan fitur | Setiap pekerjaan dapat ditelusuri ke kebutuhan, kriteria, dan bukti; dokumentasi dipelihara sesuai dampak perubahan | U1; CONFIRMED |
| DEC-015 | Gunakan executable persistence yang ada dan satu workflow build/persistence | Menambah pemeriksaan otomatis tanpa framework tes atau dependensi aplikasi baru; workflow memerlukan eksekusi GitHub tersendiri. Status konfigurasi dan run dicatat di progres | K1 dan rancangan G0; PROPOSED |
| DEC-016 | Referensi operasional Perintah Induk bersifat opsional dan menunjuk data yang ada | Dokumen dapat berdiri tanpa target atau merujuk Plan/Activity/Objective; referensi tidak membuat Activity baru atau menjadi pemiliknya. Ini memisahkan rincian H1 yang dahulu tercampur dalam DEC-005 | H1; RECORDED |
| DEC-017 | Interaksi pengembangan melalui Codex dalam GUI ChatGPT Desktop pada repository lokal Minority | Konfirmasi mencakup GUI Desktop, repository lokal yang sudah ada, dan tanpa kewajiban pengguna mengoperasikan Codex CLI. Batas lingkungan native tetap merujuk DEC-013 | U3; CONFIRMED |
| DEC-018 | Minority mendukung English dan Bahasa Indonesia; pengguna memilih bahasa secara manual melalui Settings, preferensi tersimpan antar-peluncuran, dan perubahan bahasa tidak mengubah konten buatan pengguna | Bahasa antarmuka tidak mengikuti bahasa sistem macOS secara otomatis. Perubahan pilihan hanya mengganti bahasa UI; data konten pengguna tetap sama | Pengguna; 19 Oktober 2026; CONFIRMED |
| DEC-019 | TASK-D-001 menampilkan daftar Plan pada jendela utama, membuat Plan melalui sheet, dan menyediakan pilihan bahasa melalui jendela Settings standar macOS | Keputusan navigasi ini terbatas pada TASK-D-001 dan tidak menetapkan navigasi fitur atau rilis lain | Pengguna; 19 Oktober 2026; CONFIRMED |
| DEC-020 | TASK-D-002 mencakup membuat Activity, menghubungkannya ke Plan yang sudah ada, lalu membuat dan melihat satu occurrence jadwal non-berulang | Persetujuan hanya untuk slice ini; tidak mencakup pengulangan, edit/hapus, Objective, Perintah, pelaksanaan, evaluasi, pencarian, prioritas berurutan, Technical Alpha, Product MVP, atau seluruh REQ-PLN-004 | Pengguna; jawaban langsung “lanjut” atas usulan scope; 20 Oktober 2026; CONFIRMED |
| DEC-021 | Pengguna menerima implementasi TASK-D-002 untuk scope Activity yang ditautkan ke Plan dan occurrence jadwal satu kali | Penerimaan mencakup slice D-002 yang telah diverifikasi dan tidak mengubahnya menjadi penerimaan seluruh REQ-PLN-004 atau Product MVP | Pengguna; jawaban langsung “anggap aja aku setuju” atas permintaan penerimaan D-002; 20 Oktober 2026; CONFIRMED |
| DEC-022 | Cakupan Technical Alpha berikutnya disetujui terbatas pada WF-01 planning dan jadwal, termasuk verifikasi UI offline | Mencakup Plan, Activity yang tertaut, occurrence eksplisit satu kali, alur UI dan kondisi gagal, persistensi, serta verifikasi offline yang kemudian dicatat pada EV-UI-004/005. Tidak menyetujui Objective, perintah, pelaksanaan, evaluasi, dokumen, pencarian, pengulangan, edit/hapus, Product MVP, distribusi publik, atau penggunaan rutin data pribadi penting | Pengguna; jawaban langsung “anggap aja aku setuju” atas brief penerimaan D-002 dan scope WF-01; 20 Oktober 2026; CONFIRMED |
| DEC-023 | Pengguna menerima hasil implementasi dan verifikasi WF-01 untuk cakupan terbatas yang disetujui melalui DEC-022 | Penerimaan meliputi alur Plan, Activity, penautan Activity yang sudah ada, occurrence satu kali yang eksplisit, persistensi, kondisi gagal, dan pemeriksaan UI offline yang tercatat. Ini tidak menyatakan Technical Alpha siap rilis, tidak menyetujui Product MVP, dan tidak mengubah status seluruh REQ-PLN-004 | Pengguna; instruksi langsung untuk mencatat penerimaan WF-01 setelah memverifikasi ulang bukti; 20 Oktober 2026; CONFIRMED |

## Bukti dan batas konfirmasi

Ringkasan berikut cukup untuk memahami sumber keputusan tanpa menyalin transkrip pribadi. DEC-001..019 dicatat pada 19 Oktober 2026; DEC-020..023 dicatat pada 20 Oktober 2026. Tanggal ucapan asli yang tidak tersedia tidak direkonstruksi.

| Keputusan | Pelaku dan bukti yang tersedia | Cakupan dan batas |
| --- | --- | --- |
| DEC-001..003; kebutuhan native pada DEC-013 | Pilihan implementasi diamati dalam `Package.swift`, `MinorityApp.swift`, dan `DatabaseManager.swift`; baseline commit A `3fabb98`, B `2975781`, serta README `3c668f2` | Membuktikan pilihan teknis yang tersedia pada kode, bukan ucapan persetujuan produk oleh pengguna |
| DEC-005 | **Pengguna**, kutipan “Model kombinasi keduanya.” yang disampaikan kembali melalui audit G0 bagian P0-02 (U2) | Konteks pilihan dokumen komando formal dan pengendali kegiatan. Mengonfirmasi hybrid saja; tanggal ucapan asli tidak tersedia. REQ-CMD-001 mengikuti cakupan ini |
| DEC-004/006/007/009/010/011/012/016 | **Asisten/arsitek dalam H1**, ringkasan proposal domain hybrid, empat keputusan lanjutan, dan penyesuaian; tidak tersedia kutipan pengguna yang mengonfirmasi masing-masing rincian tersebut | Identitas, relasi target, versi, prioritas, rescheduling, Objective, dan evaluasi tetap RECORDED. Kode C1 mendukung pengamatan sebagian relasi, tanpa menaikkan status persetujuan |
| DEC-008 | **Asisten/arsitek dalam H1**, penyesuaian proposal agar execution dapat dibuat saat pencatatan tanpa publikasi perintah | Menggantikan usulan awal yang membatasi inisialisasi execution pada publikasi; tetap RECORDED, bukan pilihan pengguna yang diasumsikan |
| DEC-014 | **Pengguna**, permintaan langsung agar proyek rapi dan keberatan tentang belum adanya masterplan tertulis serta tracking (U1) | Mengonfirmasi kebutuhan tata kelola; tidak sekaligus menerima seluruh roadmap atau MVP |
| DEC-015 | **Agen pada G0 awal**, usulan memakai pemeriksaan persistence yang tersedia dan satu workflow; A1 meminta desain CI minimal dipertahankan | Revisi mempertahankan konfigurasi. Penerimaan baseline dan keberhasilan run tetap dicatat terpisah; tidak ada bukti run GitHub berhasil |
| DEC-017 | **Pengguna**, kutipan “untuk selanjutnya setelah ini aku gak mau jalankan codex di terminal” dan “aku mau pakai codex dari gpt dekstop”, dengan cakupan U3 ditegaskan kembali pada finalisasi 19 Oktober 2026 | CONFIRMED hanya untuk GUI Desktop, repository lokal yang sudah ada, dan tanpa kewajiban mengoperasikan Codex CLI. Penilaian audit dan klasifikasi rilis berasal dari asisten (A2); otorisasi publikasi terpisah melalui U4 |
| DEC-018 | **Pengguna**, pilihan bahasa manual English/Bahasa Indonesia melalui Settings (U5) | Pilihan tersimpan; UI tidak mengikuti bahasa macOS otomatis; konten buatan pengguna tidak berubah |
| DEC-019 | **Pengguna**, jawaban langsung memilih daftar Plan, sheet tambah, dan Settings standar macOS untuk TASK-D-001 (U6) | Konfirmasi hanya menetapkan navigasi minimum untuk slice TASK-D-001; tidak menerima Technical Alpha atau Product MVP |
| DEC-020 | **Pengguna**, jawaban langsung “lanjut” setelah usulan Activity → hubungkan ke Plan → jadwalkan satu kali | Scope implementasi hanya TASK-D-002 sebagaimana diuraikan pada register; pemilihan navigasi rinci tetap keputusan implementasi lokal dan bukan persetujuan Technical Alpha, Product MVP, atau keseluruhan REQ-PLN-004 |
| DEC-021 | **Pengguna**, jawaban langsung “anggap aja aku setuju” setelah ditanya apakah menerima TASK-D-002 | Menerima hanya implementasi slice D-002 yang dilaporkan dan diperiksa; tidak menyatakan pemeriksaan offline D-002, distribusi publik, atau penerimaan Product MVP |
| DEC-022 | **Pengguna**, jawaban langsung “anggap aja aku setuju” setelah diberi rekomendasi scope WF-01 sebagai pekerjaan berikutnya, termasuk offline UI | Mengotorisasi scope Technical Alpha terbatas WF-01 dan verifikasi offline. Pemeriksaan UI offline WF-01 tercatat lulus pada EV-UI-004/005; kesiapan rilis masih menunggu kriteria kinerja, distribusi, backup/restore, dan keputusan OPEN-008 |
| DEC-023 | **Pengguna**, instruksi langsung pada 20 Oktober 2026 untuk mencatat penerimaan WF-01 setelah memeriksa ulang bukti | Menerima hasil WF-01 saja. Tidak menyatakan Technical Alpha siap rilis, tidak menyetujui Product MVP, dan tidak menaikkan status seluruh REQ-PLN-004 |

Eksekusi perintah build/test internal mengikuti instruksi tugas dan aturan pemeriksaan; kebutuhan verifikasi native lokal mengikuti DEC-013. Keduanya tidak memperluas cakupan konfirmasi U3 menjadi persetujuan desain produk. Klasifikasi rilis pada masterplan merupakan usulan A2; pilihan cakupan tetap OPEN/PROPOSED sampai diterima pengguna.

Pemisahan DEC-005/016 serta REQ-CMD-001/007 mempertahankan substansi model lama sekaligus memperjelas batas persetujuannya. DEC-006..012 tidak dinaikkan menjadi CONFIRMED. Tidak ada tanggal, identitas pribadi, atau persetujuan tambahan yang disimpulkan dari gaya bahasa jawaban asisten.

Alternatif yang belum dibutuhkan meliputi backend, microservices, framework state tambahan, container dependensi, target domain terpisah, dan sarana tes kedua. Pertimbangkan hanya ketika kebutuhan atau pengukuran menunjukkan manfaat yang jelas. Jangan membuatnya sebagai persiapan spekulatif.

## Keputusan yang masih terbuka

| ID | Pertanyaan | Tahap terdampak |
| --- | --- | --- |
| OPEN-001 | Hierarki Plan, pengulangan, konflik, zona waktu, lintas hari, serta kebijakan edit/hapus | D, penjadwalan lanjutan |
| OPEN-002 | Skala prioritas dan perilaku pengurutan | D/E/G |
| OPEN-003 | Format dokumen, penomoran, draft, penarikan publikasi, dan transaksi koreksi tanggal | E |
| OPEN-004 | Status pelaksanaan, input evaluasi, klasifikasi, rubrik, serta formula dan data kurang | F/G |
| OPEN-005 | Versi skema JSON, pencocokan ID, penanganan duplikasi, dan konfirmasi impor | H |
| OPEN-006 | Jenis dokumen, salinan atau referensi, hak akses, penghapusan, dan pemulihan | I |
| OPEN-007 | Cakupan pencarian, model/lisensi embeddings, dataset, serta anggaran memori/latensi pencarian dan pengindeksan; terpisah dari kinerja dasar pada OPEN-008 | J |
| OPEN-008 | Scope Product MVP/Extended Releases, navigasi di luar TASK-D-001, tenggat, distribusi, backup/restore sebelum penggunaan rutin data penting, serta beban dan kriteria kinerja UI dasar/startup/operasi database; target numerik belum ditetapkan | Kesiapan Technical Alpha WF-01 yang disetujui melalui DEC-022 masih menunggu verifikasi terkait; bahasa UI diputuskan melalui DEC-018/REQ-UI-001; navigasi TASK-D-001 terbatas diputuskan melalui DEC-019; kinerja dasar tidak menunggu fitur pencarian J |

Selesaikan pertanyaan ketika tugas bergantung padanya. Tidak perlu membuka ulang seluruh arsitektur untuk memperbaiki bagian yang sudah jelas.

## Fondasi yang sudah ada

Minority merupakan satu aplikasi macOS dengan beberapa target Swift Package Manager. Antarmuka menggunakan SwiftUI; penyimpanan memakai SQLite melalui GRDB. Fungsi database lokal tidak memerlukan layanan jaringan saat runtime.

`Package.swift` menetapkan Swift tools 6.0, minimum macOS 15, dan dependensi GRDB mulai versi 7.0.0. `Package.resolved` saat pemeriksaan mengunci GRDB 7.11.1. Perubahan versi harus tercermin pada lockfile dan diperiksa bersama.

| Lokasi | Tanggung jawab |
| --- | --- |
| `Sources/Minority/MinorityApp.swift` | Entry point, inisialisasi database, tampilan awal, dan pesan kegagalan |
| `Sources/MinorityPersistence/DatabaseManager.swift` | Lokasi database, pembukaan koneksi, dan migrasi |
| `Sources/MinorityPersistence/PlanningDomain.swift` | Model planning dan validasi; checkpoint C1 dipublikasikan pada `7e268be` |
| `Sources/MinorityPersistence/PlanningRepository.swift` | Operasi SQL planning; checkpoint C1 dipublikasikan pada `7e268be` |
| `Tests/MinorityTests/main.swift` | Executable `MinorityPersistenceChecks` dengan database sementara |
| `scripts/package-app.sh` | Build release, bundle `.app`, dan tanda tangan ad hoc |
| `.github/workflows/quality.yml` | Konfigurasi build dan pemeriksaan persistence di GitHub |

## Alur dan batas tanggung jawab

Saat ini `MinorityApp` memanggil `DatabaseManager.applicationDatabase()` saat inisialisasi dan menampilkan status berhasil atau kegagalan database. `PlanListView` menampilkan dan membuat Plan; detail Plan menampilkan Activity terkait, membuat Activity yang ditautkan ke Plan itu, menautkan Activity yang sudah ada ke Plan lain, serta membuat dan menampilkan occurrence satu kali. Alur ini belum menyediakan pengulangan atau edit/hapus, dan tidak berarti keseluruhan REQ-PLN-004 telah diterima.

Alur planning yang tersedia menggunakan SwiftUI → `PlanningRepository` → GRDB → SQLite. Tambahkan state tampilan atau koordinasi operasi hanya jika dibutuhkan oleh layar nyata. SQL tetap berada di persistence; aturan validasi data dapat dipanggil tanpa SwiftUI.

Target `Minority` bergantung pada `MinorityPersistence`. Target persistence bergantung pada GRDB dan tidak boleh bergantung balik pada aplikasi atau SwiftUI. Executable pemeriksaan menggunakan persistence dan GRDB.

Model domain saat ini berada di target persistence. Pertahankan struktur ini selama kebutuhan masih sederhana. Pemisahan target domain baru masuk akal ketika ada konsumen lain atau batas dependensi yang benar-benar perlu ditegakkan; tidak perlu memindahkan file sebagai pekerjaan kosmetik.

## Penyimpanan dan perubahan skema

Database aplikasi berada di `~/Library/Application Support/Minority/minority.sqlite`. `DatabaseManager` membuat direktori bila diperlukan, membuka `DatabaseQueue`, dan menerapkan migrasi.

Commit dasar memiliki migrasi `foundation`. Checkpoint C1 `7e268be9b3230675fccc34ff06e038f6651c149f` menambahkan `planning_v1` dengan tabel `plans`, `activities`, `plan_activities`, dan `schedule_occurrences`; commit dipublikasikan dan remote SHA diverifikasi pada 19 Oktober 2026. Publikasi source tersebut tidak menetapkan skema produk final atau kesiapan distribusi aplikasi.

Hubungan rencana dengan kegiatan memakai tabel penghubung dengan pasangan unik. Jadwal mengacu langsung pada kegiatan. SQL lokal menggunakan parameter, foreign key, serta pemeriksaan tanggal dan rentang waktu. Tinjau perilaku pembatasan dan penghapusan ini sebelum menambahkan fitur edit atau hapus.

Perubahan skema yang telah dipakai pengguna harus memiliki jalur peningkatan data. Verifikasi peningkatan dari database versi sebelumnya, bukan hanya pembuatan database kosong. Operasi yang harus berhasil bersama menggunakan transaksi. Kegagalan pembukaan atau migrasi diteruskan sebagai error; jangan mereset database untuk menutupinya.

## Keputusan desain dan alasan

| Keputusan | Alasan saat ini | Kapan ditinjau lagi |
| --- | --- | --- |
| Satu aplikasi dengan target terpisah | Batas aplikasi dan persistence sudah tersedia tanpa proses atau deployment tambahan | Ada kebutuhan komponen yang benar-benar berdiri sendiri |
| SwiftUI dan API native macOS | Sesuai platform yang sudah dipilih dalam kode | Kebutuhan platform berubah melalui keputusan produk |
| SQLite melalui GRDB | Infrastruktur lokal sudah tersedia | Kebutuhan penyimpanan nyata tidak lagi dapat dipenuhi |
| Satu `DatabaseQueue` | Cukup untuk fondasi saat ini | Ada pengukuran yang membuktikan masalah responsivitas atau konkurensi |
| Pemeriksaan persistence yang sudah ada | Memeriksa perilaku data tanpa framework tambahan | Kebutuhan isolasi, pelaporan, atau cakupan membenarkan perubahan sarana tes |

Tidak ada backend, sinkronisasi, container dependensi, event bus, atau framework state tambahan dalam fondasi sekarang. Kebutuhan baru harus menjelaskan manfaatnya sebelum menambah struktur tersebut.

## Pemeriksaan dan distribusi

Perintah dan kriteria pemeriksaan dikelola di `AGENTS.md`; panduan menjalankan aplikasi berada di `README.md`.

Workflow GitHub memakai runner macOS, membangun versi dependensi dari lockfile, lalu menjalankan `MinorityPersistenceChecks`. Status publikasi dan hasil run aktual dicatat di `PROGRESS.md`. Keberadaan workflow tidak menjamin hasilnya lulus atau menjadikannya syarat wajib merge; pengaturan branch merupakan hal terpisah.

Pengemasan saat ini menghasilkan tanda tangan ad hoc. Build dan pemeriksaan database tidak membuktikan aplikasi siap didistribusikan publik, dinotarisasi, atau telah diperiksa antarmukanya.

Nama `activity_schedules` pada proposal historis dan `schedule_occurrences` pada kode C1 mengacu pada konsep occurrence yang sama. Gunakan nama aktual kode ketika membahas skema; perbedaan nama bukan alasan membuat tabel kedua atau migrasi rename.

## Cara mengubah keputusan

Pertahankan ID dan catat pengganti jika keputusan berubah secara material. Isi minimal perubahan adalah sumber otorisasi, kebutuhan terkait, alasan, alternatif yang relevan, konsekuensi, dan tugas yang terdampak. Jangan mengubah status `RECORDED` menjadi `CONFIRMED` hanya karena pernyataan persetujuan terdapat dalam jawaban asisten lama.

Referensi konfigurasi: [instruksi proyek Codex](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [checkout untuk GitHub Actions](https://github.com/actions/checkout), dan [image runner macOS](https://github.com/actions/runner-images).

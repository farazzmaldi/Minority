# Minority — progres dan bukti

Snapshot 19 Oktober 2026, diperbarui saat finalisasi baseline G0 v0.3. Penilaian bahwa P0 telah ditangani pada tingkat dokumentasi berasal dari asisten (A2), bukan konfirmasi langsung pengguna. U3 hanya mengonfirmasi workflow GUI/repository lokal/tanpa kewajiban Codex CLI; U4 mengotorisasi publikasi checkpoint dan pemeriksaan CI. Acuan kebutuhan: [REQUIREMENTS.md](REQUIREMENTS.md); roadmap: [MASTERPLAN.md](MASTERPLAN.md). C1 dikembangkan sebelum G0 selesai; proses baru tidak diterapkan secara retroaktif pada riwayat tersebut.

## Status yang dipakai

- **Implementasi:** `NOT STARTED`, `IN PROGRESS`, `IMPLEMENTED`, atau `BLOCKED` dengan hambatan spesifik.
- **Verifikasi:** `NOT RUN`, `PASSED` untuk cakupan yang disebut, `PARTIAL`, `FAILED`, atau `REPORTED ONLY` untuk laporan historis yang belum diperiksa ulang.
- **Penerimaan:** `PENDING` atau `ACCEPTED` dengan bukti persetujuan pengguna dan cakupannya.
- **Git:** commit lokal dan status push dicatat terpisah. Perubahan yang belum di-commit bukan bagian dari HEAD.

## Ringkasan tahap

| Tahap | Implementasi yang diamati | Verifikasi | Penerimaan produk | Git lokal dan publikasi |
| --- | --- | --- | --- | --- |
| G0 | Dokumen v0.3, AGENTS, dan konfigurasi CI tersedia | Dokumen: EV-DOC-003; koreksi provenance dilakukan saat finalisasi | Publikasi baseline diotorisasi U4; penilaian audit A2 terpisah; Technical Alpha PROPOSED, Product MVP OPEN | Commit/push dan run CI dicatat setelah benar-benar terjadi |
| A | Bootstrap SwiftUI tersedia | Build EV-BLD-001 PASSED; startup UI belum diperiksa dalam pekerjaan G0 | REPORTED ONLY di H1 | Commit `3fabb98`; merupakan ancestor checkpoint C1 yang dipublikasikan |
| B | SQLite dan GRDB tersedia | Persistence EV-PER-001 PASSED; upgrade database lama belum diuji khusus | REPORTED ONLY di H1 | Commit `2975781`; merupakan ancestor checkpoint C1 yang dipublikasikan |
| README dasar | Dokumentasi fondasi dan checkpoint C1 tersedia | Status dicocokkan dengan C1 terpublikasi `7e268be` | Publikasi dokumentasi G0 diotorisasi U4 | Dasar `3c668f2`; pembaruan disertakan pada checkpoint G0, terpisah dari C1 |
| C | Spesifikasi domain direkonstruksi dan asal keputusan diperjelas | Pilihan hybrid CONFIRMED melalui U2; rincian lain merujuk register keputusan | PENDING untuk rancangan domain keseluruhan | Dokumen lokal; belum di-commit |
| C1 | Empat file core planning di-commit tanpa perubahan terhadap checkpoint | Build dan persistence EV-BLD-001/EV-PER-001 PASSED sebelum audit; hash empat blob cocok saat finalisasi; UI di luar lingkup | Publikasi checkpoint diterima melalui U4; penerimaan produk tetap PENDING | COMMITTED/PUSHED `7e268be9b3230675fccc34ff06e038f6651c149f`; remote `main` diverifikasi sama |
| D | UI planning dan Objective belum tersedia | NOT RUN | PENDING | Belum ada commit |
| E / F / G | Perintah, pelaksanaan, dan evaluasi belum tersedia | NOT RUN | PENDING | Belum ada commit |
| H / I / J | Impor, dokumen/OCR, dan pencarian belum tersedia | NOT RUN | PENDING | Belum ada commit |
| K | Packaging ad hoc tersedia; penguatan produk lebih luas belum tersedia | Packaging REPORTED ONLY di H1; backup/restore belum terbukti | PENDING; gerbang penggunaan data penting belum terpenuhi | Script packaging ada di baseline; tidak menyatakan siap distribusi |

## Tugas yang sedang ditangani

| Tugas | Requirement / keputusan | Hasil dan acceptance criteria | Status / bukti |
| --- | --- | --- | --- |
| TASK-G0-001 | REQ-GOV-001..003; DEC-014 | Masterplan, kebutuhan ber-ID, keputusan bersumber, dan progres yang memisahkan implementasi/verifikasi/acceptance | IMPLEMENTED lokal; publikasi checkpoint diotorisasi U4; cakupan Product MVP tetap OPEN |
| TASK-G0-002 | REQ-GOV-002..003; DEC-015 | Aturan agen konkret, workflow dapat dibaca, build memakai lockfile dan executable pemeriksaan yang tersedia | Konfigurasi IMPLEMENTED; perintah lokal PASSED; hasil GitHub NOT RUN |
| TASK-C1-001 | REQ-PLN-001..003, REQ-SCH-001..002; DEC-004/009 | Plan, Activity, relasi, dan occurrence tersimpan; data salah ditolak; data bertahan setelah dibuka ulang | IMPLEMENTED sebelum G0; suite lokal PASSED; hash cocok; COMMITTED/PUSHED `7e268be` melalui U4, tanpa menerima keseluruhan produk |
| TASK-G0-003 | REQ-GOV-001..003; DEC-005/014/016; audit A1 | Revisi terarah: strategi rilis, enam workflow, gerbang data, status persetujuan, provenance, serta batas checkpoint; source C1 dan CI dipertahankan | IMPLEMENTED lokal; EV-DOC-002/EV-STA-002; penilaian tindak lanjut P0 berasal dari A2; Product MVP tetap OPEN |
| TASK-G0-004 | REQ-GOV-001..003, REQ-DAT-003, REQ-REL-002; DEC-017; U3/A2 | Workflow Desktop CONFIRMED melalui U3; klasifikasi rilis dan penjelasan batas verifikasi merupakan usulan/penilaian A2; roadmap, requirement IDs, C1, dan CI dipertahankan | IMPLEMENTED pada koreksi terdahulu; EV-DOC-003/EV-STA-003; saat itu tanpa build, staging, commit, atau push |
| TASK-G0-005 | REQ-GOV-001..003; DEC-017; U4 | Koreksi provenance U3; pisahkan publikasi C1 dan G0; verifikasi remote serta run CI yang benar-benar terjadi; catat hasil melalui commit dokumentasi | C1 COMMITTED/PUSHED; dokumen G0 diselaraskan; hasil publikasi G0 dan CI dicatat pada bukti finalisasi |

## Bukti G0 awal sebelum audit

EV-SRC-001 sampai EV-GIT-001 berasal dari pekerjaan G0 awal pada 19 Oktober 2026. Build, persistence, dan packaging tidak dijalankan ulang dalam revisi dokumentasi ini.

| ID | Pemeriksaan | Hasil dan batasnya |
| --- | --- | --- |
| EV-SRC-001 | Inspeksi `Package.swift`, source, diff C1, README, serta riwayat Git | Fondasi dan empat file WIP diidentifikasi. Delapan file source/package/script memiliki hash yang sama sebelum dan sesudah perubahan dokumentasi |
| EV-BLD-001 | `swift build --force-resolved-versions` | PASSED, build selesai 4,01 detik; toolchain lokal Apple Swift 6.4, target arm64; GRDB terkunci 7.11.1. Hasil ini berlaku pada kode lokal termasuk C1 |
| EV-PER-001 | `swift run --skip-build MinorityPersistenceChecks` | PASSED dengan keluaran `Persistence checks passed`; mencakup inisialisasi, migrasi berulang, baca/tulis, constraint planning, beberapa occurrence, reopening, rollback, dan propagasi error sesuai executable saat ini |
| EV-DOC-001 | Tautan lokal, spasi akhir, newline, parse YAML, dan pemeriksaan struktur workflow | PASSED pada G0 versi kerja 0.1; tidak menyatakan workflow sudah dieksekusi oleh GitHub |
| EV-GIT-001 | `git diff --check`, status, HEAD, dan daftar file terlacak | PASSED untuk whitespace; HEAD dan ref lokal tersimpan `origin/main` sama-sama `3c668f25e39854ec8d6ba544453e2fa7e6bd74cd`. Tidak ada query live remote pada sesi ini; tidak ada database atau hasil build yang terlacak |

Hasil packaging, tanda tangan bundle, dan validasi Info.plist dalam lampiran adalah **REPORTED ONLY**, tidak dipromosikan menjadi hasil pemeriksaan baru. Build dan executable persistence juga belum membuktikan UI, backup/restore, seluruh jalur upgrade, atau penerimaan domain final.

Snapshot empat file C1 saat EV-BLD-001 dan EV-PER-001:

| File | SHA-256 |
| --- | --- |
| `Sources/MinorityPersistence/DatabaseManager.swift` | `12eb3e36ca5fefb8a9eb23727d7a297d40d3642ab48c13dd88e28b5ed738d890` |
| `Sources/MinorityPersistence/PlanningDomain.swift` | `b9e437fd8454f4ce9787fad5f1f64a85529ce6d37ac734ab5d85a12dd3568aa9` |
| `Sources/MinorityPersistence/PlanningRepository.swift` | `612771fdd052826d5e5334194ab193865d3233facfe3b3fb82a970a0b7dbccb0` |
| `Tests/MinorityTests/main.swift` | `77188a9c6a1f680fba77c2135d91039ff8863ad7cc8784821e2e5fce0bd5126c` |

Checksum di atas merupakan snapshot historis saat C1 belum di-commit. Pada finalisasi, keempat blob dalam commit `7e268be9b3230675fccc34ff06e038f6651c149f` cocok persis dengan checksum tersebut. Untuk pekerjaan berikutnya, utamakan SHA commit, hasil pemeriksaan, serta ID/URL run GitHub Actions bila tersedia. Tidak ada kewajiban mencatat checksum manual setiap file.

## Bukti revisi audit G0

| ID | Pemeriksaan | Hasil dan batasnya |
| --- | --- | --- |
| EV-DOC-002 | Tautan berkas/anchor internal, ID unik, rentang ID, referensi roadmap/tugas/workflow, status persetujuan, serta Markdown dan `git diff --check` | PASSED untuk dokumen v0.2. Konfirmasi baru terbatas pada pilihan hybrid DEC-005/REQ-CMD-001 melalui U2; kandidat MVP dan kebutuhan baru tetap PROPOSED/RECORDED sesuai sumber |
| EV-STA-002 | Snapshot sebelum/sesudah terhadap source, package, script, workflow, HEAD, dan entri index | Source aplikasi dan empat file C1 sama; workflow tidak berubah; HEAD tetap `3c668f25e39854ec8d6ba544453e2fa7e6bd74cd`; entri staging sama dan tidak ada stage/commit/push. Ref lokal tersimpan `origin/main` sama; remote live tidak diperiksa |
| EV-CI-001 | Status run GitHub Actions | NOT RUN dalam pekerjaan G0; ID/URL run belum tersedia. Konfigurasi tetap runner `macos-15`, build dengan lockfile, lalu executable `MinorityPersistenceChecks`, sesuai package lokal; batas kapabilitas runner baru terbukti setelah run |

CI build/persistence belum memverifikasi UI, packaging, signing, atau backup/restore. Setelah publikasi yang diotorisasi, jalankan satu pemeriksaan awal dan catat SHA sumber, ID/URL run, hasil, serta batasnya. Jangan mengganti status NOT RUN dengan PASSED berdasarkan parse YAML atau build lokal.

## Bukti koreksi final G0

| ID | Pemeriksaan | Hasil dan batasnya |
| --- | --- | --- |
| EV-DOC-003 | Konsistensi 35 requirement dan 17 keputusan, referensi roadmap/workflow/tugas, tautan dan anchor, status persetujuan serta milestone, Markdown, dan `git diff --check` | PASSED untuk v0.3; seluruh ID lama dan roadmap dipertahankan. DEC-017 CONFIRMED melalui U3; tidak menetapkan scope Product MVP atau mengubah status persetujuan requirement |
| EV-STA-003 | Perbandingan berkas terlindungi, HEAD, entri staging, dan status Git sebelum/sesudah koreksi | Source C1, package, script, serta workflow sama; HEAD tetap `3c668f25e39854ec8d6ba544453e2fa7e6bd74cd`; tidak ada staging, commit, push, build, atau tes aplikasi baru. Ref lokal tersimpan `origin/main` sama; tidak ada pemeriksaan remote live atau run CI baru |

EV-BLD-001/EV-PER-001 tetap bukti pemeriksaan terdahulu. Persistence SQLite yang lulus tidak secara mandiri membuktikan fungsi offline UI. Kinerja dasar UI/startup/database (OPEN-008) dan pencarian semantik (OPEN-007) memiliki kriteria serta bukti terpisah; target numerik belum ditetapkan.

## Bukti finalisasi dan publikasi

| ID | Pemeriksaan | Hasil dan batasnya |
| --- | --- | --- |
| EV-GIT-004 | Checkpoint C1, batas commit, identitas noreply, dan remote `main` | PASSED: [commit C1 `7e268be9b3230675fccc34ff06e038f6651c149f`](https://github.com/farazzmaldi/Minority/commit/7e268be9b3230675fccc34ff06e038f6651c149f) berisi tepat empat file implementasi; empat blob cocok dengan checkpoint SHA-256; identitas noreply dari riwayat proyek cocok dengan akun GitHub aktif; push berhasil dan `git ls-remote` mengembalikan SHA yang sama pada 19 Oktober 2026. Dokumen G0 tidak ikut commit C1 |
| EV-DOC-004 | Koreksi provenance dan konsistensi baseline G0 sebelum commit | PASSED untuk tautan/anchor, 35 requirement, 17 keputusan, status OPEN/PROPOSED, roadmap, Markdown, serta `git diff --check`. U3 hanya konfirmasi workflow; A2 adalah penilaian/usulan asisten; U4 mengotorisasi publikasi. Source aplikasi dan workflow tidak diubah; build aplikasi tidak diulang |

SHA governance serta ID/URL dan hasil run CI dicatat setelah checkpoint tersebut dipublikasikan. Hasil CI belum diasumsikan dari keberhasilan lokal.

## Batas checkpoint dan publikasi

| Kelompok | Berkas | Status dan batas |
| --- | --- | --- |
| Implementasi C1 | `Sources/MinorityPersistence/DatabaseManager.swift`, `Sources/MinorityPersistence/PlanningDomain.swift`, `Sources/MinorityPersistence/PlanningRepository.swift`, `Tests/MinorityTests/main.swift` | COMMITTED/PUSHED `7e268be9b3230675fccc34ff06e038f6651c149f`; isi commit hanya empat file ini; remote SHA terverifikasi |
| Governance G0 | `docs/MASTERPLAN.md`, `docs/REQUIREMENTS.md`, `docs/DECISIONS.md`, `docs/PROGRESS.md`, dan root `AGENTS.md` | Dokumen v0.3; publikasi checkpoint diotorisasi U4; SHA aktual dicatat setelah commit tersedia; Product MVP OPEN |
| Dokumentasi pengantar | `README.md` | Perubahan lokal untuk status dan tautan G0; layak digabung dengan governance |
| Konfigurasi CI | `.github/workflows/quality.yml` | Ada sebagai berkas lokal dari G0 awal; tidak diubah pada revisi audit; run GitHub belum tersedia |

Pemisahan yang diotorisasi U4: **checkpoint 1** hanya empat file C1, pesan `feat: establish core planning domain`, sudah dipublikasikan sebagai `7e268be`; **checkpoint 2** governance, README, dan CI, pesan `chore: establish G0 governance and quality checks`. SHA checkpoint kedua, remote, dan run CI ditambahkan setelah tersedia melalui pembaruan dokumentasi terpisah.

Urutan pembaruan: setelah commit C1 nyata, periksa isi/SHA lalu perbarui status C1 dalam dokumen ini, `README.md`, dan bagian arsitektur yang masih menyebut pekerjaan lokal. Setelah push yang diotorisasi, catat bukti remote. Setelah checkpoint G0/CI dipublikasikan, catat run CI pertama. Bukti commit sendiri ditambahkan setelah SHA tersedia, melalui pembaruan tracking berikutnya; jangan mengarang SHA masa depan atau mengklaim working tree bersih saat pekerjaan lain masih ada.

## Tindak lanjut temuan audit

| Temuan | Hasil revisi dan yang masih menunggu |
| --- | --- |
| P0-01 | Penilaian asisten A2: strategi dan istilah rilis ditangani pada tingkat dokumentasi; penetapan scope produk tetap OPEN |
| P0-02 | Penilaian asisten A2: batas konfirmasi telah diperjelas. Pilihan hybrid CONFIRMED melalui U2; rincian DEC-016/REQ-CMD-007 tetap RECORDED |
| P0-03 | Penilaian asisten A2: batas checkpoint dan kronologi tersedia. Publikasi aktual kini diotorisasi terpisah melalui U4 dan dicatat sesuai bukti Git |
| P1-01 | WF-01..06 merujuk requirement yang sama, tanpa menduplikasi definisinya |
| P1-02 | Gerbang backup/restore/upgrade berlaku sebelum penggunaan rutin data penting; implementasinya belum dilakukan |
| P1-03 | REQ-CMD-006 dan REQ-EVA-004/005 PROPOSED; offline diperjelas pada REQ-DAT-003 |
| P1-04 | Register keputusan menyimpan pelaku, ringkasan bukti, tanggal pencatatan, dan batas konfirmasi |
| P1-05 | CI minimal dipertahankan dan status run NOT RUN; pemeriksaan pertama menunggu publikasi |
| P2-01 | Status requirement konsisten; implementasi/verifikasi dicatat di progres |
| P2-02 | Hash lama dipertahankan; commit SHA dan identitas run diutamakan untuk tracking berikutnya |
| P2-03 | Root `AGENTS.md` diperiksa; urutan pembaruan status setelah commit dicatat di atas |

## Langkah berikutnya yang dapat ditelusuri

1. Tetapkan cakupan Technical Alpha, Product MVP, serta pembagian Extended Releases saat pengguna memberi keputusan; pertahankan status requirement dan keputusan terbuka sesuai buktinya. Workflow interaksi Desktop CONFIRMED melalui DEC-017; penilaian audit A2 tetap terpisah dari persetujuan pengguna.
2. Pertahankan pemisahan checkpoint C1 `7e268be` dari governance. Setiap pembaruan status publikasi/CI mengacu pada SHA serta hasil remote/run yang aktual.
3. Sebelum perubahan skema berikutnya, tambahkan bukti peningkatan dari database foundation yang berisi data; jangan memakai database pribadi sebagai fixture.
4. Pilih satu tugas fitur berikutnya dari roadmap dan pastikan requirement serta keputusan yang memengaruhinya cukup jelas. Jangan otomatis melanjutkan E/C2.

## Memperbarui tracking

Saat tugas selesai, perbarui baris tugas yang sama dengan hasil, tanggal, bukti, sisa masalah, acceptance, commit lokal, dan status push bila ada. Referensi pemeriksaan yang lama tetap mempunyai cakupan lama; perubahan yang memengaruhi perilaku perlu bukti baru. Jangan menyatakan working tree bersih ketika pekerjaan lain masih ada.

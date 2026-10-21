# Keamanan Firebase — Kebun Sawit Simulator

Dokumen ini menjelaskan model keamanan leaderboard online (Hall of Fame) dan
berisi **checklist tindakan manual di Firebase / Google Cloud Console** yang
wajib dikerjakan pemilik proyek sebelum rilis ke Google Play Store.

File terkait:

| File | Isi |
|---|---|
| [`firestore.rules`](../firestore.rules) | Security Rules — sumber kebenaran, bukan Console |
| [`autoload/LeaderboardManager.gd`](../autoload/LeaderboardManager.gd) | Klien Firestore REST + anonymous auth |
| [`firebase.json`](../firebase.json) | Config untuk `firebase deploy --only firestore:rules` |

---

## 1. Ringkasan: apa masalah yang sebenarnya

Kekhawatiran awalnya adalah *"`API_KEY` hardcoded di `LeaderboardManager.gd`
ikut terkompilasi ke APK dan bisa diekstrak siapa pun"*. Itu **benar**, tapi
itu **bukan** kerentanan yang sesungguhnya.

### API key Firebase memang bukan rahasia

Dokumentasi resmi Firebase, [*Learn about and manage API keys for
Firebase*](https://firebase.google.com/docs/projects/api-keys), menyatakan
secara eksplisit:

> **Public by design:** API keys for Firebase services only identify your
> Firebase project and app to those services. Authorization is handled through
> Google Cloud IAM permissions, Firebase Security Rules, and Firebase App Check.

> If your app's setup follows the above guidelines, then **API keys restricted to
> Firebase services do not need to be treated as secrets**, and it's safe to
> include them in your code or configuration files.

> **None of the Firebase-related APIs use an API key as authorization for calling
> the API.** The API key passed with the API call is only used for identification
> of the Firebase project or app.

Artinya: menyembunyikan key tidak akan menambah keamanan sedikit pun. Apa pun
yang dilakukan — obfuscation, string splitting, ambil dari remote config —
penyerang tetap bisa membaca key dari lalu lintas jaringan. Key bukan pintu;
**Security Rules adalah pintunya.**

### Yang benar-benar berbahaya: Security Rules yang longgar

Rules yang sebelumnya didokumentasikan di komentar `LeaderboardManager.gd`
(baris 8–25 versi lama) adalah masalah sesungguhnya:

```
allow read: if true;
allow create: if request.resource.data.keys().hasAll([...]) && <cek tipe>;
```

Empat lubang konkret:

1. **`allow create` tanpa autentikasi apa pun.** Siapa pun dengan `curl` bisa
   menulis skor palsu tanpa batas. Tidak ada identitas yang bisa dibatasi atau
   dicabut.
2. **`hasAll` tanpa `hasOnly`.** `hasAll` hanya memastikan field *minimal* ada.
   Penyerang bisa menambahkan field sampah sebanyak apa pun hingga batas 1 MiB
   per dokumen → membengkakkan biaya storage dan egress.
3. **`allow read: if true` tanpa batas `limit`.** Siapa pun bisa men-*dump*
   seluruh koleksi berulang-ulang. Ini vektor biaya egress yang justru lebih
   besar daripada jalur tulis.
4. **Dokumen auto-ID.** `submit_score()` versi lama POST ke
   `/hall_of_fame_profit` tanpa `documentId`, jadi **setiap** submit membuat
   dokumen baru. Koleksi tumbuh tanpa batas dan satu pemain muncul berkali-kali
   di papan peringkat.

### Bonus: write amplification (bug biaya, ditemukan saat audit)

`GameState._ready()` menyambungkan `cash_changed` ke
`maybe_record_hall_of_fame()`, yang di akhir memanggil
`LeaderboardManager.submit_score()`
([`GameState.gd:370`](../autoload/GameState.gd:370),
[`GameState.gd:742`](../autoload/GameState.gd:742)).

Jadi **setiap perubahan uang** — tiap panen, tiap penjualan, tiap pembelian
pupuk — memicu satu write Firestore. Dikombinasikan dengan dokumen auto-ID di
atas, satu sesi bermain bisa menghasilkan ratusan dokumen. Kuota gratis
Firestore adalah 20.000 write/hari; ini bisa habis hanya oleh beberapa puluh
pemain. Sudah diperbaiki (lihat §3).

---

## 2. Evaluasi empat opsi mitigasi

| Opsi | Efektif? | Praktis untuk Godot? | Keputusan |
|---|---|---|---|
| **(a) Firebase App Check** | ⭐ Paling efektif — satu-satunya mekanisme yang benar-benar menjawab *"apakah request ini dari aplikasi saya yang asli?"* | ❌ Butuh kode native Android | **Ditunda** — roadmap §7 |
| **(b) Rules ketat + rate limiting** | ✅ Rules ketat sangat efektif. Rate limiting murni di rules: **tidak mungkin** | ✅ Gratis, tanpa kode native | **DIIMPLEMENTASIKAN** |
| **(c) Cloud Function sebagai proxy** | ⭐ Satu-satunya cara memverifikasi bahwa skor benar-benar hasil bermain | ⚠️ Perlu billing Blaze + maintenance backend | **Ditunda** — roadmap §7 |
| **(d) Batasi API key per package name** | ❌ Tidak efektif, dan **akan merusak aplikasi** | ❌ | **JANGAN DILAKUKAN** (lihat peringatan) |

### Catatan (a) — Firebase App Check

Cloud Firestore **memang** salah satu produk yang didukung App Check
([daftar resmi](https://firebase.google.com/docs/app-check/enable-enforcement)),
dan secara teknis REST client bisa memenuhinya dengan mengirim header
`X-Firebase-AppCheck` (ini yang dilakukan Firestore JS SDK secara internal).

Masalahnya di sisi *produksi token*. Token App Check di Android berasal dari
**Play Integrity**, yang hanya bisa dihasilkan oleh `IntegrityManager` di Google
Play Services — Java/Kotlin, tidak ada endpoint HTTPS yang bisa dipanggil
GDScript. Jadi App Check di Godot **wajib** lewat Android plugin (AAR).

- Plugin yang ada: [`zt-pawer/GodotFirebase`](https://github.com/zt-pawer/GodotFirebase)
  (GDExtension native, punya `GodotFirebaseAppCheck` dengan provider
  `playintegrity`). Butuh `gradle_build/use_gradle_build = true` dan build
  ber-signature asli di device nyata.
- [`GodotNuts/GodotFirebase`](https://github.com/GodotNuts/GodotFirebase)
  (addon GDScript populer) **tidak punya** modul App Check.
- Provider `debug` **jangan** dipakai di rilis — mengirim debug secret di APK
  justru membatalkan seluruh gunanya App Check.
- SafetyNet Attestation sudah dimatikan total 20 Mei 2025, jadi plugin Godot
  lama berbasis SafetyNet sudah mati.

> ⚠️ Begitu enforcement App Check diaktifkan, **semua** request tanpa token
> ditolak (butuh ~15 menit untuk aktif). Jangan aktifkan sebelum plugin native
> terpasang dan teruji — kalau tidak, leaderboard mati total.

### Catatan (b) — kenapa rate limiting di rules tidak bisa

Bahasa Security Rules **tidak punya** `request.ip`, counter, maupun agregasi.
`get()`/`exists()` hanya menerima path dokumen tunggal yang lengkap, dibatasi 10
panggilan per request — jadi **tidak mungkin** menghitung jumlah dokumen atau
membatasi ukuran koleksi dari rules. Firebase sendiri mengarahkan ke App Check +
Cloud Functions untuk ini.

Ada pola *cooldown per dokumen* yang populer:

```
allow update: if request.resource.data.last_write == request.time
  && request.time >= resource.data.last_write + duration.value(60, 's');
```

**Pola ini tidak dipakai di sini**, dan alasannya penting:

- Syarat `last_write == request.time` hanya bisa dipenuhi dengan *server
  timestamp*. Lewat REST itu berarti `POST .../documents:commit` dengan
  `updateTransforms[].setToServerValue: REQUEST_TIME` — bukan `createDocument`/
  `patch` JSON biasa yang dipakai klien ini.
- Apakah nilai hasil `updateTransforms` sudah terlihat di `request.resource.data`
  saat rules dievaluasi **tidak terdokumentasi resmi** untuk jalur REST.
- Kalau `last_write` dikirim klien (seperti sekarang), penyerang bisa
  memundurkannya dan melewati cooldown. Rules yang bisa dilewati lebih buruk
  daripada tidak ada rules — menimbulkan rasa aman yang palsu.

**Pengganti yang dipakai:** `profit` wajib **naik secara monoton**
(`request.resource.data.profit > resource.data.profit`). Ini rate limiter
alami yang dieksekusi server dan tidak bergantung jam klien: submit ulang dengan
nilai sama atau lebih kecil ditolak (HTTP 403). Ditambah ID dokumen = UID, satu
akun hanya bisa punya satu entri.

### Catatan (c) — Cloud Function proxy

Ini **satu-satunya** desain di mana angka `profit` punya arti. Rules bisa
membatasi *rentang* nilai, tapi tidak bisa memverifikasi bahwa nilai itu
benar-benar hasil bermain. Penyerang yang sudah login anonim tetap bisa submit
`profit: 999999999999` di write pertamanya.

Desain targetnya: rules jadi `allow write: if false` untuk klien, klien kirim ke
Cloud Function / Cloud Run yang memvalidasi (mis. replay ledger permainan) lalu
menulis pakai kredensial Admin SDK. Butuh billing plan Blaze.

Alternatif yang lebih murah untuk sekadar **rate limiting**: Cloudflare Worker
sebagai proxy dengan Rate Limiting rules di depan Firestore. Catatan: Google
Cloud Armor **tidak bisa** dipakai di sini — ia hanya menempel di Load Balancer
milik sendiri, bukan di `firestore.googleapis.com`.

### Catatan (d) — ⚠️ JANGAN batasi API key per package name

Ini permintaan yang paling masuk akal secara intuisi, tapi justru salah untuk
proyek ini.

**Alasan 1 — akan merusak aplikasi.** Restriction "Android apps" bekerja dengan
mewajibkan request mengirim header `X-Android-Package` dan `X-Android-Cert`.
Header itu disuntikkan oleh Google Play Services / Firebase Android SDK.
`HTTPRequest` Godot **tidak** mengirimnya. Hasilnya: HTTP 403
`API_KEY_ANDROID_APP_BLOCKED` — *"Requests from this Android client application
&lt;empty&gt; are blocked."*

**Alasan 2 — tidak menambah keamanan.** Dokumentasi Google Cloud sendiri
memperingatkan di halaman [*Manage API
keys*](https://cloud.google.com/docs/authentication/api-keys):

> **Note: Bypassing this restriction is straightforward.** If you use this
> restriction, you should also add API restrictions and monitor usage carefully.

Package name (`com.aguswidanarko.kebun_sawit_sim`) dan SHA-1 sertifikat keduanya
nilai **publik** yang bisa diambil dari APK mana pun. Kalaupun header itu
ditambahkan manual di GDScript, penyerang cukup menyalin dua header yang sama.

> ✅ Yang **harus** dilakukan adalah **API restrictions** (membatasi *API mana*
> yang boleh dipanggil key ini) — bukan **Application restrictions**. Dua hal
> yang berbeda, di panel yang sama. Lihat Langkah 3 di §4.

---

## 3. Yang sudah diubah di kode

### `firestore.rules` (file baru)

Rules sekarang hidup di file yang bisa di-review lewat git, bukan di komentar
GDScript yang mudah basi.

| Sebelum | Sesudah |
|---|---|
| `allow read: if true` | `allow get: if isOwner()` + `allow list: if request.auth != null && request.query.limit <= 50` |
| `allow create` tanpa auth | `allow create: if isOwner()` — ID dokumen **wajib** sama dengan `request.auth.uid` |
| `hasAll([...])` | `hasOnly([...]) && keys().size() == 5` — set field **persis**, tidak boleh ada field sampah |
| `profit is int` | `profit is int && profit >= 0 && profit <= 1_000_000_000_000` |
| `day is int` | `day is int && day >= 1 && day <= 100_000` |
| tidak ada | `allow update` wajib `profit > resource.data.profit` (monoton naik) |
| tidak ada | `match /{document=**} { allow read, write: if false; }` — semua path lain ditutup |

`hasOnly` saja tidak cukup (dokumen kosong lolos); `keys().size() == 5`
membatasi dari bawah. `hasAll` saja — versi lama — adalah yang paling berbahaya.

Catat juga: `allow get` sengaja dibuat `isOwner()` saja. Papan peringkat dibaca
lewat operasi `list` (`:runQuery`), bukan `get` per dokumen. Ini penting karena
Security Rules **bukan filter** — kalau sebuah query *bisa* mengembalikan
dokumen yang tidak boleh dibaca klien, seluruh query gagal; jadi kondisi `list`
tidak boleh bergantung pada `resource`.

### `autoload/LeaderboardManager.gd`

1. **Anonymous Authentication lewat REST** — tanpa Firebase SDK:
   - `POST identitytoolkit.googleapis.com/v1/accounts:signUp?key=...` dengan
     body `{"returnSecureToken": true}` → `idToken`, `refreshToken`, `localId`.
   - Refresh tiap jam lewat
     `POST securetoken.googleapis.com/v1/token?key=...` (form-urlencoded).
   - `refreshToken` + `uid` disimpan di `user://leaderboard_cred.json` supaya
     entri leaderboard pemain tetap sama setelah game ditutup.
   - Setiap request Firestore membawa `Authorization: Bearer <idToken>`.
2. **ID dokumen = UID.** `submit_score()` sekarang `PATCH`
   `/hall_of_fame_profit/<uid>` (tanpa `updateMask` = tulis-ulang seluruh
   dokumen, dan membuatnya kalau belum ada). Satu entri per pemain, tidak bisa
   menimpa entri orang lain.
3. **Throttle + dedup** — perbaikan write amplification:
   - Submit di-skip kalau `profit` tidak lebih tinggi dari yang terakhir
     berhasil dikirim.
   - Maksimum 1 request per 60 detik (`SUBMIT_COOLDOWN_SEC`); submit terakhir
     tetap menyusul lewat `Timer` one-shot, jadi tidak ada skor yang hilang.
   - `GameState` **tidak perlu diubah** — `submit_score()` tetap aman dipanggil
     dari `cash_changed`.
4. **Clamp sisi klien** agar tidak pernah mengirim request yang pasti ditolak:
   `MAX_FETCH_LIMIT = 50`, `MAX_PROFIT`, `MAX_DAY`, `MAX_NAME_LEN` — keempatnya
   **harus sinkron** dengan `firestore.rules`. Kalau salah satu diubah, ubah
   keduanya.
5. **Backoff saat auth gagal** (120 detik) supaya aplikasi offline tidak
   menggempur endpoint sign-up.
6. Komentar `PROJECT_ID`/`API_KEY` diperjelas: identifier publik, bukan secret,
   dengan tautan ke dokumentasi resmi.

Verifikasi: `Godot --headless --path . --editor --quit-after 300` berjalan tanpa
error skrip.

---

## 4. ✅ Checklist tindakan manual di Console (WAJIB, berurutan)

> **Urutan penting.** Langkah 1 harus selesai sebelum Langkah 2, kalau tidak
> leaderboard akan mati total (rules baru menolak semua request tanpa auth,
> sementara anonymous auth belum aktif).

> **Kompatibilitas APK lama.** Rules baru mewajibkan autentikasi. Setiap APK
> yang sudah terpasang dengan `LeaderboardManager.gd` versi **lama** akan
> berhenti bisa submit skor (fallback ke rekor lokal, jadi game tetap jalan dan
> tidak crash). Karena game ini belum dirilis ke Play Store, ini tidak masalah —
> tapi pastikan APK yang diunggah ke Play Console adalah build **setelah**
> perubahan ini.

### Langkah 1 — Aktifkan Anonymous Authentication

1. Buka [Firebase Console](https://console.firebase.google.com/) → pilih proyek
   `project-3e24d919-f9bd-41ca-942`.
2. Menu kiri → **Build** → **Authentication**.
3. Kalau belum pernah dipakai, klik **Get started**.
4. Tab **Sign-in method** → **Add new provider** → pilih **Anonymous**.
5. Toggle **Enable** → **Save**.

Opsional tapi dianjurkan — **Authentication** → **Settings** → **User account
linking** / **Anonymous user cleanup**: aktifkan auto-delete akun anonim yang
tidak aktif 30 hari. Akun yang terhapus tidak dihitung dalam kuota/billing.
Konsekuensinya: pemain yang tidak membuka game 30+ hari akan dapat UID baru dan
entri leaderboard lamanya jadi yatim (masih tampil, tapi tidak bisa di-update
lagi). Untuk game kasual ini, trade-off-nya wajar.

> ℹ️ Catatan jujur: anonymous auth **bukan** verifikasi aplikasi. Blog resmi
> Firebase, [*Best Practices for Anonymous
> Authentication*](https://firebase.blog/posts/2023/07/best-practices-for-anonymous-authentication/),
> menyatakan token anonim bisa dibuat lewat REST API sehingga tidak cocok untuk
> membuktikan identitas aplikasi. Nilainya di sini ada pada tiga hal konkret:
> (1) `request.auth.uid` tidak bisa dipalsukan klien, jadi batasan "satu entri
> per pemain" jadi benar-benar mengikat; (2) Firebase membatasi laju pendaftaran
> anonim baru dari satu IP — rate limiter gratis di sisi server, hal yang tidak
> bisa dilakukan rules; (3) akun yang menyalahgunakan bisa di-disable per-UID
> dari Console.

### Langkah 2 — Publish Security Rules

1. Firebase Console → **Build** → **Firestore Database** → tab **Rules**.
2. Buka [`firestore.rules`](../firestore.rules) di repo, **copy seluruh isinya**.
3. Paste menggantikan seluruh isi editor di Console. Editor akan memvalidasi
   sintaks secara live — pastikan tidak ada garis merah.
4. **Sebelum Publish**, uji dulu di **Rules Playground** (tombol di editor):

   | Simulasi | Setting | Harus |
   |---|---|---|
   | Tulis tanpa login | Operation `create`, path `/hall_of_fame_profit/abc`, Authenticated **off** | ❌ Denied |
   | Tulis ke UID orang lain | `create`, path `/hall_of_fame_profit/uid_lain`, Authenticated **on** dengan UID `uid_saya` | ❌ Denied |
   | Tulis dengan field sampah | `create`, path = UID sendiri, body + field `"hack": "x"` | ❌ Denied |
   | Tulis normal | `create`, path = UID sendiri, 5 field sesuai skema | ✅ Allowed |
   | Baca papan peringkat | Operation `list`, path `/hall_of_fame_profit`, Authenticated **on** | ✅ Allowed |

5. Klik **Publish**.

> Alternatif via CLI (kalau mau versi yang bisa di-review di PR):
> `npm i -g firebase-tools && firebase login && firebase deploy --only firestore:rules --project project-3e24d919-f9bd-41ca-942`
> ([`firebase.json`](../firebase.json) sudah disiapkan untuk ini.)

### Langkah 3 — Bersihkan dokumen sampah dari rules lama

Kode versi lama membuat dokumen auto-ID setiap kali uang berubah, dan rules baru
melarang `delete` dari klien. Jadi dokumen-dokumen itu harus dihapus manual —
kalau tidak, papan peringkat akan penuh entri duplikat/palsu.

1. Firebase Console → **Firestore Database** → tab **Data**.
2. Buka koleksi `hall_of_fame_profit`.
3. Hapus **semua** dokumen yang ada (ID-nya acak 20 karakter, bukan UID Firebase
   Auth). Kalau jumlahnya banyak, lebih cepat: klik menu ⋮ di sebelah nama
   koleksi → **Delete collection**. Koleksi akan dibuat ulang otomatis oleh
   submit pertama dari klien baru.

### Langkah 4 — ⭐ Batasi API key (API restrictions)

Ini langkah yang paling penting di antara langkah-langkah "API key", dan satu-
satunya yang benar-benar mengurangi risiko: mencegah key yang bocor dipakai
memanggil API **lain** di proyek yang sama (yang bisa menimbulkan tagihan).

1. Buka [Google Cloud Console → APIs & Services →
   Credentials](https://console.cloud.google.com/apis/credentials), pilih proyek
   yang sama.
2. Klik nama key — biasanya **"Browser key (auto created by Firebase)"** —
   yang nilainya `AIzaSyAVoy4zFPM_MJJBm3E_8b1XqjudaE-Xfu4`.
3. Panel **Application restrictions** → biarkan **None**.

   > 🚫 **JANGAN** pilih "Android apps". Lihat §2(d) — ini akan membuat seluruh
   > leaderboard error 403 `API_KEY_ANDROID_APP_BLOCKED`, dan tidak menambah
   > keamanan.

4. Panel **API restrictions** → pilih **Restrict key**, lalu centang **hanya**:

   | API (display name di Console) | Service | Kenapa perlu |
   |---|---|---|
   | Cloud Firestore API | `firestore.googleapis.com` | Endpoint utama leaderboard |
   | Cloud Datastore API | `datastore.googleapis.com` | Dependensi Firestore |
   | Firebase Rules API | `firebaserules.googleapis.com` | Diwajibkan untuk **akses REST langsung** ke Firestore |
   | Identity Toolkit API | `identitytoolkit.googleapis.com` | Anonymous sign-in |
   | Token Service API | `securetoken.googleapis.com` | Refresh ID token |
   | Firebase Management API | `firebase.googleapis.com` | Dibutuhkan semua produk Firebase |
   | Cloud Logging API | `logging.googleapis.com` | Dibutuhkan semua produk Firebase |

   Hapus centang yang lain. Yang **kritis** untuk tidak dicentang: **Generative
   Language API / Gemini Developer API** — dokumentasi Firebase menyebut secara
   eksplisit *"never include the Gemini Developer API in the allowlist for a
   publicly accessible API key."*

   Catatan: Firebase Installations API **tidak** dibutuhkan selama belum pakai
   FCM / Crashlytics / Remote Config. Kalau nanti dipakai, tambahkan.

5. **Save**. Perubahan bisa butuh beberapa menit untuk aktif.
6. Jalankan game dan buka layar Hall of Fame untuk memastikan masih jalan. Kalau
   dapat 403 `API_KEY_SERVICE_BLOCKED`, berarti ada API di daftar di atas yang
   belum dicentang (atau belum di-*enable* di proyek — API harus enabled dulu
   sebelum bisa dipilih di restriction).

### Langkah 5 — Perketat kuota Identity Toolkit

Endpoint sign-up anonim sekarang jadi permukaan serang baru (penyerang bisa
membuat banyak akun anonim). Firebase menganjurkan memperketat kuotanya.

1. [Google Cloud Console → IAM & Admin →
   Quotas](https://console.cloud.google.com/iam-admin/quotas).
2. Filter service **Identity Toolkit API**.
3. Cari kuota request per menit, klik **Edit quotas**, turunkan ke angka yang
   masuk akal untuk ekspektasi trafik game ini.

> ⚠️ Kalau game tiba-tiba viral dan kuotanya terlalu ketat, pemain baru akan
> gagal sign-in (leaderboard fallback ke lokal, game tetap jalan). Mulai longgar,
> perketat sambil memantau.

### Langkah 6 — Budget alert (satu-satunya alarm yang ada)

**Firestore tidak bisa di-*cap* keras.**
[Spend caps Firebase](https://firebase.google.com/docs/projects/billing/spend-caps)
hanya berlaku untuk Firebase AI Logic, App Hosting, Cloud Functions, dan
Extensions — **Firestore tidak termasuk**. Cloud Billing budget untuk Firestore
sifatnya **alert-only**: *"Budgets won't limit your usage."*

1. [Google Cloud Console → Billing →
   Budgets & alerts](https://console.cloud.google.com/billing/budgets) →
   **Create budget**.
2. Scope: proyek ini. Amount: angka kecil, mis. **Rp 20.000 / USD 1**.
3. Threshold 50% / 90% / 100%, centang **Email alerts to billing admins**.
4. **Finish**.

Kalau mau *hard stop* sungguhan, satu-satunya pola yang ada adalah
Budget → Pub/Sub → Cloud Function yang **melepas billing account** dari proyek
(contoh: [Cap-Firebase-Billing](https://github.com/salesp07/Cap-Firebase-Billing)).
Itu circuit breaker — mematikan seluruh proyek, bukan throttle — dan tetap
tertunda oleh lag pelaporan billing. Untuk game ini, alert + rules ketat sudah
proporsional.

Sambil itu, pantau juga: Firebase Console → **Usage & billing** →
**Firestore** untuk melihat jumlah read/write harian. Kuota gratis: 20.000
write/hari, 50.000 read/hari, 1 GiB storage, 10 GiB egress/bulan.

---

## 5. Rotasi API key

**Harus dilakukan pemilik proyek di Console** — tidak boleh dan tidak bisa
dilakukan dari repo ini.

### Apakah key ini perlu dirotasi?

Secara teknis: **tidak wajib.** Key ini bukan secret (§1), jadi rotasi tidak
menambal lubang apa pun. Lubangnya ada di rules, dan itu sudah ditambal.

Rotasi tetap berguna dalam dua situasi:

- Key ini sudah lama *unrestricted* dan sempat terekspos, jadi tidak diketahui
  siapa saja yang sudah memakainya untuk membakar kuota proyek (bukan untuk
  mencuri data).
- Sebagai higiene berkala, sesuai
  [best practices Google Cloud](https://cloud.google.com/docs/authentication/api-keys-best-practices):
  *"Periodically create new API keys, update your applications to use the new
  API keys, and delete the old keys."*

Kalau Langkah 4 sudah dikerjakan dan key sudah dibatasi hanya ke API Firebase di
atas, rotasi boleh ditunda ke rilis berikutnya.

### ⚠️ Risiko utama: APK lama akan mati

Key di-*hardcode* di APK. FAQ resmi Firebase:

> **If you delete an API key that's in use by an app, then API calls from that
> app will fail.**

Jadi begitu key lama **dihapus**, semua instalasi yang masih memakai key lama
kehilangan leaderboard (fallback ke rekor lokal — game tidak crash, tapi skor
online berhenti). Key lama **tetap berfungsi sampai dihapus eksplisit**; itulah
jendela migrasinya. Jangan hapus key lama sebelum mayoritas pemain sudah update.

### Prosedur

1. Buka [APIs & Services →
   Credentials](https://console.cloud.google.com/apis/credentials).
2. Klik nama API key yang mau dirotasi.
3. Klik **Rotate key** di halaman detail key.

   > Operasi *Rotate* **hanya ada di Google Cloud Console** (tidak ada di
   > `gcloud` / REST). Kalau butuh cara lain: buat key baru manual, lalu
   > terapkan restriction yang sama persis seperti Langkah 4.

4. Beri nama key baru (mis. `kebun-sawit-sim-firestore-v2`), konfirmasi
   restriction-nya ikut tersalin, klik **Create**.
5. **Salin string key baru.**
6. Di repo, ganti nilai `API_KEY` di
   [`autoload/LeaderboardManager.gd`](../autoload/LeaderboardManager.gd):
   ```gdscript
   const API_KEY := "<KEY_BARU_DI_SINI>"
   ```
7. Verifikasi: jalankan game, buka Hall of Fame, pastikan submit & fetch jalan.
   Cek juga Cloud Console → **APIs & Services** → **Metrics** bahwa trafik
   pindah ke key baru.
8. Build & rilis versi baru ke Play Store.
9. **Tunggu** sampai adopsi versi baru tinggi (pantau di Play Console →
   **Statistics** → distribusi versi). Realistis: 2–4 minggu.
10. Baru kemudian: buka detail key baru → bagian **Previous key** → **Delete the
    previous key**.

### Jaring pengaman

- Salah hapus key masih bisa dibatalkan **dalam 30 hari**: Credentials →
  **Restore deleted credentials**, atau
  `gcloud services api-keys undelete KEY_ID`. Lewat 30 hari, permanen.
- Key Firebase tidak bisa "regenerate in-place" — string key bersifat permanen;
  rotasi **selalu** menghasilkan string baru.
- Kalau nanti pakai `google-services.json`: Firebase memilih key berdasarkan
  pencocokan Application Restrictions, dan dokumentasinya menyebut bahwa
  mengunduh ulang config akan menimpa edit manual. Proyek ini tidak memakai
  `google-services.json` (key ditulis langsung di GDScript), jadi tidak terkena.

---

## 6. Batasan yang disadari

Jujur tentang apa yang **masih** bisa dilakukan penyerang setelah semua langkah
di atas:

| Serangan | Status | Catatan |
|---|---|---|
| Baca data pemain lain di luar leaderboard | 🟢 Tertutup | `match /{document=**} { allow read, write: if false }` |
| Menimpa / menghapus entri pemain lain | 🟢 Tertutup | ID dokumen wajib = `request.auth.uid` |
| Dump seluruh koleksi | 🟢 Tertutup | `list` wajib `limit <= 50` |
| Field sampah / dokumen 1 MiB | 🟢 Tertutup | `hasOnly` + `keys().size() == 5` + batas panjang string |
| Banjir dokumen tanpa batas | 🟡 Terbatas | 1 dokumen per akun; pembuatan akun anonim dibatasi per-IP oleh Firebase |
| Spam update dari satu akun | 🟡 Terbatas | `profit` wajib naik monoton; tapi penyerang bisa naik +1 berkali-kali |
| **Submit skor palsu** | 🔴 **Terbuka** | Rules hanya membatasi rentang (0 … 1 triliun). **Hanya backend otoritatif (§2c) yang bisa menutup ini.** |
| Request bukan dari aplikasi asli | 🔴 Terbuka | Butuh App Check (§2a) |

Kesimpulan jujur: untuk leaderboard game kasual tanpa hadiah uang, posisi ini
proporsional. Yang hilang hanyalah integritas angka di papan peringkat — bukan
data pemain, bukan tagihan yang tak terkendali. **Kalau nanti leaderboard
dikaitkan dengan hadiah atau IAP, §2(c) berubah dari opsional menjadi wajib.**

---

## 7. Roadmap (kalau nanti dibutuhkan)

Urutan prioritas kalau ingin naik level:

1. **Cloud Function proxy** (§2c) — menutup celah skor palsu, celah paling
   besar yang tersisa. Butuh billing Blaze.
2. **Firebase App Check + Play Integrity** (§2a) — menutup celah "request bukan
   dari aplikasi asli", dan sekaligus memberi rate limiting nyata di sisi
   Google. Butuh Android plugin native + build ber-signature asli. Setelah
   plugin terpasang, tambahkan `firebaseappcheck.googleapis.com` ke daftar API
   restrictions di Langkah 4, dan aktifkan enforcement **hanya** setelah
   dipastikan jalan di device nyata.
3. **Server timestamp + cooldown di rules** (§2b) — pindah dari `patch` ke
   `:commit` dengan `updateTransforms` / `setToServerValue: REQUEST_TIME`, lalu
   aktifkan cooldown per dokumen. Uji dulu di Rules Playground apakah nilai
   transform terlihat di `request.resource.data`.
4. **Pruning terjadwal** — Cloud Scheduler + Function yang memangkas koleksi ke
   N entri teratas. Rules tidak bisa membatasi ukuran koleksi.

---

## 8. Referensi

**Resmi — API key & model keamanan**
- [Learn about and manage API keys for Firebase](https://firebase.google.com/docs/projects/api-keys)
- [Manage API keys (Google Cloud)](https://cloud.google.com/docs/authentication/api-keys)
- [Best practices for managing API keys](https://cloud.google.com/docs/authentication/api-keys-best-practices)
- [Firebase security checklist](https://firebase.google.com/support/guides/security-checklist)

**Resmi — Security Rules**
- [Writing conditions for Cloud Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Structuring Cloud Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Securely query data](https://firebase.google.com/docs/firestore/security/rules-query)
- [Control access to specific fields](https://firebase.google.com/docs/firestore/security/rules-fields)
- [Fix insecure rules](https://firebase.google.com/docs/firestore/security/insecure-rules)

**Resmi — REST & Auth**
- [Use the Cloud Firestore REST API](https://firebase.google.com/docs/firestore/use-rest-api)
- [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth)
- [Authenticate with Firebase Anonymously](https://firebase.google.com/docs/auth/web/anonymous-auth)
- [Best Practices for Anonymous Authentication (Firebase Blog)](https://firebase.blog/posts/2023/07/best-practices-for-anonymous-authentication/)

**Resmi — App Check & biaya**
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [Enable App Check enforcement](https://firebase.google.com/docs/app-check/enable-enforcement)
- [App Check with Play Integrity on Android](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [Firestore pricing](https://cloud.google.com/firestore/pricing)
- [Set up spend caps for Firebase services](https://firebase.google.com/docs/projects/billing/spend-caps)

**Komunitas**
- [zt-pawer/GodotFirebase — GDExtension native dengan App Check](https://github.com/zt-pawer/GodotFirebase)
- [GodotNuts/GodotFirebase — addon GDScript (tanpa App Check)](https://github.com/GodotNuts/GodotFirebase)
- [Rate Limiting With Firestore Security Rules (smarx)](https://smarx.com/posts/2021/01/rate-limiting-with-firestore-security-rules/)
- [Cap-Firebase-Billing — hard stop via Pub/Sub](https://github.com/salesp07/Cap-Firebase-Billing)

---

*Terakhir diperbarui: 21 Oktober 2026.*

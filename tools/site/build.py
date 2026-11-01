#!/usr/bin/env python3
"""Builds the ProjectFit website: one template, four languages.

English is the main language and lives at the site root; Indonesian, Japanese
and Chinese live in /id/, /ja/ and /zh/. Every page links the others with
hreflang (x-default = English) and a language menu that works without
JavaScript. Run from the repository root:

    python3 tools/site/build.py   (Python 3.12 or later)

Card screenshots come from the app's own gallery (site/img/en, site/img/id);
the Japanese and Chinese pages use the English cards, since the app itself is
not translated into Japanese and only partly into Chinese.
"""
import html
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
BASE = "https://mahendradharma.github.io/Project-Fit/"
REPO = "https://github.com/MahendraDharma/Project-Fit"

LANGS = {
    "en": {"dir": "", "name": "English", "og": "en_US", "img": "en"},
    "id": {"dir": "id/", "name": "Bahasa Indonesia", "og": "id_ID", "img": "id"},
    "ja": {"dir": "ja/", "name": "日本語", "og": "ja_JP", "img": "en"},
    "zh": {"dir": "zh/", "name": "简体中文", "og": "zh_CN", "img": "en"},
}

# Feature steps: key, screenshot.
STEPS = [
    ("stress", "stress_day"),
    ("battery", "body_battery"),
    ("sleep", "sleep_score"),
    ("fitness", "fitness_age"),
    ("training", "intensity_minutes"),
    ("snapshot", "snapshot_card"),
]

T = {
"en": {
  "title": "ProjectFit — your fitness data, computed on your phone",
  "desc": "ProjectFit reads your WHOOP band and Garmin watch and works out recovery, strain, sleep, stress and Body Battery on the phone itself. No account, no server, free and open source.",
  "nav_features": "Features", "nav_privacy": "Privacy", "nav_install": "Install", "lang": "Language",
  "h1a": "Your fitness data,", "h1b": "computed on your phone.",
  "lead": "ProjectFit reads your WHOOP band and Garmin watch over Bluetooth and works out recovery, strain, sleep, stress and Body Battery on the phone itself. No account, no server, no subscription.",
  "cta": "Download free", "src": "Source code", "note": "iPhone and Android · open source (AGPL-3.0)",
  "f1": "accounts to create", "f2": "ProjectFit servers", "f3": "automated tests", "f4": "open source code",
  "k_features": "Features", "h_features": "The numbers that usually live in a cloud, in your pocket.",
  "s_features": "Every number comes from a published method with its constants written in the open. When there is not enough data yet, ProjectFit says so instead of guessing.",
  "stress_h": "Stress, scored only while you are still", "stress_p": "A 0–100 stress level from five-minute still windows, against how variable your heart is at night. Moving time is left blank, not scored.",
  "battery_h": "Body Battery", "battery_p": "Charges while you sleep and rest calmly, drains with activity and stress. Every rate is written down, so you can see why it moved.",
  "sleep_h": "Sleep score, with its parts", "sleep_p": "Duration against your own sleep need, stages, awake time, restlessness and stress during the night, each shown with its weight.",
  "fitness_h": "Fitness age without a treadmill test", "fitness_p": "VO₂max from your routine with the HUNT Study model (age, waist, resting heart rate, workouts), and the age whose average matches it.",
  "training_h": "Intensity minutes and training focus", "training_p": "Weekly moderate and vigorous minutes against the WHO's 150, and four weeks of training split into low aerobic, high aerobic and anaerobic.",
  "snapshot_h": "Health Snapshot", "snapshot_p": "Two minutes sitting still: heart rate, HRV, breathing rate and stress, saved as one entry.",
  "more": ["Daily recovery", "Strain 0–21", "HRV status", "Training load", "Heart-rate zones", "Calories", "Steps", "Nap detection", "Muscle recovery", "Sets per muscle", "Habit journal", "Monthly report", "Smart wake alarm", "Guided breathing", "AI coach (your own key)"],
  "k_privacy": "Privacy", "h_privacy": "Your health data never leaves your phone.",
  "s_privacy": "There is no ProjectFit account and no ProjectFit server. The band talks to the app over Bluetooth.",
  "n_band": "Your band", "n_band_s": "WHOOP or Garmin", "n_phone": "Your phone", "n_phone_s": "every number computed here", "n_cloud": "A server", "n_cloud_s": "none",
  "p1_h": "Computed on the device", "p1_p": "Every metric is worked out on the phone from the band's raw data. It works offline.",
  "p2_h": "No account", "p2_p": "Nothing to sign up for. Backups are encrypted and go where you choose.",
  "p3_h": "Open code", "p3_p": "All of it is on GitHub under AGPL-3.0, so anyone can check what it does.",
  "k_install": "Install", "h_install": "Free on iPhone and Android.",
  "s_install": "ProjectFit is not in the App Store or Play Store yet. Install it from the GitHub release.",
  "ios_req": "iOS 15 or later · a free Apple ID",
  "ios_1": "iOS 27 or later: install SideStore, then add the ProjectFit source.", "ios_2": "iOS 15–26: download ProjectFit.ipa and install it with Sideloadly from a computer.",
  "and_req": "Android 8.0 or later",
  "and_1": "Download ProjectFit.apk from the latest release.", "and_2": "Open it and allow installs from that source.", "and_3": "Allow Bluetooth (Nearby devices) the first time you open it.",
  "guide_ios": "iPhone guide", "guide_and": "Android guide", "latest": "Latest release",
  "foot1": "open source, AGPL-3.0 · based on OpenStrap.",
  "foot2": "WHOOP and Garmin are trademarks of their respective owners. ProjectFit is not affiliated with, endorsed or sponsored by them.",
  "foot3": "Not a medical device. The numbers are fitness estimates, not a diagnosis.",
  "guide_lang": "en",
},
"id": {
  "title": "ProjectFit — data kebugaran yang dihitung di HP Anda",
  "desc": "ProjectFit membaca band WHOOP dan jam Garmin, lalu menghitung recovery, strain, tidur, stres, dan Body Battery langsung di HP. Tanpa akun, tanpa server, gratis dan open source.",
  "nav_features": "Fitur", "nav_privacy": "Privasi", "nav_install": "Pasang", "lang": "Bahasa",
  "h1a": "Data kebugaran Anda,", "h1b": "dihitung di HP Anda.",
  "lead": "ProjectFit membaca band WHOOP dan jam Garmin lewat Bluetooth, lalu menghitung recovery, strain, tidur, stres, dan Body Battery langsung di HP. Tanpa akun, tanpa server, tanpa langganan.",
  "cta": "Unduh gratis", "src": "Kode sumber", "note": "iPhone dan Android · open source (AGPL-3.0)",
  "f1": "akun yang perlu dibuat", "f2": "server ProjectFit", "f3": "tes otomatis", "f4": "kode terbuka",
  "k_features": "Fitur", "h_features": "Angka yang biasanya ada di cloud, kini di saku Anda.",
  "s_features": "Setiap angka dihitung dengan metode yang dipublikasikan, dengan konstanta yang ditulis terbuka. Kalau datanya belum cukup, ProjectFit bilang begitu, bukan menebak.",
  "stress_h": "Stres, dihitung hanya saat Anda diam", "stress_p": "Tingkat stres 0–100 dari jendela diam lima menit, dibanding variasi jantung Anda di malam hari. Waktu bergerak dibiarkan kosong, tidak dinilai.",
  "battery_h": "Body Battery", "battery_p": "Terisi saat tidur dan istirahat tenang, terkuras oleh aktivitas dan stres. Setiap lajunya ditulis terbuka, jadi Anda bisa melihat kenapa angkanya bergerak.",
  "sleep_h": "Skor tidur beserta komponennya", "sleep_p": "Durasi dibanding kebutuhan tidur pribadi, tahap tidur, waktu terjaga, kegelisahan, dan stres saat tidur, masing-masing dengan bobotnya.",
  "fitness_h": "Usia kebugaran tanpa tes treadmill", "fitness_p": "VO₂max dari rutinitas Anda dengan model studi HUNT (usia, lingkar pinggang, denyut istirahat, latihan), dan usia yang rata-ratanya setara.",
  "training_h": "Menit intensitas dan fokus latihan", "training_p": "Menit sedang dan berat per minggu terhadap target WHO 150 menit, serta latihan empat minggu yang dibagi menjadi aerobik rendah, aerobik tinggi, dan anaerobik.",
  "snapshot_h": "Health Snapshot", "snapshot_p": "Dua menit duduk diam: denyut jantung, HRV, laju napas, dan stres disimpan sebagai satu catatan.",
  "more": ["Recovery harian", "Strain 0–21", "Status HRV", "Beban latihan", "Zona detak jantung", "Kalori", "Langkah", "Deteksi tidur siang", "Pemulihan otot", "Set per otot", "Jurnal kebiasaan", "Laporan bulanan", "Alarm bangun pintar", "Napas terpandu", "Coach AI (kunci Anda sendiri)"],
  "k_privacy": "Privasi", "h_privacy": "Data kesehatan Anda tidak pernah meninggalkan HP.",
  "s_privacy": "Tidak ada akun ProjectFit dan tidak ada server ProjectFit. Band tersambung ke aplikasi lewat Bluetooth.",
  "n_band": "Band Anda", "n_band_s": "WHOOP atau Garmin", "n_phone": "HP Anda", "n_phone_s": "semua angka dihitung di sini", "n_cloud": "Server", "n_cloud_s": "tidak ada",
  "p1_h": "Dihitung di perangkat", "p1_p": "Semua metrik dihitung di HP dari data mentah band. Bisa dipakai tanpa internet.",
  "p2_h": "Tanpa akun", "p2_p": "Tidak perlu mendaftar. Cadangan data dienkripsi dan disimpan di tempat yang Anda pilih.",
  "p3_h": "Kode terbuka", "p3_p": "Seluruh kode ada di GitHub dengan lisensi AGPL-3.0, jadi siapa pun bisa memeriksanya.",
  "k_install": "Pasang", "h_install": "Gratis untuk iPhone dan Android.",
  "s_install": "ProjectFit belum ada di App Store maupun Play Store. Pasang langsung dari rilis GitHub.",
  "ios_req": "iOS 15 ke atas · Apple ID gratis",
  "ios_1": "iOS 27 ke atas: pasang SideStore, lalu tambahkan sumber ProjectFit.", "ios_2": "iOS 15–26: unduh ProjectFit.ipa, lalu pasang dengan Sideloadly dari komputer.",
  "and_req": "Android 8.0 ke atas",
  "and_1": "Unduh ProjectFit.apk dari rilis terbaru.", "and_2": "Buka filenya dan izinkan pemasangan dari sumber itu.", "and_3": "Beri izin Bluetooth (Perangkat di sekitar) saat pertama dibuka.",
  "guide_ios": "Panduan iPhone", "guide_and": "Panduan Android", "latest": "Rilis terbaru",
  "foot1": "open source, AGPL-3.0 · berbasis OpenStrap.",
  "foot2": "WHOOP dan Garmin adalah merek milik pemiliknya masing-masing. ProjectFit tidak berafiliasi dengan, didukung, atau disponsori oleh mereka.",
  "foot3": "Bukan alat medis. Angka-angkanya adalah estimasi kebugaran, bukan diagnosis.",
  "guide_lang": "id",
},
"ja": {
  "title": "ProjectFit — フィットネスデータをスマホの中で計算",
  "desc": "ProjectFit は WHOOP バンドと Garmin ウォッチのデータを読み取り、リカバリー、ストレイン、睡眠、ストレス、Body Battery をスマホの中で計算します。アカウント不要、サーバー不要、無料のオープンソースです。",
  "nav_features": "機能", "nav_privacy": "プライバシー", "nav_install": "インストール", "lang": "言語",
  "h1a": "あなたのフィットネスデータを、", "h1b": "あなたのスマホで計算。",
  "lead": "ProjectFit は WHOOP バンドと Garmin ウォッチに Bluetooth で接続し、リカバリー、ストレイン、睡眠、ストレス、Body Battery をスマホ本体で計算します。アカウントもサーバーもサブスクリプションも不要です。",
  "cta": "無料でダウンロード", "src": "ソースコード", "note": "iPhone と Android · オープンソース (AGPL-3.0)",
  "f1": "作成するアカウント", "f2": "ProjectFit のサーバー", "f3": "自動テスト", "f4": "オープンなコード",
  "k_features": "機能", "h_features": "いつもはクラウドにある数値を、ポケットの中に。",
  "s_features": "すべての数値は公開された手法で計算し、定数も公開しています。データがまだ足りないときは、推測せずにそう表示します。",
  "stress_h": "静止しているときだけ測るストレス", "stress_p": "5 分間の静止区間から 0–100 のストレスを算出し、夜間の心拍変動と比較します。動いている時間は評価せず空白のままにします。",
  "battery_h": "Body Battery", "battery_p": "睡眠と穏やかな休息で充電され、活動とストレスで消費されます。すべての変化率を公開しているので、なぜ動いたのかがわかります。",
  "sleep_h": "内訳つきの睡眠スコア", "sleep_p": "あなた自身の必要睡眠時間に対する睡眠時間、睡眠ステージ、覚醒時間、寝返り、夜間のストレスを、それぞれの重みとともに表示します。",
  "fitness_h": "トレッドミルなしのフィットネス年齢", "fitness_p": "HUNT 研究のモデル（年齢、ウエスト、安静時心拍数、運動習慣）で日々の習慣から VO₂max を推定し、その平均に当たる年齢を示します。",
  "training_h": "強度分数とトレーニングの重点", "training_p": "WHO の目標 150 分に対する週ごとの中強度・高強度の分数と、4 週間のトレーニングを低強度有酸素・高強度有酸素・無酸素に分けた内訳。",
  "snapshot_h": "ヘルススナップショット", "snapshot_p": "2 分間静かに座るだけで、心拍数、HRV、呼吸数、ストレスを 1 件の記録として保存します。",
  "more": ["毎日のリカバリー", "ストレイン 0–21", "HRV ステータス", "トレーニング負荷", "心拍ゾーン", "カロリー", "歩数", "昼寝の検出", "筋肉の回復", "部位別セット数", "習慣ジャーナル", "月次レポート", "スマート起床アラーム", "呼吸ガイド", "AI コーチ（ご自身のキー）"],
  "k_privacy": "プライバシー", "h_privacy": "健康データはスマホから出ていきません。",
  "s_privacy": "ProjectFit のアカウントもサーバーもありません。バンドは Bluetooth でアプリと直接つながります。",
  "n_band": "あなたのバンド", "n_band_s": "WHOOP または Garmin", "n_phone": "あなたのスマホ", "n_phone_s": "すべての数値をここで計算", "n_cloud": "サーバー", "n_cloud_s": "なし",
  "p1_h": "端末内で計算", "p1_p": "すべての指標はバンドの生データからスマホ上で計算されます。オフラインでも使えます。",
  "p2_h": "アカウント不要", "p2_p": "登録は不要です。バックアップは暗号化され、あなたが選んだ場所に保存されます。",
  "p3_h": "オープンなコード", "p3_p": "すべてのコードを AGPL-3.0 で GitHub に公開しているので、誰でも中身を確認できます。",
  "k_install": "インストール", "h_install": "iPhone と Android で無料。",
  "s_install": "ProjectFit はまだ App Store にも Play Store にもありません。GitHub のリリースからインストールしてください（手順書は英語またはインドネシア語です）。",
  "ios_req": "iOS 15 以降 · 無料の Apple ID",
  "ios_1": "iOS 27 以降：SideStore をインストールし、ProjectFit のソースを追加します。", "ios_2": "iOS 15–26：ProjectFit.ipa をダウンロードし、パソコンの Sideloadly でインストールします。",
  "and_req": "Android 8.0 以降",
  "and_1": "最新リリースから ProjectFit.apk をダウンロードします。", "and_2": "ファイルを開き、そのソースからのインストールを許可します。", "and_3": "初回起動時に Bluetooth（付近のデバイス）を許可します。",
  "guide_ios": "iPhone の手順", "guide_and": "Android の手順", "latest": "最新リリース",
  "foot1": "オープンソース、AGPL-3.0 · OpenStrap がベース。",
  "foot2": "WHOOP および Garmin は各社の商標です。ProjectFit はこれらの企業と提携しておらず、承認や後援も受けていません。",
  "foot3": "医療機器ではありません。数値はフィットネスの推定値であり、診断ではありません。",
  "guide_lang": "en",
},
"zh": {
  "title": "ProjectFit — 健身数据，在你的手机上计算",
  "desc": "ProjectFit 读取 WHOOP 手环和 Garmin 手表的数据，在手机上直接计算恢复、负荷、睡眠、压力和 Body Battery。无需账号，无需服务器，免费开源。",
  "nav_features": "功能", "nav_privacy": "隐私", "nav_install": "安装", "lang": "语言",
  "h1a": "你的健身数据，", "h1b": "在你的手机上计算。",
  "lead": "ProjectFit 通过蓝牙读取 WHOOP 手环和 Garmin 手表，在手机本机上计算恢复、负荷、睡眠、压力和 Body Battery。无需账号，无需服务器，无需订阅。",
  "cta": "免费下载", "src": "源代码", "note": "iPhone 与 Android · 开源 (AGPL-3.0)",
  "f1": "需要注册的账号", "f2": "ProjectFit 服务器", "f3": "自动化测试", "f4": "开放源代码",
  "k_features": "功能", "h_features": "原本在云端的数据，现在装进你的口袋。",
  "s_features": "每个数值都基于已发表的方法，常数全部公开。数据还不够时，ProjectFit 会直接告诉你，而不是去猜。",
  "stress_h": "只在静止时计算的压力", "stress_p": "根据五分钟的静止区间得出 0–100 的压力值，并与你夜间的心率变异性比较。活动时间留空，不计分。",
  "battery_h": "Body Battery", "battery_p": "睡眠和平静休息时充电，活动和压力时消耗。每个速率都公开写明，你能看到它为什么变化。",
  "sleep_h": "带分项的睡眠评分", "sleep_p": "相对个人睡眠需求的时长、睡眠阶段、清醒时间、躁动程度和夜间压力，每项都标出权重。",
  "fitness_h": "无需跑步机测试的体能年龄", "fitness_p": "用 HUNT 研究模型（年龄、腰围、静息心率、运动习惯）从日常习惯估算 VO₂max，并给出平均水平与之相当的年龄。",
  "training_h": "强度分钟数与训练重点", "training_p": "每周中等与高强度分钟数对照世卫组织 150 分钟目标，以及四周训练在低强度有氧、高强度有氧和无氧之间的分布。",
  "snapshot_h": "健康快照", "snapshot_p": "静坐两分钟：心率、HRV、呼吸频率和压力保存为一条记录。",
  "more": ["每日恢复", "负荷 0–21", "HRV 状态", "训练负荷", "心率区间", "卡路里", "步数", "午睡检测", "肌肉恢复", "各肌群组数", "习惯日记", "月度报告", "智能唤醒闹钟", "呼吸引导", "AI 教练（使用你自己的密钥）"],
  "k_privacy": "隐私", "h_privacy": "你的健康数据从不离开手机。",
  "s_privacy": "没有 ProjectFit 账号，也没有 ProjectFit 服务器。手环通过蓝牙直接连接应用。",
  "n_band": "你的手环", "n_band_s": "WHOOP 或 Garmin", "n_phone": "你的手机", "n_phone_s": "所有数值在这里计算", "n_cloud": "服务器", "n_cloud_s": "没有",
  "p1_h": "在设备上计算", "p1_p": "所有指标都在手机上由手环的原始数据计算，离线也能使用。",
  "p2_h": "无需账号", "p2_p": "无需注册。备份经过加密，保存在你选择的位置。",
  "p3_h": "开放代码", "p3_p": "全部代码以 AGPL-3.0 许可证发布在 GitHub 上，任何人都可以检查。",
  "k_install": "安装", "h_install": "iPhone 和 Android 均免费。",
  "s_install": "ProjectFit 尚未上架 App Store 或 Play Store，请从 GitHub 发布页安装（安装指南为英文或印尼文）。",
  "ios_req": "iOS 15 或更高 · 免费 Apple ID",
  "ios_1": "iOS 27 或更高：安装 SideStore，然后添加 ProjectFit 源。", "ios_2": "iOS 15–26：下载 ProjectFit.ipa，再用电脑上的 Sideloadly 安装。",
  "and_req": "Android 8.0 或更高",
  "and_1": "从最新发布下载 ProjectFit.apk。", "and_2": "打开文件，允许从该来源安装。", "and_3": "首次打开时允许蓝牙（附近的设备）。",
  "guide_ios": "iPhone 指南", "guide_and": "Android 指南", "latest": "最新发布",
  "foot1": "开源，AGPL-3.0 · 基于 OpenStrap。",
  "foot2": "WHOOP 和 Garmin 是其各自所有者的商标。ProjectFit 与它们没有关联，也未获得其认可或赞助。",
  "foot3": "并非医疗器械。这些数值是健身估算，不是诊断。",
  "guide_lang": "en",
},
}

GLOBE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15 15 0 0 1 0 20a15 15 0 0 1 0-20"/></svg>'
DOWN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>'
GH = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.05-.72.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.19-3.1-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.84 1.19 3.1 0 4.42-2.7 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5Z"/></svg>'
APPLE = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.4 1.2 9.8.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8s1.9.8 3.2.7c1.3 0 2.1-1.2 2.9-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.4-.9-2.4-3.8ZM14 5.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4Z"/></svg>'
DROID = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.6 9.5 19.4 6.4a.4.4 0 1 0-.7-.4l-1.8 3.1A11 11 0 0 0 12 8a11 11 0 0 0-4.9 1.1L5.3 6a.4.4 0 1 0-.7.4l1.8 3.1A9.6 9.6 0 0 0 1.5 17h21a9.6 9.6 0 0 0-4.9-7.5ZM7 14.3a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm10 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"/></svg>'
BAND = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="7" y="6" width="10" height="12" rx="3"/><path d="M9 6V2h6v4M9 18v4h6v-4"/><path d="M9.5 12h1.5l1-2 1 4 1-2h.5"/></svg>'
PHONE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="2" width="12" height="20" rx="3"/><path d="M11 18h2"/></svg>'
CLOUD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17.5 19H8a5 5 0 1 1 1-9.9A6 6 0 0 1 20 11a4 4 0 0 1-2.5 8Z"/></svg>'
LOGO = '<svg viewBox="0 0 1024 1024" aria-hidden="true"><rect width="1024" height="1024" rx="228" fill="#111315"/><g transform="translate(512 512) scale(.86) translate(-532 -522)"><path d="M372 300 L372 744" stroke="#fff" stroke-width="80" stroke-linecap="round"/><circle cx="532" cy="460" r="160" fill="none" stroke="#fff" stroke-width="80"/><circle cx="676" cy="704" r="44" fill="#30D158"/></g></svg>'
# The signature mark: drawn stroke, then a dot that beats.
MARK = ('<svg viewBox="300 220 480 600" role="img" aria-label="ProjectFit">'
        '<path class="stroke" d="M372 744 L372 300"/>'
        '<path class="stroke" d="M372 460 A160 160 0 1 1 692 460 A160 160 0 1 1 372 460"/>'
        '<circle class="ring" cx="676" cy="704" r="44"/>'
        '<circle class="dot" cx="676" cy="704" r="44"/></svg>')
PULSE = ('<svg class="pulse-bg" viewBox="0 0 1200 140" preserveAspectRatio="none" aria-hidden="true">'
         '<path d="M0 90 H380 L410 90 L430 40 L455 130 L480 20 L505 110 L520 90 H760 L780 90 L795 60 L812 112 L830 70 L842 90 H1200"/></svg>')


def page(code):
    t, L = T[code], LANGS[code]
    e = lambda k: html.escape(t[k])
    root = "../" if L["dir"] else ""
    img = f"{root}img/{L['img']}"
    url = BASE + L["dir"]
    alts = "\n".join(
        f'<link rel="alternate" hreflang="{c}" href="{BASE}{LANGS[c]["dir"]}">' for c in LANGS
    ) + f'\n<link rel="alternate" hreflang="x-default" href="{BASE}">'
    menu = "".join(
        f'<li><a href="{root}{LANGS[c]["dir"] or "./"}" hreflang="{c}" lang="{c}"'
        f'{" aria-current=\"page\"" if c == code else ""}>{LANGS[c]["name"]}</a></li>'
        for c in LANGS
    )
    foot_langs = " ".join(
        f'<a href="{root}{LANGS[c]["dir"] or "./"}" hreflang="{c}" lang="{c}">{LANGS[c]["name"]}</a>'
        for c in LANGS
    )
    steps = "\n".join(
        f'<article class="step" data-step="{i}"><h3>{e(k + "_h")}</h3><p>{e(k + "_p")}</p>'
        f'<img src="{img}/{shot}.png" alt="{e(k + "_h")}" loading="lazy" width="780"></article>'
        for i, (k, shot) in enumerate(STEPS)
    )
    screens = "".join(
        f'<img src="{img}/{shot}.png" alt="" width="780"{" loading=\"lazy\"" if i else ""}>'
        for i, (_, shot) in enumerate(STEPS)
    )
    chips = "".join(f'<span class="chip">{html.escape(c)}</span>' for c in t["more"])
    g = t["guide_lang"]
    ios_guide = f"{REPO}/blob/main/docs/IOS_SIDELOAD.md"
    and_guide = f"{REPO}/blob/main/docs/ANDROID.md"
    return f"""<!doctype html>
<html lang="{code}" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e("title")}</title>
<meta name="description" content="{e("desc")}">
<link rel="canonical" href="{url}">
{alts}
<meta property="og:type" content="website">
<meta property="og:url" content="{url}">
<meta property="og:title" content="ProjectFit">
<meta property="og:description" content="{e("desc")}">
<meta property="og:image" content="{BASE}img/social-preview.png">
<meta property="og:locale" content="{L["og"]}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#0B0C0E">
<link rel="icon" href="{root}img/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="{root}assets/site.css">
<script defer src="{root}assets/site.js"></script>
</head>
<body>
<a class="skip" href="#main">Skip</a>
<nav aria-label="Main"><div class="wrap">
  <a class="brand" href="{root}{L["dir"] or "./"}">{LOGO}ProjectFit</a>
  <div class="links"><a href="#features">{e("nav_features")}</a><a href="#privacy">{e("nav_privacy")}</a><a href="#install">{e("nav_install")}</a><a href="{REPO}">GitHub</a></div>
  <details class="lang"><summary aria-label="{e("lang")}">{GLOBE}{LANGS[code]["name"]}</summary><ul>{menu}</ul></details>
</div></nav>

<main id="main" class="wrap">
  <header class="hero">
    {PULSE}
    <div>
      <h1 class="in-1">{e("h1a")}<br><span class="accent">{e("h1b")}</span></h1>
      <p class="lead in-2">{e("lead")}</p>
      <div class="cta in-3">
        <a class="btn primary" href="#install">{DOWN}{e("cta")}</a>
        <a class="btn" href="{REPO}">{GH}{e("src")}</a>
      </div>
      <p class="note in-4">{e("note")}</p>
    </div>
    <div class="mark">{MARK}</div>
  </header>

  <div class="facts" data-reveal>
    <div class="fact"><b data-count="0">0</b><span>{e("f1")}</span></div>
    <div class="fact"><b data-count="0">0</b><span>{e("f2")}</span></div>
    <div class="fact"><b data-count="7600" data-format="{{n}}+">7,600+</b><span>{e("f3")}</span></div>
    <div class="fact"><b data-count="100" data-format="{{n}}%">100%</b><span>{e("f4")}</span></div>
  </div>

  <section id="features">
    <p class="kicker">{e("k_features")}</p>
    <h2>{e("h_features")}</h2>
    <p class="sub">{e("s_features")}</p>
    <div class="scrolly">
      <div class="steps">
{steps}
      </div>
      <div class="phone" aria-hidden="true"><div class="screen">{screens}</div></div>
    </div>
    <div class="chips" data-reveal>{chips}</div>
  </section>

  <section id="privacy">
    <p class="kicker">{e("k_privacy")}</p>
    <h2>{e("h_privacy")}</h2>
    <p class="sub">{e("s_privacy")}</p>
    <div class="flow" data-reveal>
      <div class="node">{BAND}<b>{e("n_band")}</b><span>{e("n_band_s")}</span></div>
      <div class="wire" aria-hidden="true"></div>
      <div class="node">{PHONE}<b>{e("n_phone")}</b><span>{e("n_phone_s")}</span></div>
      <div class="wire cut" aria-hidden="true"></div>
      <div class="node off">{CLOUD}<b>{e("n_cloud")}</b><span>{e("n_cloud_s")}</span></div>
    </div>
    <div class="points">
      <div class="point"><h3>{e("p1_h")}</h3><p>{e("p1_p")}</p></div>
      <div class="point"><h3>{e("p2_h")}</h3><p>{e("p2_p")}</p></div>
      <div class="point"><h3>{e("p3_h")}</h3><p>{e("p3_p")}</p></div>
    </div>
  </section>

  <section id="install">
    <p class="kicker">{e("k_install")}</p>
    <h2>{e("h_install")}</h2>
    <p class="sub">{e("s_install")}</p>
    <div class="install">
      <div class="inst" data-reveal>
        <h3>{APPLE}iPhone</h3><p class="req">{e("ios_req")}</p>
        <ol><li>{e("ios_1")}</li><li>{e("ios_2")}</li></ol>
        <div class="cta"><a class="btn primary" href="{ios_guide}">{e("guide_ios")}</a><a class="btn" href="{REPO}/releases/latest">{e("latest")}</a></div>
      </div>
      <div class="inst" data-reveal>
        <h3>{DROID}Android</h3><p class="req">{e("and_req")}</p>
        <ol><li>{e("and_1")}</li><li>{e("and_2")}</li><li>{e("and_3")}</li></ol>
        <div class="cta"><a class="btn primary" href="{and_guide}">{e("guide_and")}</a><a class="btn" href="{REPO}/releases/latest">{e("latest")}</a></div>
      </div>
    </div>
  </section>
</main>

<footer><div class="wrap">
  <p><b style="color:var(--ink)">ProjectFit</b> · {e("foot1")}</p>
  <p>{e("foot2")}</p>
  <p>{e("foot3")}</p>
  <p class="langs">{foot_langs}</p>
</div></footer>
</body>
</html>
"""


def main():
    for code, L in LANGS.items():
        out = SITE / L["dir"] / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page(code), encoding="utf-8")
        print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()

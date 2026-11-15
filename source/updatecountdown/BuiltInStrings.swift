//
//  BuiltInStrings.swift
//  updatecountdown
//
//  Built-in texts for the popover state line and buttons, and the Scheduler Reset.
//  Top 10 spoken languages, European countries, Japanese and Korean. English otherwise.
//

import Foundation

nonisolated enum BuiltInStrings {

    struct Texts: Equatable {
        let pending: String
        let downloading: String
        let preparing: String
        let ready: String
        let lowDiskSpace: String
        let checkForUpdates: String
        let reset: String
    }

    static let current = resolve(Locale.preferredLanguages.first ?? "en")

    static let english = Texts(
        pending: "Pending download", downloading: "Downloading…", preparing: "Preparing…", ready: "Ready to install",
        lowDiskSpace: "Low disk space", checkForUpdates: "Check for Updates", reset: "Reset"
    )

    // Only the first preferred language counts. Chinese and Serbian pick their
    // script from the maximal identifier, so "zh-TW" gets Traditional.
    static func resolve(_ identifier: String) -> Texts {
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return english }
        let script = Locale.Language(identifier: language.maximalIdentifier).script?.identifier
        switch code {
        case "zh": return table[script == "Hant" ? "zh-Hant" : "zh-Hans"] ?? english
        case "sr": return table[script == "Latn" ? "sr-Latn" : "sr"] ?? english
        case "no": return table["nb"] ?? english
        default: return table[code] ?? english
        }
    }

    private static let southSlavicLatin = Texts(
        pending: "Čeka se preuzimanje", downloading: "Preuzimanje…", preparing: "Priprema…", ready: "Spremno za instalaciju",
        lowDiskSpace: "Malo prostora na disku", checkForUpdates: "Provjeri ažuriranja", reset: "Resetiraj"
    )

    private static let table: [String: Texts] = [
        "en": english,
        "zh-Hans": Texts(pending: "等待下载", downloading: "正在下载…", preparing: "正在准备…", ready: "可以安装",
                         lowDiskSpace: "磁盘空间偏低", checkForUpdates: "检查更新", reset: "重置"),
        "zh-Hant": Texts(pending: "等待下載", downloading: "正在下載⋯", preparing: "正在準備⋯", ready: "可以安裝",
                         lowDiskSpace: "磁碟空間偏低", checkForUpdates: "檢查更新", reset: "重置"),
        "hi": Texts(pending: "डाउनलोड लंबित", downloading: "डाउनलोड हो रहा है…", preparing: "तैयारी हो रही है…", ready: "इंस्टॉल के लिए तैयार",
                    lowDiskSpace: "डिस्क स्थान कम है", checkForUpdates: "अपडेट की जाँच करें", reset: "रीसेट करें"),
        "es": Texts(pending: "Descarga pendiente", downloading: "Descargando…", preparing: "Preparando…", ready: "Listo para instalar",
                    lowDiskSpace: "Poco espacio en disco", checkForUpdates: "Buscar actualizaciones", reset: "Restablecer"),
        "ar": Texts(pending: "التنزيل معلّق", downloading: "جارٍ التنزيل…", preparing: "جارٍ التحضير…", ready: "جاهز للتثبيت",
                    lowDiskSpace: "مساحة القرص منخفضة", checkForUpdates: "التحقق من وجود تحديثات", reset: "إعادة تعيين"),
        "fr": Texts(pending: "Téléchargement en attente", downloading: "Téléchargement en cours…", preparing: "Préparation en cours…", ready: "Prêt à installer",
                    lowDiskSpace: "Espace disque faible", checkForUpdates: "Rechercher les mises à jour", reset: "Réinitialiser"),
        "bn": Texts(pending: "ডাউনলোড বাকি", downloading: "ডাউনলোড হচ্ছে…", preparing: "প্রস্তুত হচ্ছে…", ready: "ইনস্টলের জন্য প্রস্তুত",
                    lowDiskSpace: "ডিস্কে জায়গা কম", checkForUpdates: "আপডেট চেক করুন", reset: "রিসেট করুন"),
        "pt": Texts(pending: "Download pendente", downloading: "Baixando…", preparing: "Preparando…", ready: "Pronto para instalar",
                    lowDiskSpace: "Pouco espaço em disco", checkForUpdates: "Verificar atualizações", reset: "Redefinir"),
        "ru": Texts(pending: "Ожидает загрузки", downloading: "Загрузка…", preparing: "Подготовка…", ready: "Готово к установке",
                    lowDiskSpace: "Мало места на диске", checkForUpdates: "Проверить обновления", reset: "Сбросить"),
        "id": Texts(pending: "Menunggu unduhan", downloading: "Mengunduh…", preparing: "Menyiapkan…", ready: "Siap dipasang",
                    lowDiskSpace: "Ruang disk rendah", checkForUpdates: "Periksa Pembaruan", reset: "Atur Ulang"),
        "de": Texts(pending: "Download ausstehend", downloading: "Wird geladen …", preparing: "Wird vorbereitet …", ready: "Bereit zur Installation",
                    lowDiskSpace: "Wenig Speicherplatz", checkForUpdates: "Nach Updates suchen", reset: "Zurücksetzen"),
        "it": Texts(pending: "Download in attesa", downloading: "Download in corso…", preparing: "Preparazione in corso…", ready: "Pronto per l'installazione",
                    lowDiskSpace: "Poco spazio su disco", checkForUpdates: "Verifica aggiornamenti", reset: "Ripristina"),
        "nl": Texts(pending: "Download in afwachting", downloading: "Bezig met downloaden…", preparing: "Bezig met voorbereiden…", ready: "Klaar om te installeren",
                    lowDiskSpace: "Weinig schijfruimte", checkForUpdates: "Zoek naar updates", reset: "Stel opnieuw in"),
        "pl": Texts(pending: "Oczekiwanie na pobranie", downloading: "Pobieranie…", preparing: "Przygotowywanie…", ready: "Gotowe do instalacji",
                    lowDiskSpace: "Mało miejsca na dysku", checkForUpdates: "Sprawdź uaktualnienia", reset: "Resetuj"),
        "cs": Texts(pending: "Čeká na stažení", downloading: "Stahování…", preparing: "Příprava…", ready: "Připraveno k instalaci",
                    lowDiskSpace: "Málo místa na disku", checkForUpdates: "Vyhledat aktualizace", reset: "Resetovat"),
        "sk": Texts(pending: "Čaká na stiahnutie", downloading: "Sťahovanie…", preparing: "Príprava…", ready: "Pripravené na inštaláciu",
                    lowDiskSpace: "Málo miesta na disku", checkForUpdates: "Vyhľadať aktualizácie", reset: "Resetovať"),
        "sl": Texts(pending: "Čaka na prenos", downloading: "Prenašanje …", preparing: "Pripravljanje …", ready: "Pripravljeno za namestitev",
                    lowDiskSpace: "Malo prostora na disku", checkForUpdates: "Preveri posodobitve", reset: "Ponastavi"),
        "hu": Texts(pending: "Letöltésre vár", downloading: "Letöltés folyamatban…", preparing: "Előkészítés folyamatban…", ready: "Telepítésre kész",
                    lowDiskSpace: "Kevés a szabad lemezterület", checkForUpdates: "Frissítések keresése", reset: "Visszaállítás"),
        "ro": Texts(pending: "Descărcare în așteptare", downloading: "Se descarcă…", preparing: "Se pregătește…", ready: "Gata de instalare",
                    lowDiskSpace: "Spațiu redus pe disc", checkForUpdates: "Caută actualizări", reset: "Resetează"),
        "ca": Texts(pending: "Descàrrega pendent", downloading: "S'està baixant…", preparing: "S'està preparant…", ready: "A punt per instal·lar",
                    lowDiskSpace: "Poc espai al disc", checkForUpdates: "Comprova si hi ha actualitzacions", reset: "Restableix"),
        "lb": Texts(pending: "Download steet aus", downloading: "Gëtt erofgelueden…", preparing: "Gëtt preparéiert…", ready: "Prett fir z'installéieren",
                    lowDiskSpace: "Wéineg Späicherplaz", checkForUpdates: "No Updates sichen", reset: "Zrécksetzen"),
        "ga": Texts(pending: "Íoslódáil ar feitheamh", downloading: "Á íoslódáil…", preparing: "Á ullmhú…", ready: "Réidh le suiteáil",
                    lowDiskSpace: "Spás diosca íseal", checkForUpdates: "Seiceáil le haghaidh nuashonruithe", reset: "Athshocraigh"),
        "mt": Texts(pending: "Tniżżil pendenti", downloading: "Qed jitniżżel…", preparing: "Qed jiġi ppreparat…", ready: "Lest biex jiġi installat",
                    lowDiskSpace: "Spazju baxx fuq id-diska", checkForUpdates: "Iċċekkja għal aġġornamenti", reset: "Irrisettja"),
        "hr": southSlavicLatin,
        "bs": southSlavicLatin,
        "cnr": southSlavicLatin,
        "sr-Latn": southSlavicLatin,
        "sr": Texts(pending: "Чека се преузимање", downloading: "Преузимање…", preparing: "Припрема…", ready: "Спремно за инсталацију",
                    lowDiskSpace: "Мало простора на диску", checkForUpdates: "Провери ажурирања", reset: "Ресетуј"),
        "mk": Texts(pending: "Се чека преземање", downloading: "Преземање…", preparing: "Подготовка…", ready: "Подготвено за инсталирање",
                    lowDiskSpace: "Малку простор на дискот", checkForUpdates: "Провери за ажурирања", reset: "Ресетирај"),
        "sq": Texts(pending: "Shkarkimi në pritje", downloading: "Po shkarkohet…", preparing: "Po përgatitet…", ready: "Gati për instalim",
                    lowDiskSpace: "Hapësirë e ulët në disk", checkForUpdates: "Kontrollo për përditësime", reset: "Rivendos"),
        "bg": Texts(pending: "Изчаква изтегляне", downloading: "Изтегляне…", preparing: "Подготовка…", ready: "Готово за инсталиране",
                    lowDiskSpace: "Малко дисково пространство", checkForUpdates: "Проверка за актуализации", reset: "Нулиране"),
        "el": Texts(pending: "Εκκρεμεί λήψη", downloading: "Λήψη…", preparing: "Προετοιμασία…", ready: "Έτοιμο για εγκατάσταση",
                    lowDiskSpace: "Χαμηλός χώρος στον δίσκο", checkForUpdates: "Έλεγχος για ενημερώσεις", reset: "Επαναφορά"),
        "tr": Texts(pending: "İndirme bekleniyor", downloading: "İndiriliyor…", preparing: "Hazırlanıyor…", ready: "Yüklemeye hazır",
                    lowDiskSpace: "Disk alanı az", checkForUpdates: "Güncellemeleri Denetle", reset: "Sıfırla"),
        "sv": Texts(pending: "Väntar på hämtning", downloading: "Hämtar…", preparing: "Förbereder…", ready: "Redo att installeras",
                    lowDiskSpace: "Lite diskutrymme", checkForUpdates: "Sök efter uppdateringar", reset: "Återställ"),
        "da": Texts(pending: "Afventer download", downloading: "Downloader…", preparing: "Forbereder…", ready: "Klar til installation",
                    lowDiskSpace: "Lidt diskplads", checkForUpdates: "Søg efter opdateringer", reset: "Nulstil"),
        "nb": Texts(pending: "Venter på nedlasting", downloading: "Laster ned…", preparing: "Forbereder…", ready: "Klar til installering",
                    lowDiskSpace: "Lite diskplass", checkForUpdates: "Se etter oppdateringer", reset: "Nullstill"),
        "nn": Texts(pending: "Ventar på nedlasting", downloading: "Lastar ned…", preparing: "Førebur…", ready: "Klar til installering",
                    lowDiskSpace: "Lite diskplass", checkForUpdates: "Sjå etter oppdateringar", reset: "Nullstill"),
        "is": Texts(pending: "Bíður niðurhals", downloading: "Sækir…", preparing: "Undirbýr…", ready: "Tilbúið til uppsetningar",
                    lowDiskSpace: "Lítið diskpláss", checkForUpdates: "Leita að uppfærslum", reset: "Endurstilla"),
        "fi": Texts(pending: "Odottaa latausta", downloading: "Ladataan…", preparing: "Valmistellaan…", ready: "Valmis asennettavaksi",
                    lowDiskSpace: "Levytila vähissä", checkForUpdates: "Tarkista päivitykset", reset: "Nollaa"),
        "et": Texts(pending: "Allalaadimine ootel", downloading: "Allalaadimine…", preparing: "Ettevalmistamine…", ready: "Valmis installimiseks",
                    lowDiskSpace: "Vähe kettaruumi", checkForUpdates: "Otsi uuendusi", reset: "Lähtesta"),
        "lv": Texts(pending: "Gaida lejupielādi", downloading: "Lejupielādē…", preparing: "Sagatavo…", ready: "Gatavs instalēšanai",
                    lowDiskSpace: "Maz vietas diskā", checkForUpdates: "Pārbaudīt atjauninājumus", reset: "Atiestatīt"),
        "lt": Texts(pending: "Laukiama atsisiuntimo", downloading: "Atsisiunčiama…", preparing: "Ruošiama…", ready: "Paruošta įdiegti",
                    lowDiskSpace: "Mažai vietos diske", checkForUpdates: "Tikrinti, ar yra naujinių", reset: "Nustatyti iš naujo"),
        "uk": Texts(pending: "Очікує завантаження", downloading: "Завантаження…", preparing: "Підготовка…", ready: "Готово до встановлення",
                    lowDiskSpace: "Мало місця на диску", checkForUpdates: "Перевірити оновлення", reset: "Скинути"),
        "be": Texts(pending: "Чакае спампоўкі", downloading: "Спампоўка…", preparing: "Падрыхтоўка…", ready: "Гатова да ўсталявання",
                    lowDiskSpace: "Мала месца на дыску", checkForUpdates: "Праверыць абнаўленні", reset: "Скінуць"),
        "ja": Texts(pending: "ダウンロード待ち", downloading: "ダウンロード中…", preparing: "準備中…", ready: "インストールの準備完了",
                    lowDiskSpace: "ディスク容量が少ない", checkForUpdates: "アップデートを確認", reset: "リセット"),
        "ko": Texts(pending: "다운로드 대기 중", downloading: "다운로드 중…", preparing: "준비 중…", ready: "설치 준비 완료",
                    lowDiskSpace: "디스크 공간이 적음", checkForUpdates: "업데이트 확인", reset: "재설정"),
    ]
}

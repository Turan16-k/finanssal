// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Fraktal';

  @override
  String get appTagline => 'Portföy takibi ve fraktal analiz laboratuvarı';

  @override
  String get navMarkets => 'Piyasalar';

  @override
  String get navPortfolio => 'Portföy';

  @override
  String get navLab => 'Laboratuvar';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get errorGeneric =>
      'Bir şeyler ters gitti. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get confirm => 'Onayla';

  @override
  String get close => 'Kapat';

  @override
  String get continueLabel => 'Devam';

  @override
  String get demoModeBanner =>
      'Demo modu: piyasa verileri sentetiktir, kayıtlar yalnızca bu cihazda tutulur.';

  @override
  String get disclaimerTitle => 'Önemli bilgilendirme';

  @override
  String get disclaimerBody =>
      'Fraktal bir eğitim ve kişisel takip aracıdır. Uygulamadaki hiçbir içerik, hesaplama, simülasyon veya optimizasyon sonucu yatırım danışmanlığı ya da al-sat tavsiyesi değildir. Monte Carlo, Markowitz ve backtest sonuçları geçmiş verilere dayanan olasılık modelleridir; gelecekteki getirileri garanti etmez. Yatırım kararlarınızı kendi risk ve getiri tercihlerinize göre, gerekirse yetkili kuruluşlardan destek alarak veriniz.';

  @override
  String get disclaimerShort => 'Yatırım tavsiyesi değildir.';

  @override
  String get disclaimerAccept => 'Okudum, anladım ve kabul ediyorum';

  @override
  String get dataSources => 'Veri kaynakları';

  @override
  String get dataSourcesBody =>
      'Döviz, gram altın ve BIST 100 endeksi: TCMB EVDS (gün sonu). Kripto paralar: CoinGecko. Hisse senedi ve yatırım fonu fiyatları lisans gerektirdiği için uygulamada yayınlanmaz; bu varlıklar için kendi fiyatınızı girersiniz. Veriler gecikmeli olabilir ve hatalar içerebilir.';

  @override
  String get typeFx => 'Döviz';

  @override
  String get typeGold => 'Altın';

  @override
  String get typeIndex => 'Endeks';

  @override
  String get typeCrypto => 'Kripto';

  @override
  String get typeStocksFunds => 'Hisse & Fon';

  @override
  String get manualPriceHint =>
      'Hisse ve fon fiyatları lisans gerektirdiği için gösterilmez. Portföy değerlemesi için kendi güncel fiyatınızı girebilirsiniz.';

  @override
  String get enterPrice => 'Fiyat gir';

  @override
  String get yourPrice => 'Sizin fiyatınız';

  @override
  String sourceLabel(String source) {
    return 'Kaynak: $source';
  }

  @override
  String asOf(String date) {
    return '$date itibarıyla';
  }

  @override
  String get range1m => '1A';

  @override
  String get range3m => '3A';

  @override
  String get range1y => '1Y';

  @override
  String get range5y => '5Y';

  @override
  String get analyticsTitle => 'Fraktal analiz';

  @override
  String get hurst => 'Hurst üssü';

  @override
  String get regimeTrending => 'Trend / kalıcı hareket';

  @override
  String get regimeRandomWalk => 'Rastgele yürüyüş';

  @override
  String get regimeMeanReverting => 'Ortalamaya dönüş';

  @override
  String get volatility1y => 'Yıllık volatilite';

  @override
  String get return1y => '1 yıllık getiri';

  @override
  String get maxDrawdown => 'Maks. düşüş';

  @override
  String get createAlert => 'Alarm kur';

  @override
  String get alertAbove => 'Fiyat şunun üzerine çıkarsa';

  @override
  String get alertBelow => 'Fiyat şunun altına inerse';

  @override
  String get alertPctUp => 'Günlük artış en az (%)';

  @override
  String get alertPctDown => 'Günlük düşüş en az (%)';

  @override
  String get priceThreshold => 'Fiyat eşiği';

  @override
  String get percentThreshold => 'Yüzde eşiği';

  @override
  String get alertCreated => 'Alarm kuruldu';

  @override
  String get alertEodNote =>
      'Alarmlar gün sonu verisiyle, veri güncellendiğinde kontrol edilir.';

  @override
  String get alertsTitle => 'Fiyat alarmları';

  @override
  String get noAlerts =>
      'Henüz alarm yok. Bir varlığın detayından alarm kurabilirsiniz.';

  @override
  String get alertsNeedBackend =>
      'Alarmlar için bulut hesabı gerekir; demo modunda kullanılamaz.';

  @override
  String lastTriggered(String date) {
    return 'son: $date';
  }

  @override
  String get portfolios => 'Portföylerim';

  @override
  String get newPortfolio => 'Yeni portföy';

  @override
  String get portfolioName => 'Portföy adı';

  @override
  String get noPortfolios =>
      'Henüz portföyünüz yok. İlk portföyünüzü oluşturup işlemlerinizi ekleyin.';

  @override
  String get marketValue => 'Piyasa değeri';

  @override
  String get costBasis => 'Maliyet';

  @override
  String get unrealizedPnl => 'Gerçekleşmemiş K/Z';

  @override
  String get realizedPnl => 'Gerçekleşmiş K/Z';

  @override
  String get dividends => 'Temettü';

  @override
  String get positions => 'Pozisyonlar';

  @override
  String get transactions => 'İşlemler';

  @override
  String get noTransactions => 'Henüz işlem yok.';

  @override
  String get addTransaction => 'İşlem ekle';

  @override
  String get txBuy => 'Alış';

  @override
  String get txSell => 'Satış';

  @override
  String get txDividend => 'Temettü';

  @override
  String get txFee => 'Ücret';

  @override
  String get txDeposit => 'Para yatırma';

  @override
  String get txWithdraw => 'Para çekme';

  @override
  String get instrument => 'Varlık';

  @override
  String get selectInstrument => 'Bir varlık seçin';

  @override
  String get quantity => 'Adet';

  @override
  String get unitPrice => 'Birim fiyat';

  @override
  String get amount => 'Tutar';

  @override
  String get fee => 'Komisyon';

  @override
  String get note => 'Not';

  @override
  String get invalidNumber => 'Geçerli bir sayı girin';

  @override
  String get priceMissing =>
      'Fiyatı girilmemiş varlıklar maliyetinden değerlendi.';

  @override
  String get sendToLab => 'Laboratuvarda analiz et';

  @override
  String deletePortfolioConfirm(String name) {
    return '\"$name\" portföyü ve tüm işlemleri silinsin mi?';
  }

  @override
  String get deleteTransactionConfirm => 'Bu işlem silinsin mi?';

  @override
  String ledgerError(String message) {
    return 'İşlem geçmişi tutarsız: $message';
  }

  @override
  String avgCost(String value) {
    return 'ort. $value';
  }

  @override
  String quantityShort(String qty) {
    return '$qty adet';
  }

  @override
  String get labTitle => 'Analiz laboratuvarı';

  @override
  String get labIntro =>
      'Varlıkları seçip ağırlıkları ayarlayın. Tüm hesaplamalar cihazınızda yapılır.';

  @override
  String get labEmpty => 'Başlamak için en az bir varlık seçin.';

  @override
  String get assets => 'Varlıklar';

  @override
  String get selectAssets => 'Varlık seç';

  @override
  String get equalWeights => 'Eşit ağırlık';

  @override
  String get parameters => 'Parametreler';

  @override
  String horizonDays(int days) {
    return 'Ufuk: $days işlem günü';
  }

  @override
  String simulationsCount(int count) {
    return '$count simülasyon';
  }

  @override
  String daysShort(int days) {
    return '${days}g';
  }

  @override
  String get riskFree => 'Risksiz faiz (yıllık)';

  @override
  String get jumps => 'Kriz sıçramaları (Merton)';

  @override
  String get jumpsHint =>
      'Ani şokları modele ekler; kuyruk riskini daha gerçekçi gösterir.';

  @override
  String get initialCapital => 'Başlangıç sermayesi';

  @override
  String get run => 'Çalıştır';

  @override
  String get running => 'Hesaplanıyor…';

  @override
  String get tabSimulation => 'Simülasyon';

  @override
  String get tabFrontier => 'Optimizasyon';

  @override
  String get tabBacktest => 'Backtest';

  @override
  String get tabFractal => 'Fraktal';

  @override
  String dataWindow(int days, String start, String end) {
    return '$days ortak gün · $start – $end';
  }

  @override
  String get notEnoughHistory =>
      'Seçili varlıkların ortak geçmişi yetersiz (en az 60 gün gerekli).';

  @override
  String get expectedValue => 'Beklenen değer';

  @override
  String get median => 'Medyan';

  @override
  String get var95 => 'VaR %95';

  @override
  String get var95Hint => '%95 olasılıkla kayıp bu tutarı aşmaz';

  @override
  String get cvar95 => 'CVaR %95';

  @override
  String get cvar95Hint => 'En kötü %5 senaryoda ortalama kayıp';

  @override
  String get probLoss => 'Zarar olasılığı';

  @override
  String get percentileBand => '%5 – %95 aralığı';

  @override
  String get band25_75 => '%25–%75';

  @override
  String get band5_95 => '%5–%95';

  @override
  String get optimalWeights => 'Maks. Sharpe';

  @override
  String get minVariance => 'Min. varyans';

  @override
  String get currentPortfolio => 'Mevcut';

  @override
  String get applyWeights => 'Ağırlıkları uygula';

  @override
  String get frontierAxes =>
      'Yatay: yıllık volatilite · Dikey: yıllık beklenen getiri';

  @override
  String get optimizerNote =>
      'Açığa satış yok; ağırlıklar %0–%100. Geçmiş ortalamalar geleceği yansıtmayabilir.';

  @override
  String get needTwoAssets => 'Optimizasyon için en az 2 varlık seçin.';

  @override
  String get sharpe => 'Sharpe';

  @override
  String get expectedReturnShort => 'getiri';

  @override
  String get volatilityShort => 'vol';

  @override
  String get totalReturn => 'Toplam getiri';

  @override
  String get cagr => 'Yıllık getiri (CAGR)';

  @override
  String get backtestNote =>
      'Günlük yeniden dengelenen sabit ağırlıklı portföy; komisyon ve vergi dahil değildir.';

  @override
  String get hurstExplainer =>
      'Hurst üssü (R/S): H > 0,55 trend/kalıcılık, H ≈ 0,5 rastgele yürüyüş, H < 0,45 ortalamaya dönüş eğilimi.';

  @override
  String get correlation => 'Korelasyon';

  @override
  String get labDisclaimer =>
      'Sonuçlar geçmiş veriye dayalı olasılık modelleridir; gelecekteki getiriyi garanti etmez ve yatırım tavsiyesi değildir.';

  @override
  String get bulletinTitle => 'Bülten analizi (AI)';

  @override
  String get bulletinHint => 'Finansal bir haber veya bülten metni yapıştırın';

  @override
  String get aiNotice =>
      'Metin analiz için Google Gemini\'ye gönderilir; kişisel bilgi eklemeyin.';

  @override
  String get analyze => 'Analiz et';

  @override
  String get sentiment => 'Duygu skoru';

  @override
  String get useSentiment => 'Duygu skorunu simülasyona uygula';

  @override
  String get quotaExceeded =>
      'Günlük AI kullanım sınırına ulaştınız, yarın tekrar deneyin.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get account => 'Hesap';

  @override
  String get guestAccount => 'Misafir hesap';

  @override
  String get guestAccountHint =>
      'Verileriniz bu cihazdaki oturuma bağlı. Kaybetmemek için e-postanızı bağlayın.';

  @override
  String get linkEmail => 'E-posta bağla';

  @override
  String get signInExisting => 'Mevcut hesaba giriş';

  @override
  String get signInWarning =>
      'Giriş yaparsanız bu cihazdaki misafir verileri görünmez olur. Önce e-posta bağlamanız önerilir.';

  @override
  String get email => 'E-posta';

  @override
  String get code => 'Doğrulama kodu';

  @override
  String get sendCode => 'Kod gönder';

  @override
  String get verify => 'Doğrula';

  @override
  String codeSent(String email) {
    return '$email adresine 6 haneli kod gönderildi.';
  }

  @override
  String get invalidEmail => 'Geçerli bir e-posta girin';

  @override
  String get emailVerified => 'E-posta doğrulandı';

  @override
  String get signOut => 'Çıkış yap';

  @override
  String get deleteAccount => 'Hesabı sil';

  @override
  String get deleteAccountConfirm =>
      'Tüm portföyleriniz, işlemleriniz ve alarmlarınız sunucudan kalıcı olarak silinecek. Bu işlem geri alınamaz.';

  @override
  String get accountDeleted => 'Hesabınız silindi.';

  @override
  String get dangerZone => 'Tehlikeli bölge';

  @override
  String get appearance => 'Görünüm';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Cihaz dili';

  @override
  String get security => 'Güvenlik';

  @override
  String get biometricLock => 'Biyometrik kilit';

  @override
  String get biometricReason => 'Fraktal\'ı açmak için kimliğinizi doğrulayın';

  @override
  String get biometricUnavailable =>
      'Bu cihazda biyometrik doğrulama kullanılamıyor.';

  @override
  String get unlock => 'Kilidi aç';

  @override
  String get legal => 'Yasal';

  @override
  String get privacyPolicy => 'Gizlilik politikası';

  @override
  String get terms => 'Kullanım koşulları';

  @override
  String get openSourceLicenses => 'Açık kaynak lisansları';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Fraktal'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In tr, this message translates to:
  /// **'Portföy takibi ve fraktal analiz laboratuvarı'**
  String get appTagline;

  /// No description provided for @navMarkets.
  ///
  /// In tr, this message translates to:
  /// **'Piyasalar'**
  String get navMarkets;

  /// No description provided for @navPortfolio.
  ///
  /// In tr, this message translates to:
  /// **'Portföy'**
  String get navPortfolio;

  /// No description provided for @navLab.
  ///
  /// In tr, this message translates to:
  /// **'Laboratuvar'**
  String get navLab;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti. Bağlantınızı kontrol edip tekrar deneyin.'**
  String get errorGeneric;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @continueLabel.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get continueLabel;

  /// No description provided for @demoModeBanner.
  ///
  /// In tr, this message translates to:
  /// **'Demo modu: piyasa verileri sentetiktir, kayıtlar yalnızca bu cihazda tutulur.'**
  String get demoModeBanner;

  /// No description provided for @disclaimerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Önemli bilgilendirme'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody.
  ///
  /// In tr, this message translates to:
  /// **'Fraktal bir eğitim ve kişisel takip aracıdır. Uygulamadaki hiçbir içerik, hesaplama, simülasyon veya optimizasyon sonucu yatırım danışmanlığı ya da al-sat tavsiyesi değildir. Monte Carlo, Markowitz ve backtest sonuçları geçmiş verilere dayanan olasılık modelleridir; gelecekteki getirileri garanti etmez. Yatırım kararlarınızı kendi risk ve getiri tercihlerinize göre, gerekirse yetkili kuruluşlardan destek alarak veriniz.'**
  String get disclaimerBody;

  /// No description provided for @disclaimerShort.
  ///
  /// In tr, this message translates to:
  /// **'Yatırım tavsiyesi değildir.'**
  String get disclaimerShort;

  /// No description provided for @disclaimerAccept.
  ///
  /// In tr, this message translates to:
  /// **'Okudum, anladım ve kabul ediyorum'**
  String get disclaimerAccept;

  /// No description provided for @dataSources.
  ///
  /// In tr, this message translates to:
  /// **'Veri kaynakları'**
  String get dataSources;

  /// No description provided for @dataSourcesBody.
  ///
  /// In tr, this message translates to:
  /// **'Döviz, gram altın ve BIST 100 endeksi: TCMB EVDS (gün sonu). Kripto paralar: CoinGecko. Hisse senedi ve yatırım fonu fiyatları lisans gerektirdiği için uygulamada yayınlanmaz; bu varlıklar için kendi fiyatınızı girersiniz. Veriler gecikmeli olabilir ve hatalar içerebilir.'**
  String get dataSourcesBody;

  /// No description provided for @typeFx.
  ///
  /// In tr, this message translates to:
  /// **'Döviz'**
  String get typeFx;

  /// No description provided for @typeGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın'**
  String get typeGold;

  /// No description provided for @typeIndex.
  ///
  /// In tr, this message translates to:
  /// **'Endeks'**
  String get typeIndex;

  /// No description provided for @typeCrypto.
  ///
  /// In tr, this message translates to:
  /// **'Kripto'**
  String get typeCrypto;

  /// No description provided for @typeStocksFunds.
  ///
  /// In tr, this message translates to:
  /// **'Hisse & Fon'**
  String get typeStocksFunds;

  /// No description provided for @manualPriceHint.
  ///
  /// In tr, this message translates to:
  /// **'Hisse ve fon fiyatları lisans gerektirdiği için gösterilmez. Portföy değerlemesi için kendi güncel fiyatınızı girebilirsiniz.'**
  String get manualPriceHint;

  /// No description provided for @enterPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat gir'**
  String get enterPrice;

  /// No description provided for @yourPrice.
  ///
  /// In tr, this message translates to:
  /// **'Sizin fiyatınız'**
  String get yourPrice;

  /// No description provided for @sourceLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak: {source}'**
  String sourceLabel(String source);

  /// No description provided for @asOf.
  ///
  /// In tr, this message translates to:
  /// **'{date} itibarıyla'**
  String asOf(String date);

  /// No description provided for @range1m.
  ///
  /// In tr, this message translates to:
  /// **'1A'**
  String get range1m;

  /// No description provided for @range3m.
  ///
  /// In tr, this message translates to:
  /// **'3A'**
  String get range3m;

  /// No description provided for @range1y.
  ///
  /// In tr, this message translates to:
  /// **'1Y'**
  String get range1y;

  /// No description provided for @range5y.
  ///
  /// In tr, this message translates to:
  /// **'5Y'**
  String get range5y;

  /// No description provided for @analyticsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Fraktal analiz'**
  String get analyticsTitle;

  /// No description provided for @hurst.
  ///
  /// In tr, this message translates to:
  /// **'Hurst üssü'**
  String get hurst;

  /// No description provided for @regimeTrending.
  ///
  /// In tr, this message translates to:
  /// **'Trend / kalıcı hareket'**
  String get regimeTrending;

  /// No description provided for @regimeRandomWalk.
  ///
  /// In tr, this message translates to:
  /// **'Rastgele yürüyüş'**
  String get regimeRandomWalk;

  /// No description provided for @regimeMeanReverting.
  ///
  /// In tr, this message translates to:
  /// **'Ortalamaya dönüş'**
  String get regimeMeanReverting;

  /// No description provided for @volatility1y.
  ///
  /// In tr, this message translates to:
  /// **'Yıllık volatilite'**
  String get volatility1y;

  /// No description provided for @return1y.
  ///
  /// In tr, this message translates to:
  /// **'1 yıllık getiri'**
  String get return1y;

  /// No description provided for @maxDrawdown.
  ///
  /// In tr, this message translates to:
  /// **'Maks. düşüş'**
  String get maxDrawdown;

  /// No description provided for @createAlert.
  ///
  /// In tr, this message translates to:
  /// **'Alarm kur'**
  String get createAlert;

  /// No description provided for @alertAbove.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat şunun üzerine çıkarsa'**
  String get alertAbove;

  /// No description provided for @alertBelow.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat şunun altına inerse'**
  String get alertBelow;

  /// No description provided for @alertPctUp.
  ///
  /// In tr, this message translates to:
  /// **'Günlük artış en az (%)'**
  String get alertPctUp;

  /// No description provided for @alertPctDown.
  ///
  /// In tr, this message translates to:
  /// **'Günlük düşüş en az (%)'**
  String get alertPctDown;

  /// No description provided for @priceThreshold.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat eşiği'**
  String get priceThreshold;

  /// No description provided for @percentThreshold.
  ///
  /// In tr, this message translates to:
  /// **'Yüzde eşiği'**
  String get percentThreshold;

  /// No description provided for @alertCreated.
  ///
  /// In tr, this message translates to:
  /// **'Alarm kuruldu'**
  String get alertCreated;

  /// No description provided for @alertEodNote.
  ///
  /// In tr, this message translates to:
  /// **'Alarmlar gün sonu verisiyle, veri güncellendiğinde kontrol edilir.'**
  String get alertEodNote;

  /// No description provided for @alertsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat alarmları'**
  String get alertsTitle;

  /// No description provided for @noAlerts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz alarm yok. Bir varlığın detayından alarm kurabilirsiniz.'**
  String get noAlerts;

  /// No description provided for @alertsNeedBackend.
  ///
  /// In tr, this message translates to:
  /// **'Alarmlar için bulut hesabı gerekir; demo modunda kullanılamaz.'**
  String get alertsNeedBackend;

  /// No description provided for @lastTriggered.
  ///
  /// In tr, this message translates to:
  /// **'son: {date}'**
  String lastTriggered(String date);

  /// No description provided for @portfolios.
  ///
  /// In tr, this message translates to:
  /// **'Portföylerim'**
  String get portfolios;

  /// No description provided for @newPortfolio.
  ///
  /// In tr, this message translates to:
  /// **'Yeni portföy'**
  String get newPortfolio;

  /// No description provided for @portfolioName.
  ///
  /// In tr, this message translates to:
  /// **'Portföy adı'**
  String get portfolioName;

  /// No description provided for @noPortfolios.
  ///
  /// In tr, this message translates to:
  /// **'Henüz portföyünüz yok. İlk portföyünüzü oluşturup işlemlerinizi ekleyin.'**
  String get noPortfolios;

  /// No description provided for @marketValue.
  ///
  /// In tr, this message translates to:
  /// **'Piyasa değeri'**
  String get marketValue;

  /// No description provided for @costBasis.
  ///
  /// In tr, this message translates to:
  /// **'Maliyet'**
  String get costBasis;

  /// No description provided for @unrealizedPnl.
  ///
  /// In tr, this message translates to:
  /// **'Gerçekleşmemiş K/Z'**
  String get unrealizedPnl;

  /// No description provided for @realizedPnl.
  ///
  /// In tr, this message translates to:
  /// **'Gerçekleşmiş K/Z'**
  String get realizedPnl;

  /// No description provided for @dividends.
  ///
  /// In tr, this message translates to:
  /// **'Temettü'**
  String get dividends;

  /// No description provided for @positions.
  ///
  /// In tr, this message translates to:
  /// **'Pozisyonlar'**
  String get positions;

  /// No description provided for @transactions.
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get transactions;

  /// No description provided for @noTransactions.
  ///
  /// In tr, this message translates to:
  /// **'Henüz işlem yok.'**
  String get noTransactions;

  /// No description provided for @addTransaction.
  ///
  /// In tr, this message translates to:
  /// **'İşlem ekle'**
  String get addTransaction;

  /// No description provided for @txBuy.
  ///
  /// In tr, this message translates to:
  /// **'Alış'**
  String get txBuy;

  /// No description provided for @txSell.
  ///
  /// In tr, this message translates to:
  /// **'Satış'**
  String get txSell;

  /// No description provided for @txDividend.
  ///
  /// In tr, this message translates to:
  /// **'Temettü'**
  String get txDividend;

  /// No description provided for @txFee.
  ///
  /// In tr, this message translates to:
  /// **'Ücret'**
  String get txFee;

  /// No description provided for @txDeposit.
  ///
  /// In tr, this message translates to:
  /// **'Para yatırma'**
  String get txDeposit;

  /// No description provided for @txWithdraw.
  ///
  /// In tr, this message translates to:
  /// **'Para çekme'**
  String get txWithdraw;

  /// No description provided for @instrument.
  ///
  /// In tr, this message translates to:
  /// **'Varlık'**
  String get instrument;

  /// No description provided for @selectInstrument.
  ///
  /// In tr, this message translates to:
  /// **'Bir varlık seçin'**
  String get selectInstrument;

  /// No description provided for @quantity.
  ///
  /// In tr, this message translates to:
  /// **'Adet'**
  String get quantity;

  /// No description provided for @unitPrice.
  ///
  /// In tr, this message translates to:
  /// **'Birim fiyat'**
  String get unitPrice;

  /// No description provided for @amount.
  ///
  /// In tr, this message translates to:
  /// **'Tutar'**
  String get amount;

  /// No description provided for @fee.
  ///
  /// In tr, this message translates to:
  /// **'Komisyon'**
  String get fee;

  /// No description provided for @note.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get note;

  /// No description provided for @invalidNumber.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir sayı girin'**
  String get invalidNumber;

  /// No description provided for @priceMissing.
  ///
  /// In tr, this message translates to:
  /// **'Fiyatı girilmemiş varlıklar maliyetinden değerlendi.'**
  String get priceMissing;

  /// No description provided for @sendToLab.
  ///
  /// In tr, this message translates to:
  /// **'Laboratuvarda analiz et'**
  String get sendToLab;

  /// No description provided for @deletePortfolioConfirm.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" portföyü ve tüm işlemleri silinsin mi?'**
  String deletePortfolioConfirm(String name);

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem silinsin mi?'**
  String get deleteTransactionConfirm;

  /// No description provided for @ledgerError.
  ///
  /// In tr, this message translates to:
  /// **'İşlem geçmişi tutarsız: {message}'**
  String ledgerError(String message);

  /// No description provided for @avgCost.
  ///
  /// In tr, this message translates to:
  /// **'ort. {value}'**
  String avgCost(String value);

  /// No description provided for @quantityShort.
  ///
  /// In tr, this message translates to:
  /// **'{qty} adet'**
  String quantityShort(String qty);

  /// No description provided for @labTitle.
  ///
  /// In tr, this message translates to:
  /// **'Analiz laboratuvarı'**
  String get labTitle;

  /// No description provided for @labIntro.
  ///
  /// In tr, this message translates to:
  /// **'Varlıkları seçip ağırlıkları ayarlayın. Tüm hesaplamalar cihazınızda yapılır.'**
  String get labIntro;

  /// No description provided for @labEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Başlamak için en az bir varlık seçin.'**
  String get labEmpty;

  /// No description provided for @assets.
  ///
  /// In tr, this message translates to:
  /// **'Varlıklar'**
  String get assets;

  /// No description provided for @selectAssets.
  ///
  /// In tr, this message translates to:
  /// **'Varlık seç'**
  String get selectAssets;

  /// No description provided for @equalWeights.
  ///
  /// In tr, this message translates to:
  /// **'Eşit ağırlık'**
  String get equalWeights;

  /// No description provided for @parameters.
  ///
  /// In tr, this message translates to:
  /// **'Parametreler'**
  String get parameters;

  /// No description provided for @horizonDays.
  ///
  /// In tr, this message translates to:
  /// **'Ufuk: {days} işlem günü'**
  String horizonDays(int days);

  /// No description provided for @simulationsCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} simülasyon'**
  String simulationsCount(int count);

  /// No description provided for @daysShort.
  ///
  /// In tr, this message translates to:
  /// **'{days}g'**
  String daysShort(int days);

  /// No description provided for @riskFree.
  ///
  /// In tr, this message translates to:
  /// **'Risksiz faiz (yıllık)'**
  String get riskFree;

  /// No description provided for @jumps.
  ///
  /// In tr, this message translates to:
  /// **'Kriz sıçramaları (Merton)'**
  String get jumps;

  /// No description provided for @jumpsHint.
  ///
  /// In tr, this message translates to:
  /// **'Ani şokları modele ekler; kuyruk riskini daha gerçekçi gösterir.'**
  String get jumpsHint;

  /// No description provided for @initialCapital.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç sermayesi'**
  String get initialCapital;

  /// No description provided for @run.
  ///
  /// In tr, this message translates to:
  /// **'Çalıştır'**
  String get run;

  /// No description provided for @running.
  ///
  /// In tr, this message translates to:
  /// **'Hesaplanıyor…'**
  String get running;

  /// No description provided for @tabSimulation.
  ///
  /// In tr, this message translates to:
  /// **'Simülasyon'**
  String get tabSimulation;

  /// No description provided for @tabFrontier.
  ///
  /// In tr, this message translates to:
  /// **'Optimizasyon'**
  String get tabFrontier;

  /// No description provided for @tabBacktest.
  ///
  /// In tr, this message translates to:
  /// **'Backtest'**
  String get tabBacktest;

  /// No description provided for @tabFractal.
  ///
  /// In tr, this message translates to:
  /// **'Fraktal'**
  String get tabFractal;

  /// No description provided for @dataWindow.
  ///
  /// In tr, this message translates to:
  /// **'{days} ortak gün · {start} – {end}'**
  String dataWindow(int days, String start, String end);

  /// No description provided for @notEnoughHistory.
  ///
  /// In tr, this message translates to:
  /// **'Seçili varlıkların ortak geçmişi yetersiz (en az 60 gün gerekli).'**
  String get notEnoughHistory;

  /// No description provided for @expectedValue.
  ///
  /// In tr, this message translates to:
  /// **'Beklenen değer'**
  String get expectedValue;

  /// No description provided for @median.
  ///
  /// In tr, this message translates to:
  /// **'Medyan'**
  String get median;

  /// No description provided for @var95.
  ///
  /// In tr, this message translates to:
  /// **'VaR %95'**
  String get var95;

  /// No description provided for @var95Hint.
  ///
  /// In tr, this message translates to:
  /// **'%95 olasılıkla kayıp bu tutarı aşmaz'**
  String get var95Hint;

  /// No description provided for @cvar95.
  ///
  /// In tr, this message translates to:
  /// **'CVaR %95'**
  String get cvar95;

  /// No description provided for @cvar95Hint.
  ///
  /// In tr, this message translates to:
  /// **'En kötü %5 senaryoda ortalama kayıp'**
  String get cvar95Hint;

  /// No description provided for @probLoss.
  ///
  /// In tr, this message translates to:
  /// **'Zarar olasılığı'**
  String get probLoss;

  /// No description provided for @percentileBand.
  ///
  /// In tr, this message translates to:
  /// **'%5 – %95 aralığı'**
  String get percentileBand;

  /// No description provided for @band25_75.
  ///
  /// In tr, this message translates to:
  /// **'%25–%75'**
  String get band25_75;

  /// No description provided for @band5_95.
  ///
  /// In tr, this message translates to:
  /// **'%5–%95'**
  String get band5_95;

  /// No description provided for @optimalWeights.
  ///
  /// In tr, this message translates to:
  /// **'Maks. Sharpe'**
  String get optimalWeights;

  /// No description provided for @minVariance.
  ///
  /// In tr, this message translates to:
  /// **'Min. varyans'**
  String get minVariance;

  /// No description provided for @currentPortfolio.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut'**
  String get currentPortfolio;

  /// No description provided for @applyWeights.
  ///
  /// In tr, this message translates to:
  /// **'Ağırlıkları uygula'**
  String get applyWeights;

  /// No description provided for @frontierAxes.
  ///
  /// In tr, this message translates to:
  /// **'Yatay: yıllık volatilite · Dikey: yıllık beklenen getiri'**
  String get frontierAxes;

  /// No description provided for @optimizerNote.
  ///
  /// In tr, this message translates to:
  /// **'Açığa satış yok; ağırlıklar %0–%100. Geçmiş ortalamalar geleceği yansıtmayabilir.'**
  String get optimizerNote;

  /// No description provided for @needTwoAssets.
  ///
  /// In tr, this message translates to:
  /// **'Optimizasyon için en az 2 varlık seçin.'**
  String get needTwoAssets;

  /// No description provided for @sharpe.
  ///
  /// In tr, this message translates to:
  /// **'Sharpe'**
  String get sharpe;

  /// No description provided for @expectedReturnShort.
  ///
  /// In tr, this message translates to:
  /// **'getiri'**
  String get expectedReturnShort;

  /// No description provided for @volatilityShort.
  ///
  /// In tr, this message translates to:
  /// **'vol'**
  String get volatilityShort;

  /// No description provided for @totalReturn.
  ///
  /// In tr, this message translates to:
  /// **'Toplam getiri'**
  String get totalReturn;

  /// No description provided for @cagr.
  ///
  /// In tr, this message translates to:
  /// **'Yıllık getiri (CAGR)'**
  String get cagr;

  /// No description provided for @backtestNote.
  ///
  /// In tr, this message translates to:
  /// **'Günlük yeniden dengelenen sabit ağırlıklı portföy; komisyon ve vergi dahil değildir.'**
  String get backtestNote;

  /// No description provided for @hurstExplainer.
  ///
  /// In tr, this message translates to:
  /// **'Hurst üssü (R/S): H > 0,55 trend/kalıcılık, H ≈ 0,5 rastgele yürüyüş, H < 0,45 ortalamaya dönüş eğilimi.'**
  String get hurstExplainer;

  /// No description provided for @correlation.
  ///
  /// In tr, this message translates to:
  /// **'Korelasyon'**
  String get correlation;

  /// No description provided for @labDisclaimer.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar geçmiş veriye dayalı olasılık modelleridir; gelecekteki getiriyi garanti etmez ve yatırım tavsiyesi değildir.'**
  String get labDisclaimer;

  /// No description provided for @bulletinTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bülten analizi (AI)'**
  String get bulletinTitle;

  /// No description provided for @bulletinHint.
  ///
  /// In tr, this message translates to:
  /// **'Finansal bir haber veya bülten metni yapıştırın'**
  String get bulletinHint;

  /// No description provided for @aiNotice.
  ///
  /// In tr, this message translates to:
  /// **'Metin analiz için Google Gemini\'ye gönderilir; kişisel bilgi eklemeyin.'**
  String get aiNotice;

  /// No description provided for @analyze.
  ///
  /// In tr, this message translates to:
  /// **'Analiz et'**
  String get analyze;

  /// No description provided for @sentiment.
  ///
  /// In tr, this message translates to:
  /// **'Duygu skoru'**
  String get sentiment;

  /// No description provided for @useSentiment.
  ///
  /// In tr, this message translates to:
  /// **'Duygu skorunu simülasyona uygula'**
  String get useSentiment;

  /// No description provided for @quotaExceeded.
  ///
  /// In tr, this message translates to:
  /// **'Günlük AI kullanım sınırına ulaştınız, yarın tekrar deneyin.'**
  String get quotaExceeded;

  /// No description provided for @settingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// No description provided for @account.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get account;

  /// No description provided for @guestAccount.
  ///
  /// In tr, this message translates to:
  /// **'Misafir hesap'**
  String get guestAccount;

  /// No description provided for @guestAccountHint.
  ///
  /// In tr, this message translates to:
  /// **'Verileriniz bu cihazdaki oturuma bağlı. Kaybetmemek için e-postanızı bağlayın.'**
  String get guestAccountHint;

  /// No description provided for @linkEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta bağla'**
  String get linkEmail;

  /// No description provided for @signInExisting.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut hesaba giriş'**
  String get signInExisting;

  /// No description provided for @signInWarning.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yaparsanız bu cihazdaki misafir verileri görünmez olur. Önce e-posta bağlamanız önerilir.'**
  String get signInWarning;

  /// No description provided for @email.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get email;

  /// No description provided for @code.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu'**
  String get code;

  /// No description provided for @sendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod gönder'**
  String get sendCode;

  /// No description provided for @verify.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get verify;

  /// No description provided for @codeSent.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine 6 haneli kod gönderildi.'**
  String codeSent(String email);

  /// No description provided for @invalidEmail.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta girin'**
  String get invalidEmail;

  /// No description provided for @emailVerified.
  ///
  /// In tr, this message translates to:
  /// **'E-posta doğrulandı'**
  String get emailVerified;

  /// No description provided for @signOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı sil'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Tüm portföyleriniz, işlemleriniz ve alarmlarınız sunucudan kalıcı olarak silinecek. Bu işlem geri alınamaz.'**
  String get deleteAccountConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız silindi.'**
  String get accountDeleted;

  /// No description provided for @dangerZone.
  ///
  /// In tr, this message translates to:
  /// **'Tehlikeli bölge'**
  String get dangerZone;

  /// No description provided for @appearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Cihaz dili'**
  String get languageSystem;

  /// No description provided for @security.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik'**
  String get security;

  /// No description provided for @biometricLock.
  ///
  /// In tr, this message translates to:
  /// **'Biyometrik kilit'**
  String get biometricLock;

  /// No description provided for @biometricReason.
  ///
  /// In tr, this message translates to:
  /// **'Fraktal\'ı açmak için kimliğinizi doğrulayın'**
  String get biometricReason;

  /// No description provided for @biometricUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda biyometrik doğrulama kullanılamıyor.'**
  String get biometricUnavailable;

  /// No description provided for @unlock.
  ///
  /// In tr, this message translates to:
  /// **'Kilidi aç'**
  String get unlock;

  /// No description provided for @legal.
  ///
  /// In tr, this message translates to:
  /// **'Yasal'**
  String get legal;

  /// No description provided for @privacyPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik politikası'**
  String get privacyPolicy;

  /// No description provided for @terms.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım koşulları'**
  String get terms;

  /// No description provided for @openSourceLicenses.
  ///
  /// In tr, this message translates to:
  /// **'Açık kaynak lisansları'**
  String get openSourceLicenses;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fraktal';

  @override
  String get appTagline => 'Portfolio tracking and fractal analysis lab';

  @override
  String get navMarkets => 'Markets';

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get navLab => 'Lab';

  @override
  String get navSettings => 'Settings';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get continueLabel => 'Continue';

  @override
  String get demoModeBanner =>
      'Demo mode: market data is synthetic and records are stored on this device only.';

  @override
  String get disclaimerTitle => 'Important notice';

  @override
  String get disclaimerBody =>
      'Fraktal is an educational and personal tracking tool. Nothing in the app — including calculations, simulations or optimizations — is investment advice or a recommendation to buy or sell. Monte Carlo, Markowitz and backtest results are probabilistic models based on historical data and do not guarantee future returns. Make investment decisions according to your own risk preferences and, if needed, with help from licensed professionals.';

  @override
  String get disclaimerShort => 'Not investment advice.';

  @override
  String get disclaimerAccept => 'I have read, understood and accept';

  @override
  String get dataSources => 'Data sources';

  @override
  String get dataSourcesBody =>
      'FX, gram gold and the BIST 100 index: CBRT EVDS (end of day). Crypto: CoinGecko. Stock and mutual fund prices require a license and are not published in the app; you enter your own prices for these assets. Data may be delayed and may contain errors.';

  @override
  String get typeFx => 'FX';

  @override
  String get typeGold => 'Gold';

  @override
  String get typeIndex => 'Index';

  @override
  String get typeCrypto => 'Crypto';

  @override
  String get typeStocksFunds => 'Stocks & Funds';

  @override
  String get manualPriceHint =>
      'Stock and fund prices require a license and are not shown. Enter your own current price for portfolio valuation.';

  @override
  String get enterPrice => 'Enter price';

  @override
  String get yourPrice => 'Your price';

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String asOf(String date) {
    return 'as of $date';
  }

  @override
  String get range1m => '1M';

  @override
  String get range3m => '3M';

  @override
  String get range1y => '1Y';

  @override
  String get range5y => '5Y';

  @override
  String get analyticsTitle => 'Fractal analysis';

  @override
  String get hurst => 'Hurst exponent';

  @override
  String get regimeTrending => 'Trending / persistent';

  @override
  String get regimeRandomWalk => 'Random walk';

  @override
  String get regimeMeanReverting => 'Mean reverting';

  @override
  String get volatility1y => 'Annual volatility';

  @override
  String get return1y => '1-year return';

  @override
  String get maxDrawdown => 'Max drawdown';

  @override
  String get createAlert => 'Create alert';

  @override
  String get alertAbove => 'Price rises above';

  @override
  String get alertBelow => 'Price falls below';

  @override
  String get alertPctUp => 'Daily gain at least (%)';

  @override
  String get alertPctDown => 'Daily drop at least (%)';

  @override
  String get priceThreshold => 'Price threshold';

  @override
  String get percentThreshold => 'Percent threshold';

  @override
  String get alertCreated => 'Alert created';

  @override
  String get alertEodNote =>
      'Alerts are checked against end-of-day data when it is updated.';

  @override
  String get alertsTitle => 'Price alerts';

  @override
  String get noAlerts =>
      'No alerts yet. Create one from an asset\'s detail page.';

  @override
  String get alertsNeedBackend =>
      'Alerts need a cloud account and are unavailable in demo mode.';

  @override
  String lastTriggered(String date) {
    return 'last: $date';
  }

  @override
  String get portfolios => 'My portfolios';

  @override
  String get newPortfolio => 'New portfolio';

  @override
  String get portfolioName => 'Portfolio name';

  @override
  String get noPortfolios =>
      'You have no portfolios yet. Create one and add your transactions.';

  @override
  String get marketValue => 'Market value';

  @override
  String get costBasis => 'Cost basis';

  @override
  String get unrealizedPnl => 'Unrealized P/L';

  @override
  String get realizedPnl => 'Realized P/L';

  @override
  String get dividends => 'Dividends';

  @override
  String get positions => 'Positions';

  @override
  String get transactions => 'Transactions';

  @override
  String get noTransactions => 'No transactions yet.';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get txBuy => 'Buy';

  @override
  String get txSell => 'Sell';

  @override
  String get txDividend => 'Dividend';

  @override
  String get txFee => 'Fee';

  @override
  String get txDeposit => 'Deposit';

  @override
  String get txWithdraw => 'Withdrawal';

  @override
  String get instrument => 'Asset';

  @override
  String get selectInstrument => 'Select an asset';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitPrice => 'Unit price';

  @override
  String get amount => 'Amount';

  @override
  String get fee => 'Commission';

  @override
  String get note => 'Note';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get priceMissing => 'Assets without a price are valued at cost.';

  @override
  String get sendToLab => 'Analyze in lab';

  @override
  String deletePortfolioConfirm(String name) {
    return 'Delete portfolio \"$name\" and all its transactions?';
  }

  @override
  String get deleteTransactionConfirm => 'Delete this transaction?';

  @override
  String ledgerError(String message) {
    return 'Inconsistent transaction history: $message';
  }

  @override
  String avgCost(String value) {
    return 'avg $value';
  }

  @override
  String quantityShort(String qty) {
    return '$qty units';
  }

  @override
  String get labTitle => 'Analysis lab';

  @override
  String get labIntro =>
      'Pick assets and set weights. All calculations run on your device.';

  @override
  String get labEmpty => 'Select at least one asset to start.';

  @override
  String get assets => 'Assets';

  @override
  String get selectAssets => 'Select assets';

  @override
  String get equalWeights => 'Equal weights';

  @override
  String get parameters => 'Parameters';

  @override
  String horizonDays(int days) {
    return 'Horizon: $days trading days';
  }

  @override
  String simulationsCount(int count) {
    return '$count simulations';
  }

  @override
  String daysShort(int days) {
    return '${days}d';
  }

  @override
  String get riskFree => 'Risk-free rate (annual)';

  @override
  String get jumps => 'Crisis jumps (Merton)';

  @override
  String get jumpsHint =>
      'Adds sudden shocks to the model for more realistic tail risk.';

  @override
  String get initialCapital => 'Initial capital';

  @override
  String get run => 'Run';

  @override
  String get running => 'Calculating…';

  @override
  String get tabSimulation => 'Simulation';

  @override
  String get tabFrontier => 'Optimization';

  @override
  String get tabBacktest => 'Backtest';

  @override
  String get tabFractal => 'Fractal';

  @override
  String dataWindow(int days, String start, String end) {
    return '$days common days · $start – $end';
  }

  @override
  String get notEnoughHistory =>
      'Not enough shared history for the selected assets (60 days required).';

  @override
  String get expectedValue => 'Expected value';

  @override
  String get median => 'Median';

  @override
  String get var95 => 'VaR 95%';

  @override
  String get var95Hint => '95% chance loss won\'t exceed this';

  @override
  String get cvar95 => 'CVaR 95%';

  @override
  String get cvar95Hint => 'Average loss in the worst 5%';

  @override
  String get probLoss => 'Probability of loss';

  @override
  String get percentileBand => '5% – 95% range';

  @override
  String get band25_75 => '25–75%';

  @override
  String get band5_95 => '5–95%';

  @override
  String get optimalWeights => 'Max Sharpe';

  @override
  String get minVariance => 'Min variance';

  @override
  String get currentPortfolio => 'Current';

  @override
  String get applyWeights => 'Apply weights';

  @override
  String get frontierAxes => 'X: annual volatility · Y: annual expected return';

  @override
  String get optimizerNote =>
      'No short selling; weights 0–100%. Historical averages may not reflect the future.';

  @override
  String get needTwoAssets => 'Select at least 2 assets to optimize.';

  @override
  String get sharpe => 'Sharpe';

  @override
  String get expectedReturnShort => 'return';

  @override
  String get volatilityShort => 'vol';

  @override
  String get totalReturn => 'Total return';

  @override
  String get cagr => 'Annual return (CAGR)';

  @override
  String get backtestNote =>
      'Daily-rebalanced constant-weight portfolio; excludes commissions and taxes.';

  @override
  String get hurstExplainer =>
      'Hurst exponent (R/S): H > 0.55 trending/persistent, H ≈ 0.5 random walk, H < 0.45 mean reverting.';

  @override
  String get correlation => 'Correlation';

  @override
  String get labDisclaimer =>
      'Results are probabilistic models based on historical data; they do not guarantee future returns and are not investment advice.';

  @override
  String get bulletinTitle => 'Bulletin analysis (AI)';

  @override
  String get bulletinHint => 'Paste a financial news or bulletin text';

  @override
  String get aiNotice =>
      'Text is sent to Google Gemini for analysis; do not include personal information.';

  @override
  String get analyze => 'Analyze';

  @override
  String get sentiment => 'Sentiment';

  @override
  String get useSentiment => 'Apply sentiment to simulation';

  @override
  String get quotaExceeded => 'Daily AI limit reached, try again tomorrow.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get guestAccount => 'Guest account';

  @override
  String get guestAccountHint =>
      'Your data is tied to this device\'s session. Link your email to keep it.';

  @override
  String get linkEmail => 'Link email';

  @override
  String get signInExisting => 'Sign in to existing account';

  @override
  String get signInWarning =>
      'Signing in hides this device\'s guest data. Linking an email first is recommended.';

  @override
  String get email => 'Email';

  @override
  String get code => 'Verification code';

  @override
  String get sendCode => 'Send code';

  @override
  String get verify => 'Verify';

  @override
  String codeSent(String email) {
    return 'A 6-digit code was sent to $email.';
  }

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirm =>
      'All your portfolios, transactions and alerts will be permanently deleted from the server. This cannot be undone.';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get security => 'Security';

  @override
  String get biometricLock => 'Biometric lock';

  @override
  String get biometricReason => 'Authenticate to open Fraktal';

  @override
  String get biometricUnavailable =>
      'Biometric authentication is not available on this device.';

  @override
  String get unlock => 'Unlock';

  @override
  String get legal => 'Legal';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get terms => 'Terms of use';

  @override
  String get openSourceLicenses => 'Open source licenses';
}

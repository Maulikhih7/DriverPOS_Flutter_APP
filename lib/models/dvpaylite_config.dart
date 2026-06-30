import 'package:shared_preferences/shared_preferences.dart';

const _kPrefix = 'dvpaylite_';

class DvPayLiteConfig {
  static const fontFamilies = ['Inter', 'Roboto', 'Open Sans', 'Poppins', 'Lato'];
  static const receiptTypes = ['No', 'Merchant', 'Customer', 'Both'];

  final String primaryColor;
  final String secondaryColor;
  final String negativeButtonColor;
  final String fontFamily;
  final bool removeLoaderLogo;
  final bool requiredAvs;
  final bool showBreakupScreen;
  final bool showTipScreen;
  final bool showDualPriceScreen;
  final String receiptType;
  final bool showTxnStatusScreen;

  const DvPayLiteConfig({
    this.primaryColor = '7FB069',
    this.secondaryColor = '141414',
    this.negativeButtonColor = 'C01C2D',
    this.fontFamily = 'Roboto',
    this.removeLoaderLogo = false,
    this.requiredAvs = false,
    this.showBreakupScreen = false,
    this.showTipScreen = false,
    this.showDualPriceScreen = false,
    this.receiptType = 'No',
    this.showTxnStatusScreen = true,
  });

  DvPayLiteConfig copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? negativeButtonColor,
    String? fontFamily,
    bool? removeLoaderLogo,
    bool? requiredAvs,
    bool? showBreakupScreen,
    bool? showTipScreen,
    bool? showDualPriceScreen,
    String? receiptType,
    bool? showTxnStatusScreen,
  }) {
    return DvPayLiteConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      negativeButtonColor: negativeButtonColor ?? this.negativeButtonColor,
      fontFamily: fontFamily ?? this.fontFamily,
      removeLoaderLogo: removeLoaderLogo ?? this.removeLoaderLogo,
      requiredAvs: requiredAvs ?? this.requiredAvs,
      showBreakupScreen: showBreakupScreen ?? this.showBreakupScreen,
      showTipScreen: showTipScreen ?? this.showTipScreen,
      showDualPriceScreen: showDualPriceScreen ?? this.showDualPriceScreen,
      receiptType: receiptType ?? this.receiptType,
      showTxnStatusScreen: showTxnStatusScreen ?? this.showTxnStatusScreen,
    );
  }

  static Future<DvPayLiteConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return DvPayLiteConfig(
      primaryColor: p.getString('${_kPrefix}primaryColor') ?? '7FB069',
      secondaryColor: p.getString('${_kPrefix}secondaryColor') ?? '141414',
      negativeButtonColor: p.getString('${_kPrefix}negativeButtonColor') ?? 'C01C2D',
      fontFamily: p.getString('${_kPrefix}fontFamily') ?? 'Roboto',
      removeLoaderLogo: p.getBool('${_kPrefix}removeLoaderLogo') ?? false,
      requiredAvs: p.getBool('${_kPrefix}requiredAvs') ?? false,
      showBreakupScreen: p.getBool('${_kPrefix}showBreakupScreen') ?? false,
      showTipScreen: p.getBool('${_kPrefix}showTipScreen') ?? false,
      showDualPriceScreen: p.getBool('${_kPrefix}showDualPriceScreen') ?? false,
      receiptType: p.getString('${_kPrefix}receiptType') ?? 'No',
      showTxnStatusScreen: p.getBool('${_kPrefix}showTxnStatusScreen') ?? true,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_kPrefix}primaryColor', primaryColor);
    await p.setString('${_kPrefix}secondaryColor', secondaryColor);
    await p.setString('${_kPrefix}negativeButtonColor', negativeButtonColor);
    await p.setString('${_kPrefix}fontFamily', fontFamily);
    await p.setBool('${_kPrefix}removeLoaderLogo', removeLoaderLogo);
    await p.setBool('${_kPrefix}requiredAvs', requiredAvs);
    await p.setBool('${_kPrefix}showBreakupScreen', showBreakupScreen);
    await p.setBool('${_kPrefix}showTipScreen', showTipScreen);
    await p.setBool('${_kPrefix}showDualPriceScreen', showDualPriceScreen);
    await p.setString('${_kPrefix}receiptType', receiptType);
    await p.setBool('${_kPrefix}showTxnStatusScreen', showTxnStatusScreen);
  }

  /// Returns the full map of args to merge into the performSale call.
  Map<String, dynamic> toPaymentArgs() => {
        'customUI': {
          'fontFamily': fontFamily.toLowerCase(),
          'primaryColor': primaryColor,
          'secondaryColor': secondaryColor,
          'negativeButtonColor': negativeButtonColor,
          'removeLoaderLogo': removeLoaderLogo ? 'YES' : 'NO',
          'requiredAvs': requiredAvs ? 'YES' : 'NO',
        },
        'showBreakupScreen': showBreakupScreen ? 'Yes' : 'No',
        'showTipScreen': showTipScreen ? 'Yes' : 'No',
        'showDualPriceScreen': showDualPriceScreen ? 'Yes' : 'No',
        'receiptType': receiptType,
        'isTxnStatusScreenRequired': showTxnStatusScreen ? 'Yes' : 'No',
      };
}

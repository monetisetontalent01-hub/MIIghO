import 'package:flutter/material.dart';

class MiighoStrings {
  final Locale locale;
  MiighoStrings(this.locale);

  static MiighoStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return MiighoStrings(locale);
  }

  String get languageCode => locale.languageCode;

  // General & Brand
  String get appName => 'MÏÏghO';
  String get appTagline {
    switch (languageCode) {
      case 'en': return 'Pan-African Modular Digital Ecosystem';
      case 'sw': return 'Mfumo wa Dijitali wa Afrika';
      case 'ar': return 'المنظومة الرقمية الإفريقية الموحدة';
      default: return 'Écosystème Numérique Panafricain';
    }
  }

  String get greeting {
    switch (languageCode) {
      case 'en': return 'Hello';
      case 'sw': return 'Habari';
      case 'ar': return 'مرحباً';
      default: return 'Bonjour';
    }
  }

  // Navigation
  String get navHome {
    switch (languageCode) {
      case 'en': return 'Home';
      case 'sw': return 'Nyumbani';
      case 'ar': return 'الرئيسية';
      default: return 'Accueil';
    }
  }

  String get navChat {
    switch (languageCode) {
      case 'en': return 'Chat';
      case 'sw': return 'Mazungumzo';
      case 'ar': return 'المحادثات';
      default: return 'Chat';
    }
  }

  String get navPay {
    switch (languageCode) {
      case 'en': return 'Pay';
      case 'sw': return 'Malipo';
      case 'ar': return 'المدفوعات';
      default: return 'Pay';
    }
  }

  String get navMore {
    switch (languageCode) {
      case 'en': return 'More';
      case 'sw': return 'Zaidi';
      case 'ar': return 'المزيد';
      default: return 'Plus';
    }
  }

  String get navContacts {
    switch (languageCode) {
      case 'en': return 'Contacts';
      case 'sw': return 'Watu';
      case 'ar': return 'جهات الاتصال';
      default: return 'Contacts';
    }
  }

  String get navSettings {
    switch (languageCode) {
      case 'en': return 'Settings';
      case 'sw': return 'Mipangilio';
      case 'ar': return 'الإعدادات';
      default: return 'Paramètres';
    }
  }

  // Quick Actions
  String get actionSend {
    switch (languageCode) {
      case 'en': return 'Send';
      case 'sw': return 'Tuma';
      case 'ar': return 'إرسال';
      default: return 'Envoyer';
    }
  }

  String get actionReceive {
    switch (languageCode) {
      case 'en': return 'Receive';
      case 'sw': return 'Pokea';
      case 'ar': return 'استلام';
      default: return 'Recevoir';
    }
  }

  String get actionReload {
    switch (languageCode) {
      case 'en': return 'Top-Up';
      case 'sw': return 'Ongeza';
      case 'ar': return 'شحن';
      default: return 'Recharger';
    }
  }

  String get actionScan {
    switch (languageCode) {
      case 'en': return 'Scan QR';
      case 'sw': return 'Changanua QR';
      case 'ar': return 'مسح QR';
      default: return 'Scanner';
    }
  }

  String get actionNewChat {
    switch (languageCode) {
      case 'en': return 'New Chat';
      case 'sw': return 'Mazungumzo Mapya';
      case 'ar': return 'محادثة جديدة';
      default: return 'Nouveau Chat';
    }
  }

  // Dashboard Sections
  String get walletBalanceTitle {
    switch (languageCode) {
      case 'en': return 'Available Balance (Sandbox)';
      case 'sw': return 'Salio Linalopatikana (Jaribio)';
      case 'ar': return 'الرصيد المتاح (تجريبي)';
      default: return 'Solde disponible (Sandbox)';
    }
  }

  String get quickActionsTitle {
    switch (languageCode) {
      case 'en': return 'Quick Actions';
      case 'sw': return 'Hatua za Haraka';
      case 'ar': return 'إجراءات سريعة';
      default: return 'Actions Rapides';
    }
  }

  String get ecosystemTitle {
    switch (languageCode) {
      case 'en': return 'Your MÏÏghO Ecosystem';
      case 'sw': return 'Mfumo wako wa MÏÏghO';
      case 'ar': return 'منظومة MÏÏghO الخاصة بك';
      default: return 'Votre écosystème MÏÏghO';
    }
  }

  String get recentActivityTitle {
    switch (languageCode) {
      case 'en': return 'Recent Activity';
      case 'sw': return 'Shughuli za Hivi Karibuni';
      case 'ar': return 'النشاط الأخير';
      default: return 'Activité Récente';
    }
  }

  String get unreadMessages {
    switch (languageCode) {
      case 'en': return 'unread messages';
      case 'sw': return 'ujumbe ambao haujasomwa';
      case 'ar': return 'رسائل غير مقروءة';
      default: return 'messages non lus';
    }
  }

  // Status Labels
  String get statusActive {
    switch (languageCode) {
      case 'en': return 'Active';
      case 'sw': return 'Inafanya kazi';
      case 'ar': return 'نشط';
      default: return 'Actif';
    }
  }

  String get statusBeta {
    switch (languageCode) {
      case 'en': return 'Beta';
      case 'sw': return 'Beta';
      case 'ar': return 'بيتا';
      default: return 'Bêta';
    }
  }

  String get statusPrototype {
    switch (languageCode) {
      case 'en': return 'Prototype';
      case 'sw': return 'Mfano';
      case 'ar': return 'نموذج أولي';
      default: return 'Prototype';
    }
  }

  String get statusDevelopment {
    switch (languageCode) {
      case 'en': return 'In Development';
      case 'sw': return 'Inaendelezwa';
      case 'ar': return 'قيد التطوير';
      default: return 'En développement';
    }
  }

  String get statusComingSoon {
    switch (languageCode) {
      case 'en': return 'Coming Soon';
      case 'sw': return 'Inakuja Hivi Karibuni';
      case 'ar': return 'قريباً';
      default: return 'Bientôt disponible';
    }
  }

  // Modules
  String get moduleChatDesc {
    switch (languageCode) {
      case 'en': return 'Sovereign instant messaging, private & group conversations';
      case 'sw': return 'Ujumbe wa papo hapo, mazungumzo ya faragha na ya kikundi';
      case 'ar': return 'مراسلة فورية سيادية، محادثات خاصة وجماعية';
      default: return 'Messagerie instantanée souveraine, discussions privées et groupes';
    }
  }

  String get modulePayDesc {
    switch (languageCode) {
      case 'en': return 'Unified wallet, simulated sandbox & ledger-ready accounting';
      case 'sw': return 'Pochi ya pamoja, miamala ya majaribio na uhasibu wa ledger';
      case 'ar': return 'محفظة مالية موحدة، بيئة تجريبية ومحاسبة دفتر الأستاذ';
      default: return 'Portefeuille unifié, transferts sandbox & comptabilité ledger';
    }
  }

  String get moduleBusinessDesc {
    switch (languageCode) {
      case 'en': return 'B2B Suite, invoices, client management & payment QR';
      case 'sw': return 'Zana za biashara, ankara, usimamizi wa wateja na QR ya malipo';
      case 'ar': return 'أدوات الأعمال B2B، الفواتير، إدارة العملاء ورمز الاستجابة السريعة';
      default: return 'Suite B2B, facturation, encaissements QR & rapports d\'activité';
    }
  }

  String get moduleMarketDesc {
    switch (languageCode) {
      case 'en': return 'Pan-African marketplace with secure escrow transactions';
      case 'sw': return 'Soko la pamoja la Afrika lenye ununuzi salama wa escrow';
      case 'ar': return 'سوق إفريقي موحد مع نظام دفع محمي بالضمان';
      default: return 'Marketplace panafricaine avec sécurisation des fonds par Escrow';
    }
  }

  String get moduleCloudDesc {
    switch (languageCode) {
      case 'en': return 'Sovereign Cloud storage & encrypted document sharing';
      case 'sw': return 'Uhifadhi wa wingu na ushiriki wa nyaraka zilizolindwa';
      case 'ar': return 'سحابة تخزين سيادية ومشاركة آمنة للمستندات';
      default: return 'Stockage cloud souverain & partage sécurisé de documents';
    }
  }

  String get moduleMediaAIDesc {
    switch (languageCode) {
      case 'en': return 'Contextual AI assistant adapted to African languages';
      case 'sw': return 'Msaidizi wa akili bandia anayejua lugha za Kiafrika';
      case 'ar': return 'مساعد ذكاء اصطناعي مخصص للغات والسياق الإفريقي';
      default: return 'Assistant d\'intelligence artificielle adapté aux contextes africains';
    }
  }

  String get moduleDevDesc {
    switch (languageCode) {
      case 'en': return 'Developer platform, unified APIs, SDKs & Webhooks';
      case 'sw': return 'Jukwaa la watengenezaji, API za pamoja na SDK';
      case 'ar': return 'منصة المطورين، واجهات برمجة موحدة وحزم SDK';
      default: return 'Portail développeurs, APIs unifiées, SDKs & Webhooks';
    }
  }
}

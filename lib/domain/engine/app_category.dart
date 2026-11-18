import '../../platform/notification_platform_interface.dart';

// Android ApplicationInfo.CATEGORY_* values.
const _androidCategorySocial = 4;
const _androidCategoryProductivity = 7;

const _messagingWords = [
  'whatsapp',
  'telegram',
  'signal',
  'message',
  'chat',
  'sms',
];
const _socialWords = [
  'insta',
  'facebook',
  'twitter',
  'x.com',
  'tiktok',
  'youtube',
  'snapchat',
  'reddit',
];
const _productivityWords = [
  'slack',
  'teams',
  'meet',
  'zoom',
  'jira',
  'notion',
  'trello',
  'gmail',
  'outlook',
  'mail',
];

/// Picks the Add Apps tab for [app]: messaging keywords, then Android's own
/// category, then social/productivity keywords, then the real system flag;
/// anything else is "other".
String appCategoryFor(DiscoveredAppInfo app) {
  final text = '${app.displayName} ${app.packageName}'.toLowerCase();
  bool has(List<String> words) => words.any(text.contains);

  if (has(_messagingWords)) {
    return 'messaging';
  }
  if (app.androidCategory == _androidCategorySocial) {
    return 'social';
  }
  if (app.androidCategory == _androidCategoryProductivity) {
    return 'productivity';
  }
  if (has(_socialWords)) {
    return 'social';
  }
  if (has(_productivityWords)) {
    return 'productivity';
  }
  if (app.isSystemApp) {
    return 'system';
  }
  return 'other';
}

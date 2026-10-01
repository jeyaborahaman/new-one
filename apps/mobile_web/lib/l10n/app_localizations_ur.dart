// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get navHome => 'ہوم';

  @override
  String get navReels => 'ریلز';

  @override
  String get navCreate => 'بنائیں';

  @override
  String get navChats => 'چیٹس';

  @override
  String get navProfile => 'پروفائل';

  @override
  String get somethingWentWrong => 'کچھ غلط ہو گیا';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String storyRingSemantic(String state, String name) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'seen': '$name کی اسٹوری، دیکھی جا چکی',
      'other': '$name کی نئی اسٹوری',
    });
    return '$_temp0';
  }

  @override
  String get errorNetwork => 'سرور تک رسائی نہیں ہو سکی۔ اپنا کنکشن چیک کریں۔';

  @override
  String errorGeneric(String code) {
    return 'کچھ غلط ہو گیا ($code)';
  }

  @override
  String get uploadFailedNetwork => 'اپ لوڈ ناکام ہو گیا۔ اپنا کنکشن چیک کریں۔';

  @override
  String uploadFailedCode(String code) {
    return 'اپ لوڈ ناکام ہو گیا ($code)۔';
  }

  @override
  String get timeNow => 'ابھی';

  @override
  String timeMinutes(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString منٹ';
  }

  @override
  String timeHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString گھنٹے';
  }

  @override
  String timeDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString دن';
  }

  @override
  String get verified => 'تصدیق شدہ';

  @override
  String reactionName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'like': 'پسند',
      'love': 'محبت',
      'wow': 'واہ',
      'laugh': 'ہنسی',
      'sad': 'اداس',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String get authWelcomeBack => 'خوش آمدید';

  @override
  String get authSignInSubtitle =>
      'سائن ان کریں اور دیکھیں آپ کے دوست کیا کر رہے ہیں۔';

  @override
  String get authTwoStepTitle => 'دو مرحلہ تصدیق';

  @override
  String get authTwoStepSubtitle =>
      'اپنی تصدیقی ایپ سے 6 ہندسوں کا کوڈ یا بیک اپ کوڈ درج کریں۔';

  @override
  String get fieldEmailOrUsername => 'ای میل یا صارف نام';

  @override
  String get fieldPassword => 'پاس ورڈ';

  @override
  String get showPassword => 'پاس ورڈ دکھائیں';

  @override
  String get hidePassword => 'پاس ورڈ چھپائیں';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get fieldCode => 'کوڈ';

  @override
  String get verify => 'تصدیق کریں';

  @override
  String get signIn => 'سائن ان';

  @override
  String get continueWithPhone => 'فون کے ساتھ جاری رکھیں';

  @override
  String get newHere => 'یہاں نئے ہیں؟';

  @override
  String get createAccount => 'اکاؤنٹ بنائیں';

  @override
  String get backToSignIn => 'سائن ان پر واپس جائیں';

  @override
  String get errorEnterCredentials =>
      'اپنا ای میل یا صارف نام اور پاس ورڈ درج کریں';

  @override
  String get registerTitle => 'اپنا اکاؤنٹ بنائیں';

  @override
  String get registerSubtitle => 'کمیونٹی میں شامل ہوں۔ صرف ایک منٹ لگے گا۔';

  @override
  String get fieldDisplayNameOptional => 'ڈسپلے نام (اختیاری)';

  @override
  String get fieldUsername => 'صارف نام';

  @override
  String get usernameHelper => '3 سے 30 انگریزی حروف، ہندسے یا _';

  @override
  String get usernameInvalid => '3 سے 30 انگریزی حروف، ہندسے یا _ استعمال کریں';

  @override
  String get fieldEmail => 'ای میل';

  @override
  String get emailInvalid => 'درست ای میل درج کریں';

  @override
  String get passwordHelper => 'کم از کم 8 حروف';

  @override
  String get passwordTooShort => 'کم از کم 8 حروف';

  @override
  String get fieldReferralOptional => 'ریفرل کوڈ (اختیاری)';

  @override
  String get phoneTitleEnterCode => 'کوڈ درج کریں';

  @override
  String get phoneTitle => 'آپ کا فون نمبر';

  @override
  String phoneCodeSent(String phone) {
    return 'ہم نے $phone پر 6 ہندسوں کا کوڈ بھیجا ہے۔';
  }

  @override
  String phoneFormatHint(String example) {
    return 'بین الاقوامی فارمیٹ استعمال کریں، مثلاً $example۔';
  }

  @override
  String get fieldPhone => 'فون نمبر';

  @override
  String get field2faCode => 'دو مرحلہ تصدیق کا کوڈ';

  @override
  String get sendCode => 'کوڈ بھیجیں';

  @override
  String get resetTitle => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get resetSentSubtitle =>
      'اگر اس ای میل پر اکاؤنٹ موجود ہے تو کوڈ بھیج دیا گیا ہے۔';

  @override
  String get resetSubtitle => 'ہم آپ کو 6 ہندسوں کا کوڈ ای میل کریں گے۔';

  @override
  String get fieldNewPassword => 'نیا پاس ورڈ';

  @override
  String get passwordUpdated =>
      'پاس ورڈ اپ ڈیٹ ہو گیا۔ نئے پاس ورڈ سے سائن ان کریں۔';

  @override
  String get updatePassword => 'پاس ورڈ اپ ڈیٹ کریں';

  @override
  String get search => 'تلاش';

  @override
  String get notifications => 'اطلاعات';

  @override
  String get feedEmptyTitle => 'آپ کی فیڈ خاموش ہے';

  @override
  String get feedEmptyMessage => 'لوگوں کو فالو کریں یا اپنی پہلی پوسٹ بنائیں۔';

  @override
  String get yourStory => 'آپ کی اسٹوری';

  @override
  String get addToYourStory => 'اپنی اسٹوری میں شامل کریں';

  @override
  String userStorySemantic(String name) {
    return '$name کی اسٹوری';
  }

  @override
  String levelShort(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'لیول $levelString';
  }

  @override
  String get imageUnavailable => 'تصویر دستیاب نہیں';

  @override
  String commentsSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تبصرے، $countString';
  }

  @override
  String reactSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'ردِعمل دیں، $countString ردِعمل';
  }

  @override
  String yourReactionSemantic(String reaction, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'آپ کا ردِعمل: $reaction، $countString ردِعمل۔ ہٹانے کے لیے تھپتھپائیں';
  }

  @override
  String get reactHint => 'مزید ردِعمل کے لیے دیر تک دبائیں';

  @override
  String pollVotes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ووٹ',
      one: '1 ووٹ',
    );
    return '$_temp0';
  }

  @override
  String get commentsTitle => 'تبصرے';

  @override
  String get reply => 'جواب دیں';

  @override
  String get viewReplies => 'جوابات دیکھیں';

  @override
  String get noComments => 'ابھی کوئی تبصرہ نہیں۔ گفتگو شروع کریں۔';

  @override
  String replyingTo(String name) {
    return '$name کو جواب';
  }

  @override
  String get cancelReply => 'جواب منسوخ کریں';

  @override
  String get addComment => 'تبصرہ شامل کریں';

  @override
  String get sendComment => 'تبصرہ بھیجیں';

  @override
  String get someone => 'کوئی';

  @override
  String couldNotOpenGallery(String error) {
    return 'گیلری نہیں کھل سکی: $error';
  }

  @override
  String get composerEmpty => 'کچھ لکھیں یا تصویر یا ویڈیو شامل کریں';

  @override
  String get pollNeedsTwo => 'پول کے لیے کم از کم 2 آپشن ضروری ہیں';

  @override
  String get posted => 'پوسٹ ہو گئی';

  @override
  String get scheduled => 'شیڈول ہو گئی';

  @override
  String get pickFutureTime => 'مستقبل کا کوئی وقت منتخب کریں';

  @override
  String get newPost => 'نئی پوسٹ';

  @override
  String get close => 'بند کریں';

  @override
  String get post => 'پوسٹ کریں';

  @override
  String get schedule => 'شیڈول';

  @override
  String get composerHint =>
      'آپ کیا سوچ رہے ہیں؟ #ہیش_ٹیگز اور @مینشنز استعمال کریں';

  @override
  String get uploading => 'اپ لوڈ ہو رہا ہے';

  @override
  String get shortReel => 'مختصر ریل';

  @override
  String get regularVideo => 'عام ویڈیو';

  @override
  String pollOption(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'آپشن $nString';
  }

  @override
  String get addOption => 'آپشن شامل کریں';

  @override
  String get photo => 'تصویر';

  @override
  String get video => 'ویڈیو';

  @override
  String get poll => 'پول';

  @override
  String scheduledAt(String date) {
    return '$date کو';
  }

  @override
  String get clearSchedule => 'شیڈول ختم کریں';

  @override
  String get whoCanSee => 'یہ کون دیکھ سکتا ہے';

  @override
  String get visibilityPublic => 'عوامی';

  @override
  String get visibilityFollowers => 'فالوورز';

  @override
  String get visibilityPrivate => 'صرف میں';

  @override
  String get selectedPhoto => 'منتخب تصویر';

  @override
  String fileSize(String name, String size) {
    return '$name · $size MB';
  }

  @override
  String get removeAttachment => 'منسلکہ ہٹائیں';

  @override
  String couldNotOpen(String error) {
    return 'یہ نہیں کھل سکا: $error';
  }

  @override
  String get storyShared => 'اسٹوری 24 گھنٹوں کے لیے شیئر ہو گئی';

  @override
  String get newStory => 'نئی اسٹوری';

  @override
  String get share => 'شیئر کریں';

  @override
  String get shareMoment => 'کوئی لمحہ شیئر کریں';

  @override
  String get storiesDisappear => 'اسٹوریز 24 گھنٹے بعد غائب ہو جاتی ہیں۔';

  @override
  String get storyPreview => 'اسٹوری کا پیش منظر';

  @override
  String get addCaption => 'کیپشن شامل کریں';

  @override
  String get chooseDifferentFile => 'کوئی اور فائل منتخب کریں';

  @override
  String reactionSent(String emoji) {
    return '$emoji بھیج دیا';
  }

  @override
  String get storyUnavailable => 'اسٹوری دستیاب نہیں';

  @override
  String storyViews(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ویوز',
      one: '1 ویو',
    );
    return '$_temp0';
  }

  @override
  String reactWith(String reaction) {
    return '$reaction سے ردِعمل دیں';
  }

  @override
  String get videoUnavailable => 'ویڈیو دستیاب نہیں';

  @override
  String playVideo(String title) {
    return 'ویڈیو چلائیں $title';
  }

  @override
  String get forYou => 'آپ کے لیے';

  @override
  String get trending => 'مقبول';

  @override
  String get noReels => 'ابھی کوئی ریل نہیں';

  @override
  String get noReelsMessage => 'مختصر ویڈیوز یہاں نظر آئیں گی۔';

  @override
  String get loved => 'پسند آیا';

  @override
  String get chats => 'چیٹس';

  @override
  String get chat => 'چیٹ';

  @override
  String get newChat => 'نئی چیٹ';

  @override
  String get noConversations => 'ابھی کوئی گفتگو نہیں';

  @override
  String get noConversationsMessage => 'کسی دوست کو ڈھونڈیں اور سلام کہیں۔';

  @override
  String get startChat => 'چیٹ شروع کریں';

  @override
  String get noMessagesYet => 'ابھی کوئی پیغام نہیں';

  @override
  String get sayHello => 'سلام کہیں';

  @override
  String unreadCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString غیر پڑھے';
  }

  @override
  String get typing => 'لکھ رہے ہیں…';

  @override
  String get sending => 'بھیجا جا رہا ہے…';

  @override
  String get messageHint => 'پیغام';

  @override
  String get send => 'بھیجیں';

  @override
  String messageNotSent(String error) {
    return 'پیغام نہیں بھیجا جا سکا: $error';
  }

  @override
  String sentMedia(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'image': 'تصویر بھیجی',
      'video': 'ویڈیو بھیجی',
      'voice': 'صوتی پیغام بھیجا',
      'file': 'فائل بھیجی',
      'sticker': 'اسٹیکر بھیجا',
      'other': '$type بھیجا',
    });
    return '$_temp0';
  }

  @override
  String get profile => 'پروفائل';

  @override
  String get editProfile => 'پروفائل میں ترمیم';

  @override
  String get walletAndRewards => 'والٹ اور انعامات';

  @override
  String get leaderboard => 'لیڈر بورڈ';

  @override
  String get inviteFriends => 'دوستوں کو مدعو کریں';

  @override
  String yourCode(String code) {
    return 'آپ کا کوڈ: $code';
  }

  @override
  String get copyCode => 'کوڈ کاپی کریں';

  @override
  String get codeCopied => 'کوڈ کاپی ہو گیا';

  @override
  String get themeAuto => 'خودکار';

  @override
  String get themeLight => 'لائٹ';

  @override
  String get themeDark => 'ڈارک';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get displayName => 'ڈسپلے نام';

  @override
  String get bio => 'تعارف';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get luckyDraw => 'لکی ڈرا';

  @override
  String get statFollowers => 'فالوورز';

  @override
  String get statFollowing => 'فالوئنگ';

  @override
  String get followingButton => 'فالو کر رہے ہیں';

  @override
  String get follow => 'فالو کریں';

  @override
  String get message => 'پیغام بھیجیں';

  @override
  String levelXp(int level, int xp) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return 'لیول $levelString · $xpString XP';
  }

  @override
  String get language => 'زبان';

  @override
  String get languageSystem => 'ڈیوائس کی زبان';

  @override
  String get findSomeone => 'پیغام بھیجنے کے لیے کسی کو تلاش کریں';

  @override
  String get searchHint => 'لوگ، پوسٹس اور #ٹیگز تلاش کریں';

  @override
  String get peopleYouMayKnow => 'وہ لوگ جنہیں آپ شاید جانتے ہوں';

  @override
  String mutualCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString مشترکہ';
  }

  @override
  String get noResults => 'کوئی نتیجہ نہیں';

  @override
  String nothingFound(String query) {
    return '\"$query\" کے لیے کچھ نہیں ملا۔';
  }

  @override
  String followersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فالوورز',
      one: '1 فالوور',
    );
    return '$_temp0';
  }

  @override
  String hashtagPosts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString پوسٹس',
      one: '1 پوسٹ',
    );
    return '$_temp0';
  }

  @override
  String get postsHeader => 'پوسٹس';

  @override
  String streakReward(int streak, int coins) {
    final intl.NumberFormat streakNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String streakString = streakNumberFormat.format(streak);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$streakString دن کا سلسلہ: +$coinsString سکے';
  }

  @override
  String get rewardClaimed => 'انعام وصول ہو گیا';

  @override
  String get coins => 'سکے';

  @override
  String get claimDaily => 'روزانہ انعام وصول کریں';

  @override
  String get badges => 'بیجز';

  @override
  String get noBadges =>
      'ابھی کوئی بیج نہیں۔ بیج حاصل کرنے کے لیے پوسٹ کریں، تبصرہ کریں اور دوستوں کو مدعو کریں۔';

  @override
  String get challenges => 'چیلنجز';

  @override
  String challengeProgress(int progress, int target, int coins) {
    final intl.NumberFormat progressNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String progressString = progressNumberFormat.format(progress);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$progressString/$targetString · +$coinsString سکے';
  }

  @override
  String get join => 'شامل ہوں';

  @override
  String get claim => 'وصول کریں';

  @override
  String get history => 'تاریخچہ';

  @override
  String get noTransactions => 'ابھی کوئی لین دین نہیں۔';

  @override
  String txReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'daily': 'روزانہ انعام',
      'referral': 'ریفرل',
      'luckydraw': 'لکی ڈرا',
      'challenge': 'چیلنج',
      'other': '$reason',
    });
    return '$_temp0';
  }

  @override
  String badgeName(String code, String name) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'first_post': 'پہلی پوسٹ',
      'chatterbox': 'باتونی',
      'popular': 'مقبول',
      'level_5': 'لیول 5',
      'streak_7': 'ہفتہ وار سلسلہ',
      'connector': 'رابطہ کار',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String get thisWeek => 'اس ہفتے';

  @override
  String get allTime => 'ہر وقت';

  @override
  String get noActivity => 'ابھی کوئی سرگرمی نہیں';

  @override
  String levelN(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'لیول $levelString';
  }

  @override
  String xpCount(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return '$xpString XP';
  }

  @override
  String get allCaughtUp => 'سب کچھ دیکھ لیا';

  @override
  String get newActivity => 'نئی سرگرمی یہاں نظر آئے گی۔';

  @override
  String get notAvailable => 'دستیاب نہیں';

  @override
  String get luckyRegion => 'لکی ڈرا ابھی آپ کے علاقے میں دستیاب نہیں۔';

  @override
  String get noCampaigns => 'ابھی کوئی مہم نہیں';

  @override
  String campaignStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'open': 'کھلا',
      'closed': 'بند',
      'published': 'نتائج جاری',
      'cancelled': 'منسوخ',
      'draft': 'مسودہ',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String get freeEntry => 'مفت اندراج';

  @override
  String coinsPerEntry(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'فی اندراج $coinsString سکے';
  }

  @override
  String entryTerms(String price, int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$price · زیادہ سے زیادہ $maxString اندراجات';
  }

  @override
  String entered(int entries, int max) {
    final intl.NumberFormat entriesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String entriesString = entriesNumberFormat.format(entries);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'اندراج ہو گیا! آپ کے $maxString میں سے $entriesString اندراجات ہیں';
  }

  @override
  String get getEntry => 'اندراج حاصل کریں';

  @override
  String get callAudio => 'آڈیو کال';

  @override
  String get callVideo => 'ویڈیو کال';

  @override
  String get callIncomingAudio => 'آنے والی آڈیو کال';

  @override
  String get callIncomingVideo => 'آنے والی ویڈیو کال';

  @override
  String get callCalling => 'کال کی جا رہی ہے…';

  @override
  String get callConnecting => 'کنیکٹ ہو رہا ہے…';

  @override
  String get callReconnecting => 'دوبارہ کنیکٹ ہو رہا ہے…';

  @override
  String callEndReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'declined': 'کال مسترد کر دی گئی',
      'busy': 'مصروف',
      'noAnswer': 'کوئی جواب نہیں',
      'missed': 'مِسڈ کال',
      'answeredElsewhere': 'دوسرے آلے پر جواب دیا گیا',
      'failed': 'کال ناکام ہو گئی',
      'permissionDenied': 'کال کرنے کے لیے مائیکروفون اور کیمرے تک رسائی دیں',
      'notConfigured': 'کالز ابھی دستیاب نہیں',
      'other': 'کال ختم ہو گئی',
    });
    return '$_temp0';
  }

  @override
  String get acceptCall => 'جواب دیں';

  @override
  String get declineCall => 'مسترد کریں';

  @override
  String get endCall => 'کال ختم کریں';

  @override
  String get mute => 'خاموش کریں';

  @override
  String get unmute => 'آواز کھولیں';

  @override
  String get cameraOff => 'کیمرا بند کریں';

  @override
  String get cameraOn => 'کیمرا آن کریں';

  @override
  String get switchCamera => 'کیمرا بدلیں';

  @override
  String get cameraShort => 'کیمرا';

  @override
  String get flipShort => 'پلٹیں';

  @override
  String get speaker => 'اسپیکر';

  @override
  String get minimize => 'چھوٹا کریں';

  @override
  String get returnToCall => 'کال پر واپس جانے کے لیے تھپتھپائیں';

  @override
  String get callsTitle => 'کالز';

  @override
  String get callHistory => 'کالز کی تاریخ';

  @override
  String get noCalls => 'ابھی کوئی کال نہیں';

  @override
  String get noCallsMessage => 'آپ کی کالز یہاں نظر آئیں گی۔';

  @override
  String get callOutgoing => 'آؤٹ گوئنگ';

  @override
  String get callIncoming => 'اِن کمنگ';

  @override
  String get callMissedLabel => 'مِسڈ';

  @override
  String get callDeclinedLabel => 'مسترد';

  @override
  String get callBack => 'واپس کال کریں';

  @override
  String get openSettings => 'سیٹنگز کھولیں';

  @override
  String get callsUnavailable => 'کالز موبائل ایپ میں دستیاب ہیں۔';

  @override
  String get callNotRinging => 'یہ کال ختم ہو چکی ہے۔';

  @override
  String get moreOptions => 'مزید اختیارات';

  @override
  String get reportUser => 'رپورٹ کریں';

  @override
  String get blockUser => 'بلاک کریں';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String blockConfirmTitle(String name) {
    return '$name کو بلاک کریں؟';
  }

  @override
  String get blockConfirmBody =>
      'وہ آپ کی پروفائل یا پوسٹس نہیں دیکھ سکیں گے، نہ آپ کو فالو، پیغام یا کال کر سکیں گے۔ انہیں نہیں بتایا جائے گا کہ آپ نے انہیں بلاک کیا ہے۔';

  @override
  String userBlocked(String name) {
    return '$name کو بلاک کر دیا گیا';
  }

  @override
  String reportTitle(String name) {
    return '$name کی رپورٹ کریں';
  }

  @override
  String get reportReasonPrompt => 'آپ اس اکاؤنٹ کی رپورٹ کیوں کر رہے ہیں؟';

  @override
  String reportReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'spam': 'اسپیم',
      'harassment': 'ہراسانی یا دھونس',
      'hate': 'نفرت انگیز بات',
      'sexual': 'جنسی مواد',
      'violence': 'تشدد یا دھمکی',
      'self_harm': 'خود کو نقصان یا خودکشی',
      'other': 'کچھ اور',
    });
    return '$_temp0';
  }

  @override
  String get reportDetailsHint => 'تفصیلات شامل کریں (اختیاری)';

  @override
  String get submitReport => 'رپورٹ بھیجیں';

  @override
  String get reportSent => 'بتانے کا شکریہ۔ ہماری ٹیم اس کا جائزہ لے گی۔';

  @override
  String get blockedAccounts => 'بلاک کیے گئے اکاؤنٹس';

  @override
  String get noBlocked => 'آپ نے کسی کو بلاک نہیں کیا۔';

  @override
  String get unblock => 'ان بلاک کریں';

  @override
  String userUnblocked(String name) {
    return '$name کو ان بلاک کر دیا گیا';
  }

  @override
  String get deleteAccount => 'اکاؤنٹ حذف کریں';

  @override
  String get deleteAccountTitle => 'اپنا اکاؤنٹ حذف کریں؟';

  @override
  String get deleteAccountBody =>
      'اس سے آپ کی پروفائل، پوسٹس، تبصرے، اسٹوریز اور اپ لوڈ کی گئی تصاویر اور ویڈیوز مستقل طور پر ہٹ جائیں گی اور آپ ہر آلے سے سائن آؤٹ ہو جائیں گے۔ یہ عمل واپس نہیں ہو سکتا۔';

  @override
  String deleteTypeToConfirm(String word) {
    return 'تصدیق کے لیے $word لکھیں';
  }

  @override
  String get deleteForever => 'ہمیشہ کے لیے حذف کریں';

  @override
  String get accountDeleted => 'آپ کا اکاؤنٹ حذف ہو گیا ہے۔';

  @override
  String get reportPost => 'پوسٹ کی رپورٹ کریں';

  @override
  String get reportComment => 'تبصرے کی رپورٹ کریں';

  @override
  String get reportPostPrompt => 'آپ اس پوسٹ کی رپورٹ کیوں کر رہے ہیں؟';

  @override
  String get reportCommentPrompt => 'آپ اس تبصرے کی رپورٹ کیوں کر رہے ہیں؟';

  @override
  String get groups => 'گروپس';

  @override
  String get pages => 'پیجز';

  @override
  String get yourGroups => 'آپ کے گروپس';

  @override
  String get yourPages => 'جن پیجز کو آپ فالو کرتے ہیں';

  @override
  String get discover => 'دریافت کریں';

  @override
  String get searchGroups => 'گروپس تلاش کریں';

  @override
  String get searchPages => 'پیجز تلاش کریں';

  @override
  String get noYourGroups => 'آپ ابھی کسی گروپ میں شامل نہیں ہوئے۔';

  @override
  String get noYourPages => 'آپ ابھی کسی پیج کو فالو نہیں کرتے۔';

  @override
  String get noGroupsFound => 'کوئی گروپ نہیں ملا';

  @override
  String get noPagesFound => 'کوئی پیج نہیں ملا';

  @override
  String get createGroup => 'گروپ بنائیں';

  @override
  String get createPage => 'پیج بنائیں';

  @override
  String get groupName => 'گروپ کا نام';

  @override
  String get pageName => 'پیج کا نام';

  @override
  String get descriptionOptional => 'تفصیل (اختیاری)';

  @override
  String get nameTooShort => 'کم از کم 2 حروف استعمال کریں';

  @override
  String get groupPublic => 'عوامی';

  @override
  String get groupPrivate => 'نجی';

  @override
  String get groupPublicHint => 'کوئی بھی پوسٹس دیکھ اور شامل ہو سکتا ہے۔';

  @override
  String get groupPrivateHint =>
      'صرف اراکین پوسٹس دیکھتے ہیں۔ ایڈمنز نئے اراکین کو منظور کرتے ہیں۔';

  @override
  String get pageTypeLabel => 'پیج کی قسم';

  @override
  String pageType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'business': 'کاروبار',
      'community': 'کمیونٹی',
      'creator': 'کریئیٹر',
      'other': '$type',
    });
    return '$_temp0';
  }

  @override
  String get create => 'بنائیں';

  @override
  String get requested => 'درخواست بھیجی گئی';

  @override
  String get leave => 'چھوڑ دیں';

  @override
  String get unfollow => 'ان فالو کریں';

  @override
  String get requestSent => 'درخواست بھیج دی گئی۔ ایک ایڈمن اس کا جائزہ لے گا۔';

  @override
  String memberCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString اراکین',
      one: '1 رکن',
    );
    return '$_temp0';
  }

  @override
  String get members => 'اراکین';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'owner': 'مالک',
      'admin': 'ایڈمن',
      'moderator': 'موڈریٹر',
      'other': 'رکن',
    });
    return '$_temp0';
  }

  @override
  String get wantsToJoin => 'شامل ہونا چاہتے ہیں';

  @override
  String get approve => 'منظور کریں';

  @override
  String get declineRequest => 'مسترد کریں';

  @override
  String get privateGroupTitle => 'یہ گروپ نجی ہے';

  @override
  String get privateGroupMessage =>
      'اس کی پوسٹس اور اراکین دیکھنے کے لیے شامل ہوں۔';

  @override
  String get noCommunityPosts => 'ابھی کوئی پوسٹ نہیں';
}

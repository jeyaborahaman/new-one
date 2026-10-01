// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navReels => 'ريلز';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navChats => 'المحادثات';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String storyRingSemantic(String state, String name) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'seen': 'قصة $name، تمت مشاهدتها',
      'other': 'قصة $name، جديدة',
    });
    return '$_temp0';
  }

  @override
  String get errorNetwork => 'تعذّر الوصول إلى الخادم. تحقّق من اتصالك.';

  @override
  String errorGeneric(String code) {
    return 'حدث خطأ ما ($code)';
  }

  @override
  String get uploadFailedNetwork => 'فشل الرفع. تحقّق من اتصالك.';

  @override
  String uploadFailedCode(String code) {
    return 'فشل الرفع ($code).';
  }

  @override
  String get timeNow => 'الآن';

  @override
  String timeMinutes(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString د';
  }

  @override
  String timeHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString س';
  }

  @override
  String timeDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString ي';
  }

  @override
  String get verified => 'موثّق';

  @override
  String reactionName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'like': 'إعجاب',
      'love': 'حب',
      'wow': 'واو',
      'laugh': 'ضحك',
      'sad': 'حزن',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String get authWelcomeBack => 'مرحبًا بعودتك';

  @override
  String get authSignInSubtitle => 'سجّل الدخول لترى ما يفعله أصدقاؤك.';

  @override
  String get authTwoStepTitle => 'التحقق بخطوتين';

  @override
  String get authTwoStepSubtitle =>
      'أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة، أو رمزًا احتياطيًا.';

  @override
  String get fieldEmailOrUsername => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get fieldCode => 'الرمز';

  @override
  String get verify => 'تحقّق';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get continueWithPhone => 'المتابعة باستخدام الهاتف';

  @override
  String get newHere => 'جديد هنا؟';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get errorEnterCredentials =>
      'أدخل بريدك الإلكتروني أو اسم المستخدم وكلمة المرور';

  @override
  String get registerTitle => 'أنشئ حسابك';

  @override
  String get registerSubtitle => 'انضم إلى المجتمع. لن يستغرق الأمر سوى دقيقة.';

  @override
  String get fieldDisplayNameOptional => 'الاسم المعروض (اختياري)';

  @override
  String get fieldUsername => 'اسم المستخدم';

  @override
  String get usernameHelper => 'من 3 إلى 30 حرفًا لاتينيًا أو رقمًا أو _';

  @override
  String get usernameInvalid =>
      'استخدم من 3 إلى 30 حرفًا لاتينيًا أو رقمًا أو _';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get emailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get passwordHelper => '8 أحرف على الأقل';

  @override
  String get passwordTooShort => '8 أحرف على الأقل';

  @override
  String get fieldReferralOptional => 'رمز الإحالة (اختياري)';

  @override
  String get phoneTitleEnterCode => 'أدخل الرمز';

  @override
  String get phoneTitle => 'رقم هاتفك';

  @override
  String phoneCodeSent(String phone) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $phone.';
  }

  @override
  String phoneFormatHint(String example) {
    return 'استخدم الصيغة الدولية، مثل $example.';
  }

  @override
  String get fieldPhone => 'رقم الهاتف';

  @override
  String get field2faCode => 'رمز التحقق بخطوتين';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get resetTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get resetSentSubtitle =>
      'إذا كان هذا البريد مرتبطًا بحساب، فالرمز في طريقه إليك.';

  @override
  String get resetSubtitle =>
      'سنرسل إليك رمزًا من 6 أرقام عبر البريد الإلكتروني.';

  @override
  String get fieldNewPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordUpdated =>
      'تم تحديث كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get search => 'بحث';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get feedEmptyTitle => 'موجز أخبارك هادئ';

  @override
  String get feedEmptyMessage => 'تابع أشخاصًا أو أنشئ أول منشور لك.';

  @override
  String get yourStory => 'قصتك';

  @override
  String get addToYourStory => 'أضف إلى قصتك';

  @override
  String userStorySemantic(String name) {
    return 'قصة $name';
  }

  @override
  String levelShort(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'مستوى $levelString';
  }

  @override
  String get imageUnavailable => 'الصورة غير متاحة';

  @override
  String commentsSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'التعليقات، $countString';
  }

  @override
  String reactSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تفاعل، $countString تفاعلات';
  }

  @override
  String yourReactionSemantic(String reaction, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تفاعلك: $reaction، $countString تفاعلات. انقر للإزالة';
  }

  @override
  String get reactHint => 'اضغط مطوّلًا لمزيد من التفاعلات';

  @override
  String pollVotes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString صوت',
      many: '$countString صوتًا',
      few: '$countString أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$_temp0';
  }

  @override
  String get commentsTitle => 'التعليقات';

  @override
  String get reply => 'رد';

  @override
  String get viewReplies => 'عرض الردود';

  @override
  String get noComments => 'لا توجد تعليقات بعد. ابدأ المحادثة.';

  @override
  String replyingTo(String name) {
    return 'الرد على $name';
  }

  @override
  String get cancelReply => 'إلغاء الرد';

  @override
  String get addComment => 'أضف تعليقًا';

  @override
  String get sendComment => 'إرسال التعليق';

  @override
  String get someone => 'شخص ما';

  @override
  String couldNotOpenGallery(String error) {
    return 'تعذّر فتح المعرض: $error';
  }

  @override
  String get composerEmpty => 'اكتب شيئًا أو أضف صورة أو فيديو';

  @override
  String get pollNeedsTwo => 'يحتاج الاستطلاع إلى خيارين على الأقل';

  @override
  String get posted => 'تم النشر';

  @override
  String get scheduled => 'تمت الجدولة';

  @override
  String get pickFutureTime => 'اختر وقتًا في المستقبل';

  @override
  String get newPost => 'منشور جديد';

  @override
  String get close => 'إغلاق';

  @override
  String get post => 'نشر';

  @override
  String get schedule => 'جدولة';

  @override
  String get composerHint => 'بماذا تفكر؟ استخدم #الوسوم و@الإشارات';

  @override
  String get uploading => 'جارٍ الرفع';

  @override
  String get shortReel => 'ريل قصير';

  @override
  String get regularVideo => 'فيديو عادي';

  @override
  String pollOption(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'الخيار $nString';
  }

  @override
  String get addOption => 'إضافة خيار';

  @override
  String get photo => 'صورة';

  @override
  String get video => 'فيديو';

  @override
  String get poll => 'استطلاع';

  @override
  String scheduledAt(String date) {
    return 'في $date';
  }

  @override
  String get clearSchedule => 'إلغاء الجدولة';

  @override
  String get whoCanSee => 'من يمكنه رؤية هذا';

  @override
  String get visibilityPublic => 'عام';

  @override
  String get visibilityFollowers => 'المتابِعون';

  @override
  String get visibilityPrivate => 'أنا فقط';

  @override
  String get selectedPhoto => 'الصورة المحددة';

  @override
  String fileSize(String name, String size) {
    return '$name · $size م.ب';
  }

  @override
  String get removeAttachment => 'إزالة المرفق';

  @override
  String couldNotOpen(String error) {
    return 'تعذّر فتح ذلك: $error';
  }

  @override
  String get storyShared => 'تمت مشاركة القصة لمدة 24 ساعة';

  @override
  String get newStory => 'قصة جديدة';

  @override
  String get share => 'مشاركة';

  @override
  String get shareMoment => 'شارك لحظة';

  @override
  String get storiesDisappear => 'تختفي القصص بعد 24 ساعة.';

  @override
  String get storyPreview => 'معاينة القصة';

  @override
  String get addCaption => 'أضف تعليقًا توضيحيًا';

  @override
  String get chooseDifferentFile => 'اختر ملفًا آخر';

  @override
  String reactionSent(String emoji) {
    return 'تم إرسال $emoji';
  }

  @override
  String get storyUnavailable => 'القصة غير متاحة';

  @override
  String storyViews(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مشاهدة',
      many: '$countString مشاهدة',
      few: '$countString مشاهدات',
      two: 'مشاهدتان',
      one: 'مشاهدة واحدة',
      zero: 'لا مشاهدات',
    );
    return '$_temp0';
  }

  @override
  String reactWith(String reaction) {
    return 'تفاعل بـ$reaction';
  }

  @override
  String get videoUnavailable => 'الفيديو غير متاح';

  @override
  String playVideo(String title) {
    return 'تشغيل الفيديو $title';
  }

  @override
  String get forYou => 'لك';

  @override
  String get trending => 'الرائج';

  @override
  String get noReels => 'لا توجد ريلز بعد';

  @override
  String get noReelsMessage => 'ستظهر مقاطع الفيديو القصيرة هنا.';

  @override
  String get loved => 'أعجبني';

  @override
  String get chats => 'المحادثات';

  @override
  String get chat => 'محادثة';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String get noConversations => 'لا توجد محادثات بعد';

  @override
  String get noConversationsMessage => 'ابحث عن صديق وقل مرحبًا.';

  @override
  String get startChat => 'ابدأ محادثة';

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get sayHello => 'قل مرحبًا';

  @override
  String unreadCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString غير مقروءة';
  }

  @override
  String get typing => 'يكتب…';

  @override
  String get sending => 'جارٍ الإرسال…';

  @override
  String get messageHint => 'رسالة';

  @override
  String get send => 'إرسال';

  @override
  String messageNotSent(String error) {
    return 'لم تُرسَل الرسالة: $error';
  }

  @override
  String sentMedia(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'image': 'أرسل صورة',
      'video': 'أرسل فيديو',
      'voice': 'أرسل رسالة صوتية',
      'file': 'أرسل ملفًا',
      'sticker': 'أرسل ملصقًا',
      'other': 'أرسل $type',
    });
    return '$_temp0';
  }

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get walletAndRewards => 'المحفظة والمكافآت';

  @override
  String get leaderboard => 'لوحة المتصدرين';

  @override
  String get inviteFriends => 'ادعُ أصدقاءك';

  @override
  String yourCode(String code) {
    return 'رمزك: $code';
  }

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String get themeAuto => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get displayName => 'الاسم المعروض';

  @override
  String get bio => 'النبذة';

  @override
  String get save => 'حفظ';

  @override
  String get luckyDraw => 'السحب على الجوائز';

  @override
  String get statFollowers => 'المتابِعون';

  @override
  String get statFollowing => 'يتابع';

  @override
  String get followingButton => 'تتابعه';

  @override
  String get follow => 'متابعة';

  @override
  String get message => 'مراسلة';

  @override
  String levelXp(int level, int xp) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return 'المستوى $levelString · $xpString نقطة خبرة';
  }

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get findSomeone => 'ابحث عن شخص لمراسلته';

  @override
  String get searchHint => 'ابحث عن أشخاص ومنشورات و#وسوم';

  @override
  String get peopleYouMayKnow => 'أشخاص قد تعرفهم';

  @override
  String mutualCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString مشترك';
  }

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String nothingFound(String query) {
    return 'لم يُعثر على شيء لـ\"$query\".';
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
      other: '$countString متابع',
      many: '$countString متابعًا',
      few: '$countString متابعين',
      two: 'متابعان',
      one: 'متابع واحد',
      zero: 'لا متابعين',
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
      other: '$countString منشور',
      many: '$countString منشورًا',
      few: '$countString منشورات',
      two: 'منشوران',
      one: 'منشور واحد',
      zero: 'لا منشورات',
    );
    return '$_temp0';
  }

  @override
  String get postsHeader => 'المنشورات';

  @override
  String streakReward(int streak, int coins) {
    final intl.NumberFormat streakNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String streakString = streakNumberFormat.format(streak);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'سلسلة اليوم $streakString: +$coinsString عملة';
  }

  @override
  String get rewardClaimed => 'تم استلام المكافأة';

  @override
  String get coins => 'العملات';

  @override
  String get claimDaily => 'استلم المكافأة اليومية';

  @override
  String get badges => 'الشارات';

  @override
  String get noBadges =>
      'لا توجد شارات بعد. انشر وعلّق وادعُ أصدقاءك لتحصل عليها.';

  @override
  String get challenges => 'التحديات';

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

    return '$progressString/$targetString · +$coinsString عملة';
  }

  @override
  String get join => 'انضمام';

  @override
  String get claim => 'استلام';

  @override
  String get history => 'السجل';

  @override
  String get noTransactions => 'لا توجد معاملات بعد.';

  @override
  String txReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'daily': 'مكافأة يومية',
      'referral': 'إحالة',
      'luckydraw': 'السحب على الجوائز',
      'challenge': 'تحدٍّ',
      'other': '$reason',
    });
    return '$_temp0';
  }

  @override
  String badgeName(String code, String name) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'first_post': 'أول منشور',
      'chatterbox': 'كثير الكلام',
      'popular': 'مشهور',
      'level_5': 'المستوى 5',
      'streak_7': 'سلسلة أسبوع',
      'connector': 'الموصِّل',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get allTime => 'كل الأوقات';

  @override
  String get noActivity => 'لا يوجد نشاط بعد';

  @override
  String levelN(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'المستوى $levelString';
  }

  @override
  String xpCount(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return '$xpString نقطة';
  }

  @override
  String get allCaughtUp => 'لا جديد لديك';

  @override
  String get newActivity => 'سيظهر النشاط الجديد هنا.';

  @override
  String get notAvailable => 'غير متاح';

  @override
  String get luckyRegion => 'السحب على الجوائز غير متاح في منطقتك حاليًا.';

  @override
  String get noCampaigns => 'لا توجد حملات حاليًا';

  @override
  String campaignStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'open': 'مفتوح',
      'closed': 'مغلق',
      'published': 'أُعلنت النتائج',
      'cancelled': 'ملغى',
      'draft': 'مسودة',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String get freeEntry => 'دخول مجاني';

  @override
  String coinsPerEntry(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString عملة لكل مشاركة';
  }

  @override
  String entryTerms(String price, int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$price · حتى $maxString مشاركات';
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

    return 'تم الاشتراك! لديك $entriesString من أصل $maxString مشاركات';
  }

  @override
  String get getEntry => 'احصل على مشاركة';

  @override
  String get callAudio => 'مكالمة صوتية';

  @override
  String get callVideo => 'مكالمة فيديو';

  @override
  String get callIncomingAudio => 'مكالمة صوتية واردة';

  @override
  String get callIncomingVideo => 'مكالمة فيديو واردة';

  @override
  String get callCalling => 'جارٍ الاتصال…';

  @override
  String get callConnecting => 'جارٍ التوصيل…';

  @override
  String get callReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String callEndReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'declined': 'تم رفض المكالمة',
      'busy': 'مشغول',
      'noAnswer': 'لا يوجد رد',
      'missed': 'مكالمة فائتة',
      'answeredElsewhere': 'تم الرد من جهاز آخر',
      'failed': 'فشلت المكالمة',
      'permissionDenied':
          'اسمح بالوصول إلى الميكروفون والكاميرا لإجراء المكالمات',
      'notConfigured': 'المكالمات غير متاحة حاليًا',
      'other': 'انتهت المكالمة',
    });
    return '$_temp0';
  }

  @override
  String get acceptCall => 'قبول';

  @override
  String get declineCall => 'رفض';

  @override
  String get endCall => 'إنهاء المكالمة';

  @override
  String get mute => 'كتم الصوت';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get cameraOff => 'إيقاف الكاميرا';

  @override
  String get cameraOn => 'تشغيل الكاميرا';

  @override
  String get switchCamera => 'تبديل الكاميرا';

  @override
  String get cameraShort => 'الكاميرا';

  @override
  String get flipShort => 'قلب';

  @override
  String get speaker => 'مكبّر الصوت';

  @override
  String get minimize => 'تصغير';

  @override
  String get returnToCall => 'انقر للعودة إلى المكالمة';

  @override
  String get callsTitle => 'المكالمات';

  @override
  String get callHistory => 'سجل المكالمات';

  @override
  String get noCalls => 'لا توجد مكالمات بعد';

  @override
  String get noCallsMessage => 'ستظهر مكالماتك هنا.';

  @override
  String get callOutgoing => 'صادرة';

  @override
  String get callIncoming => 'واردة';

  @override
  String get callMissedLabel => 'فائتة';

  @override
  String get callDeclinedLabel => 'مرفوضة';

  @override
  String get callBack => 'معاودة الاتصال';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get callsUnavailable => 'المكالمات متاحة في تطبيق الهاتف.';

  @override
  String get callNotRinging => 'انتهت هذه المكالمة.';

  @override
  String get moreOptions => 'خيارات أخرى';

  @override
  String get reportUser => 'إبلاغ';

  @override
  String get blockUser => 'حظر';

  @override
  String get cancel => 'إلغاء';

  @override
  String blockConfirmTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get blockConfirmBody =>
      'لن يتمكن من رؤية ملفك الشخصي أو منشوراتك أو متابعتك أو مراسلتك أو الاتصال بك. ولن يتم إخطاره بأنك حظرته.';

  @override
  String userBlocked(String name) {
    return 'تم حظر $name';
  }

  @override
  String reportTitle(String name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String get reportReasonPrompt => 'لماذا تُبلّغ عن هذا الحساب؟';

  @override
  String reportReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'spam': 'رسائل مزعجة',
      'harassment': 'مضايقة أو تنمّر',
      'hate': 'خطاب كراهية',
      'sexual': 'محتوى جنسي',
      'violence': 'عنف أو تهديد',
      'self_harm': 'إيذاء النفس أو الانتحار',
      'other': 'سبب آخر',
    });
    return '$_temp0';
  }

  @override
  String get reportDetailsHint => 'أضف تفاصيل (اختياري)';

  @override
  String get submitReport => 'إرسال البلاغ';

  @override
  String get reportSent => 'شكرًا لإبلاغنا. سيراجع فريقنا البلاغ.';

  @override
  String get blockedAccounts => 'الحسابات المحظورة';

  @override
  String get noBlocked => 'لم تحظر أحدًا.';

  @override
  String get unblock => 'إلغاء الحظر';

  @override
  String userUnblocked(String name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountTitle => 'حذف حسابك؟';

  @override
  String get deleteAccountBody =>
      'سيؤدي هذا إلى إزالة ملفك الشخصي ومنشوراتك وتعليقاتك وقصصك وما رفعته من صور ومقاطع فيديو نهائيًا، وتسجيل خروجك من كل الأجهزة. لا يمكن التراجع عن ذلك.';

  @override
  String deleteTypeToConfirm(String word) {
    return 'اكتب $word للتأكيد';
  }

  @override
  String get deleteForever => 'حذف نهائي';

  @override
  String get accountDeleted => 'تم حذف حسابك.';

  @override
  String get reportPost => 'الإبلاغ عن المنشور';

  @override
  String get reportComment => 'الإبلاغ عن التعليق';

  @override
  String get reportPostPrompt => 'لماذا تُبلّغ عن هذا المنشور؟';

  @override
  String get reportCommentPrompt => 'لماذا تُبلّغ عن هذا التعليق؟';

  @override
  String get groups => 'المجموعات';

  @override
  String get pages => 'الصفحات';

  @override
  String get yourGroups => 'مجموعاتك';

  @override
  String get yourPages => 'الصفحات التي تتابعها';

  @override
  String get discover => 'اكتشف';

  @override
  String get searchGroups => 'ابحث في المجموعات';

  @override
  String get searchPages => 'ابحث في الصفحات';

  @override
  String get noYourGroups => 'لم تنضم إلى أي مجموعة بعد.';

  @override
  String get noYourPages => 'لا تتابع أي صفحة بعد.';

  @override
  String get noGroupsFound => 'لم يُعثر على مجموعات';

  @override
  String get noPagesFound => 'لم يُعثر على صفحات';

  @override
  String get createGroup => 'إنشاء مجموعة';

  @override
  String get createPage => 'إنشاء صفحة';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get pageName => 'اسم الصفحة';

  @override
  String get descriptionOptional => 'الوصف (اختياري)';

  @override
  String get nameTooShort => 'استخدم حرفين على الأقل';

  @override
  String get groupPublic => 'عامة';

  @override
  String get groupPrivate => 'خاصة';

  @override
  String get groupPublicHint => 'يمكن لأي شخص رؤية المنشورات والانضمام.';

  @override
  String get groupPrivateHint =>
      'يرى الأعضاء فقط المنشورات، ويوافق المشرفون على الأعضاء الجدد.';

  @override
  String get pageTypeLabel => 'نوع الصفحة';

  @override
  String pageType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'business': 'نشاط تجاري',
      'community': 'مجتمع',
      'creator': 'صانع محتوى',
      'other': '$type',
    });
    return '$_temp0';
  }

  @override
  String get create => 'إنشاء';

  @override
  String get requested => 'تم إرسال الطلب';

  @override
  String get leave => 'مغادرة';

  @override
  String get unfollow => 'إلغاء المتابعة';

  @override
  String get requestSent => 'تم إرسال الطلب. سيراجعه أحد المشرفين.';

  @override
  String memberCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString عضو',
      many: '$countString عضوًا',
      few: '$countString أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا أعضاء',
    );
    return '$_temp0';
  }

  @override
  String get members => 'الأعضاء';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'owner': 'المالك',
      'admin': 'مشرف',
      'moderator': 'مراقب',
      'other': 'عضو',
    });
    return '$_temp0';
  }

  @override
  String get wantsToJoin => 'يريد الانضمام';

  @override
  String get approve => 'موافقة';

  @override
  String get declineRequest => 'رفض';

  @override
  String get privateGroupTitle => 'هذه المجموعة خاصة';

  @override
  String get privateGroupMessage => 'انضم لرؤية منشوراتها وأعضائها.';

  @override
  String get noCommunityPosts => 'لا توجد منشورات بعد';
}

/**
 * Server-side translations (English, Arabic, Urdu; English is the fallback).
 * - API error messages follow the request's Accept-Language (the app sends its UI language).
 * - Notification texts follow the recipient's saved language (users.locale), since the push is shown by the OS.
 * English strings are the canonical texts used across the codebase, so untranslated messages simply stay English.
 */
const LANGS = ['en', 'ar', 'ur'];
const FALLBACK = 'en';
const norm = (l) => (LANGS.includes(l) ? l : FALLBACK);

/** Best supported language from an Accept-Language header ("ar-SA,ar;q=0.9,en;q=0.8" -> "ar"). */
function pickLanguage(header) {
  if (!header) return FALLBACK;
  const ranked = String(header).split(',').map((part, i) => {
    const [tag, ...params] = part.trim().split(';');
    const q = Number((params.find((p) => p.trim().startsWith('q=')) || 'q=1').trim().slice(2));
    return { lang: tag.trim().toLowerCase().split('-')[0], q: Number.isFinite(q) ? q : 0, i };
  }).filter((x) => x.q > 0).sort((a, b) => b.q - a.q || a.i - b.i);
  return ranked.find((x) => LANGS.includes(x.lang))?.lang || FALLBACK;
}

// ---- API error messages: English text -> translations ----
const ERRORS = {
  'Something went wrong': ['حدث خطأ ما', 'کچھ غلط ہو گیا'],
  'Route not found': ['المسار غير موجود', 'راستہ نہیں ملا'],
  'Malformed JSON': ['بيانات غير صالحة', 'غلط ڈیٹا'],
  'Validation failed': ['بعض الحقول غير صالحة', 'کچھ فیلڈز درست نہیں'],
  'Too many requests': ['طلبات كثيرة جدًا. حاول لاحقًا.', 'بہت زیادہ درخواستیں۔ بعد میں کوشش کریں۔'],
  'Authentication required': ['يجب تسجيل الدخول', 'سائن ان ضروری ہے'],
  'Invalid or expired token': ['انتهت الجلسة. سجّل الدخول مجددًا.', 'سیشن ختم ہو گیا۔ دوبارہ سائن ان کریں۔'],
  'Account unavailable': ['الحساب غير متاح', 'اکاؤنٹ دستیاب نہیں'],
  'Account suspended': ['الحساب موقوف', 'اکاؤنٹ معطل ہے'],
  'Account banned': ['الحساب محظور', 'اکاؤنٹ پر پابندی ہے'],
  'Account deleted': ['تم حذف الحساب', 'اکاؤنٹ حذف ہو چکا ہے'],
  'Account not found': ['الحساب غير موجود', 'اکاؤنٹ نہیں ملا'],
  'Forbidden': ['غير مسموح', 'اجازت نہیں'],
  'Not allowed': ['غير مسموح', 'اجازت نہیں'],
  'Insufficient role': ['ليست لديك صلاحية لذلك', 'آپ کو اس کی اجازت نہیں'],
  'Invalid credentials': ['بيانات الدخول غير صحيحة', 'غلط لاگ ان معلومات'],
  'Email or username already in use': ['البريد الإلكتروني أو اسم المستخدم مستخدم بالفعل', 'ای میل یا صارف نام پہلے سے استعمال میں ہے'],
  'Code expired or invalid': ['الرمز منتهي الصلاحية أو غير صالح', 'کوڈ کی میعاد ختم ہو گئی یا غلط ہے'],
  'Too many codes requested. Try again later.': ['طلبت رموزًا كثيرة. حاول لاحقًا.', 'بہت زیادہ کوڈ مانگے گئے۔ بعد میں کوشش کریں۔'],
  'Invalid code': ['الرمز غير صحيح', 'غلط کوڈ'],
  'Challenge expired': ['انتهت مهلة التحقق. سجّل الدخول مجددًا.', 'تصدیق کا وقت ختم ہو گیا۔ دوبارہ سائن ان کریں۔'],
  'Invalid challenge': ['طلب تحقق غير صالح', 'غلط تصدیقی درخواست'],
  'Invalid refresh token': ['انتهت الجلسة. سجّل الدخول مجددًا.', 'سیشن ختم ہو گیا۔ دوبارہ سائن ان کریں۔'],
  'Refresh token expired': ['انتهت الجلسة. سجّل الدخول مجددًا.', 'سیشن ختم ہو گیا۔ دوبارہ سائن ان کریں۔'],
  'Refresh token reuse detected': ['تم إنهاء الجلسة لأسباب أمنية. سجّل الدخول مجددًا.', 'حفاظتی وجوہات سے سیشن ختم کر دیا گیا۔ دوبارہ سائن ان کریں۔'],
  '2FA is already enabled': ['التحقق بخطوتين مفعّل بالفعل', 'دو مرحلہ تصدیق پہلے سے فعال ہے'],
  '2FA is not enabled': ['التحقق بخطوتين غير مفعّل', 'دو مرحلہ تصدیق فعال نہیں'],
  'Start 2FA setup first': ['ابدأ إعداد التحقق بخطوتين أولًا', 'پہلے دو مرحلہ تصدیق سیٹ اپ شروع کریں'],
  'Google login is not configured': ['تسجيل الدخول عبر Google غير متاح', 'Google لاگ ان دستیاب نہیں'],
  'Apple login is not configured': ['تسجيل الدخول عبر Apple غير متاح', 'Apple لاگ ان دستیاب نہیں'],
  'Invalid Google token': ['تعذّر التحقق من حساب Google', 'Google اکاؤنٹ کی تصدیق نہیں ہو سکی'],
  'Invalid Apple token': ['تعذّر التحقق من حساب Apple', 'Apple اکاؤنٹ کی تصدیق نہیں ہو سکی'],
  'User not found': ['المستخدم غير موجود', 'صارف نہیں ملا'],
  'Cannot follow yourself': ['لا يمكنك متابعة نفسك', 'آپ خود کو فالو نہیں کر سکتے'],
  'Cannot befriend yourself': ['لا يمكنك إرسال طلب صداقة لنفسك', 'آپ خود کو دوستی کی درخواست نہیں بھیج سکتے'],
  'Cannot block yourself': ['لا يمكنك حظر نفسك', 'آپ خود کو بلاک نہیں کر سکتے'],
  'Cannot message yourself': ['لا يمكنك مراسلة نفسك', 'آپ خود کو پیغام نہیں بھیج سکتے'],
  'Cannot subscribe to yourself': ['لا يمكنك الاشتراك في قناتك', 'آپ اپنے چینل کو سبسکرائب نہیں کر سکتے'],
  'You cannot interact with this user': ['لا يمكنك التفاعل مع هذا المستخدم', 'آپ اس صارف سے رابطہ نہیں کر سکتے'],
  'You cannot add a user you blocked or who blocked you': ['لا يمكنك إضافة مستخدم حظرته أو حظرك', 'آپ ایسے صارف کو شامل نہیں کر سکتے جسے آپ نے بلاک کیا ہو یا جس نے آپ کو بلاک کیا ہو'],
  'You cannot report yourself': ['لا يمكنك الإبلاغ عن نفسك', 'آپ اپنی رپورٹ نہیں کر سکتے'],
  'You already reported this': ['لقد أبلغت عن هذا بالفعل', 'آپ پہلے ہی اس کی رپورٹ کر چکے ہیں'],
  'No pending request': ['لا يوجد طلب معلّق', 'کوئی زیر التواء درخواست نہیں'],
  'Post not found': ['المنشور غير موجود', 'پوسٹ نہیں ملی'],
  'Comment not found': ['التعليق غير موجود', 'تبصرہ نہیں ملا'],
  'Parent comment not found on this post': ['التعليق الأصلي غير موجود', 'اصل تبصرہ نہیں ملا'],
  'This content violates the community guidelines': ['هذا المحتوى يخالف إرشادات المجتمع', 'یہ مواد کمیونٹی کے اصولوں کی خلاف ورزی کرتا ہے'],
  'Not a poll': ['هذا ليس استطلاعًا', 'یہ پول نہیں ہے'],
  'Poll is closed': ['تم إغلاق الاستطلاع', 'پول بند ہو چکا ہے'],
  'Unknown option': ['خيار غير معروف', 'نامعلوم آپشن'],
  'You already voted': ['لقد صوّتّ بالفعل', 'آپ پہلے ہی ووٹ دے چکے ہیں'],
  'poll posts need poll options': ['يحتاج الاستطلاع إلى خيارات', 'پول کے لیے آپشنز ضروری ہیں'],
  'Media not found': ['الملف غير موجود', 'فائل نہیں ملی'],
  'Media not found or not ready': ['الملف غير موجود أو لم يكتمل رفعه', 'فائل نہیں ملی یا ابھی اپ لوڈ مکمل نہیں ہوا'],
  'Media storage is not configured': ['رفع الملفات غير متاح حاليًا', 'فائل اپ لوڈ ابھی دستیاب نہیں'],
  'Upload not found. Upload the file first.': ['لم يُعثر على الملف المرفوع. ارفع الملف أولًا.', 'اپ لوڈ نہیں ملا۔ پہلے فائل اپ لوڈ کریں۔'],
  'Uploaded size does not match the declared size': ['حجم الملف المرفوع غير مطابق', 'اپ لوڈ کی گئی فائل کا سائز مطابقت نہیں رکھتا'],
  'Upload link expired or invalid': ['انتهت صلاحية رابط الرفع', 'اپ لوڈ لنک کی میعاد ختم ہو گئی'],
  'Story not found': ['القصة غير موجودة', 'اسٹوری نہیں ملی'],
  'Story not found or expired': ['القصة غير موجودة أو انتهت صلاحيتها', 'اسٹوری نہیں ملی یا اس کی میعاد ختم ہو گئی'],
  'Only the author can see viewers': ['يمكن للناشر فقط رؤية المشاهدين', 'صرف پوسٹ کرنے والا دیکھنے والوں کو دیکھ سکتا ہے'],
  'Video not found': ['الفيديو غير موجود', 'ویڈیو نہیں ملی'],
  'Channel not found': ['القناة غير موجودة', 'چینل نہیں ملا'],
  'Playlist not found': ['قائمة التشغيل غير موجودة', 'پلے لسٹ نہیں ملی'],
  'Unknown category': ['فئة غير معروفة', 'نامعلوم زمرہ'],
  'Community not found': ['المجتمع غير موجود', 'کمیونٹی نہیں ملی'],
  'Join the community to post': ['انضم إلى المجتمع لتتمكن من النشر', 'پوسٹ کرنے کے لیے کمیونٹی میں شامل ہوں'],
  'Only page staff can post': ['النشر متاح لمشرفي الصفحة فقط', 'صرف پیج کا عملہ پوسٹ کر سکتا ہے'],
  'You are banned from this community': ['أنت محظور من هذا المجتمع', 'آپ پر اس کمیونٹی میں پابندی ہے'],
  'Members only': ['للأعضاء فقط', 'صرف اراکین کے لیے'],
  'Owners must transfer ownership first': ['يجب نقل الملكية أولًا', 'پہلے ملکیت منتقل کریں'],
  'Not a member of this conversation': ['لست عضوًا في هذه المحادثة', 'آپ اس گفتگو کے رکن نہیں'],
  'Group not found': ['المجموعة غير موجودة', 'گروپ نہیں ملا'],
  'Group admins only': ['لمشرفي المجموعة فقط', 'صرف گروپ ایڈمنز کے لیے'],
  'Owner cannot leave; delete or transfer the group': ['لا يمكن للمالك المغادرة؛ احذف المجموعة أو انقل ملكيتها', 'مالک گروپ نہیں چھوڑ سکتا؛ گروپ حذف کریں یا ملکیت منتقل کریں'],
  'Unknown member id': ['عضو غير معروف', 'نامعلوم رکن'],
  'Member not found': ['العضو غير موجود', 'رکن نہیں ملا'],
  'A call is already in progress in this conversation': ['هناك مكالمة جارية بالفعل في هذه المحادثة', 'اس گفتگو میں پہلے سے کال جاری ہے'],
  'Call not found': ['المكالمة غير موجودة', 'کال نہیں ملی'],
  'Calling is not configured': ['المكالمات غير متاحة حاليًا', 'کالز ابھی دستیاب نہیں'],
  'Insufficient coins': ['رصيد العملات غير كافٍ', 'سکے کافی نہیں'],
  'Already claimed today': ['لقد استلمت مكافأة اليوم بالفعل', 'آج کا انعام پہلے ہی وصول ہو چکا ہے'],
  'Already claimed': ['تم الاستلام بالفعل', 'پہلے ہی وصول ہو چکا ہے'],
  'Unknown referral code': ['رمز الإحالة غير معروف', 'نامعلوم ریفرل کوڈ'],
  'You cannot refer yourself': ['لا يمكنك إحالة نفسك', 'آپ خود کو ریفر نہیں کر سکتے'],
  'Referral already applied': ['تم تطبيق الإحالة بالفعل', 'ریفرل پہلے ہی لاگو ہو چکا ہے'],
  'Challenge not found': ['التحدي غير موجود', 'چیلنج نہیں ملا'],
  'Join the challenge first': ['انضم إلى التحدي أولًا', 'پہلے چیلنج میں شامل ہوں'],
  'Challenge not complete': ['لم يكتمل التحدي بعد', 'چیلنج ابھی مکمل نہیں ہوا'],
  'Campaign not found': ['الحملة غير موجودة', 'مہم نہیں ملی'],
  'Campaign is not open': ['الحملة غير مفتوحة', 'مہم کھلی نہیں ہے'],
  'Entry limit reached': ['وصلت إلى الحد الأقصى للمشاركات', 'اندراجات کی حد پوری ہو گئی'],
  'Results not published': ['لم تُعلن النتائج بعد', 'نتائج ابھی جاری نہیں ہوئے'],
  'Translation is not configured': ['الترجمة غير متاحة حاليًا', 'ترجمہ ابھی دستیاب نہیں'],
  'Empty query': ['اكتب كلمة للبحث', 'تلاش کے لیے کچھ لکھیں'],
};
// Messages with a variable part.
const ERROR_PATTERNS = [
  [/^File too large \(max (\d+) MB\)$/, ['الملف كبير جدًا (الحد الأقصى $1 م.ب)', 'فائل بہت بڑی ہے (زیادہ سے زیادہ $1 MB)']],
  [/^Unsupported (image|video|audio|file) type$/, ['نوع الملف غير مدعوم', 'فائل کی یہ قسم معاون نہیں']],
];

function translateError(lang, message) {
  const i = LANGS.indexOf(norm(lang)) - 1;
  if (i < 0 || typeof message !== 'string') return message;
  if (ERRORS[message]) return ERRORS[message][i];
  for (const [re, t] of ERROR_PATTERNS) if (re.test(message)) return message.replace(re, t[i]);
  return message;
}

// ---- Notification texts ({param} placeholders; English = the original wording) ----
const REACTIONS = { like: ['like', 'إعجاب', 'پسند'], love: ['love', 'حب', 'محبت'], wow: ['wow', 'واو', 'واہ'], laugh: ['laugh', 'ضحك', 'ہنسی'], sad: ['sad', 'حزن', 'اداس'] };
const BADGES = {
  first_post: ['First Post', 'أول منشور', 'پہلی پوسٹ'], chatterbox: ['Chatterbox', 'كثير الكلام', 'باتونی'], popular: ['Popular', 'مشهور', 'مقبول'],
  level_5: ['Level 5', 'المستوى 5', 'لیول 5'], streak_7: ['Week Streak', 'سلسلة أسبوع', 'ہفتہ وار سلسلہ'], connector: ['Connector', 'الموصِّل', 'رابطہ کار'],
};
const NOTIFY = {
  friend_request: ['Sent you a friend request', 'أرسل إليك طلب صداقة', 'آپ کو دوستی کی درخواست بھیجی'],
  mention: ['Mentioned you in a post', 'أشار إليك في منشور', 'ایک پوسٹ میں آپ کا ذکر کیا'],
  reaction_title: ['New reaction', 'تفاعل جديد', 'نیا ردِعمل'],
  reaction_post: ['Someone reacted {reaction} to your post', 'تفاعل أحدهم بـ{reaction} مع منشورك', 'کسی نے آپ کی پوسٹ پر {reaction} سے ردِعمل دیا'],
  story_reaction_title: ['Story reaction', 'تفاعل مع قصتك', 'اسٹوری پر ردِعمل'],
  story_reaction: ['Someone reacted {reaction}', 'تفاعل أحدهم بـ{reaction}', 'کسی نے {reaction} سے ردِعمل دیا'],
  story_new: ['Posted a new story', 'نشر قصة جديدة', 'نئی اسٹوری پوسٹ کی'],
  reel_new: ['New reel: {title}', 'ريل جديد: {title}', 'نئی ریل: {title}'],
  video_new: ['New video: {title}', 'فيديو جديد: {title}', 'نئی ویڈیو: {title}'],
  join_request: ['{name} wants to join', 'يريد {name} الانضمام', '{name} شامل ہونا چاہتے ہیں'],
  join_approved: ['Your join request was approved', 'تمت الموافقة على طلب انضمامك', 'آپ کی شمولیت کی درخواست منظور ہو گئی'],
  badge_title: ['Badge earned', 'حصلت على شارة', 'بیج حاصل ہوا'],
  referral_title: ['Referral bonus', 'مكافأة إحالة', 'ریفرل بونس'],
  referral_body: ['You earned {coins} coins', 'ربحت {coins} عملة', 'آپ نے {coins} سکے حاصل کیے'],
  new_message: ['New message', 'رسالة جديدة', 'نیا پیغام'],
  sent_image: ['Sent an image', 'أرسل صورة', 'تصویر بھیجی'],
  sent_video: ['Sent a video', 'أرسل فيديو', 'ویڈیو بھیجی'],
  sent_voice: ['Sent a voice message', 'أرسل رسالة صوتية', 'صوتی پیغام بھیجا'],
  sent_file: ['Sent a file', 'أرسل ملفًا', 'فائل بھیجی'],
  sent_sticker: ['Sent a sticker', 'أرسل ملصقًا', 'اسٹیکر بھیجا'],
  call_audio: ['Incoming audio call', 'مكالمة صوتية واردة', 'آنے والی آڈیو کال'],
  call_video: ['Incoming video call', 'مكالمة فيديو واردة', 'آنے والی ویڈیو کال'],
  missed_call_audio: ['Missed audio call', 'مكالمة صوتية فائتة', 'مِسڈ آڈیو کال'],
  missed_call_video: ['Missed video call', 'مكالمة فيديو فائتة', 'مِسڈ ویڈیو کال'],
};

/** Localized notification text for `key`, filling {params}. Unknown keys return null (caller keeps its text). */
function notificationText(lang, key, params = {}) {
  if (key === 'badge') return badgeName(lang, params.code, params.name);
  const row = NOTIFY[key]; if (!row) return null;
  const i = LANGS.indexOf(norm(lang));
  const p = { ...params };
  if (p.reaction && REACTIONS[p.reaction]) p.reaction = REACTIONS[p.reaction][i];
  return row[i].replace(/\{(\w+)\}/g, (m, k) => (p[k] === undefined ? m : String(p[k])));
}
const badgeName = (lang, code, fallback) => BADGES[code]?.[LANGS.indexOf(norm(lang))] ?? fallback;

module.exports = { LANGS, FALLBACK, pickLanguage, translateError, notificationText, badgeName };

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navReels => 'Reels';

  @override
  String get navCreate => 'Create';

  @override
  String get navChats => 'Chats';

  @override
  String get navProfile => 'Profile';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String storyRingSemantic(String state, String name) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'seen': '$name seen story',
      'other': '$name new story',
    });
    return '$_temp0';
  }

  @override
  String get errorNetwork => 'Cannot reach the server. Check your connection.';

  @override
  String errorGeneric(String code) {
    return 'Something went wrong ($code)';
  }

  @override
  String get uploadFailedNetwork => 'Upload failed. Check your connection.';

  @override
  String uploadFailedCode(String code) {
    return 'Upload failed ($code).';
  }

  @override
  String get timeNow => 'now';

  @override
  String timeMinutes(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '${nString}m';
  }

  @override
  String timeHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '${nString}h';
  }

  @override
  String timeDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '${nString}d';
  }

  @override
  String get verified => 'Verified';

  @override
  String reactionName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'like': 'like',
      'love': 'love',
      'wow': 'wow',
      'laugh': 'laugh',
      'sad': 'sad',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInSubtitle =>
      'Sign in to see what your friends are up to.';

  @override
  String get authTwoStepTitle => 'Two-step check';

  @override
  String get authTwoStepSubtitle =>
      'Enter the 6-digit code from your authenticator app, or a backup code.';

  @override
  String get fieldEmailOrUsername => 'Email or username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get fieldCode => 'Code';

  @override
  String get verify => 'Verify';

  @override
  String get signIn => 'Sign in';

  @override
  String get continueWithPhone => 'Continue with phone';

  @override
  String get newHere => 'New here?';

  @override
  String get createAccount => 'Create account';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get errorEnterCredentials =>
      'Enter your email or username and password';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'Join the community. It takes a minute.';

  @override
  String get fieldDisplayNameOptional => 'Display name (optional)';

  @override
  String get fieldUsername => 'Username';

  @override
  String get usernameHelper => '3-30 letters, numbers or _';

  @override
  String get usernameInvalid => 'Use 3-30 letters, numbers or _';

  @override
  String get fieldEmail => 'Email';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordHelper => 'At least 8 characters';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get fieldReferralOptional => 'Referral code (optional)';

  @override
  String get phoneTitleEnterCode => 'Enter the code';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String phoneCodeSent(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String phoneFormatHint(String example) {
    return 'Use international format, e.g. $example.';
  }

  @override
  String get fieldPhone => 'Phone number';

  @override
  String get field2faCode => '2FA code';

  @override
  String get sendCode => 'Send code';

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetSentSubtitle =>
      'If that email has an account, a code is on its way.';

  @override
  String get resetSubtitle => 'We will email you a 6-digit code.';

  @override
  String get fieldNewPassword => 'New password';

  @override
  String get passwordUpdated =>
      'Password updated. Sign in with your new password.';

  @override
  String get updatePassword => 'Update password';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get feedEmptyTitle => 'Your feed is quiet';

  @override
  String get feedEmptyMessage => 'Follow people or create your first post.';

  @override
  String get yourStory => 'Your story';

  @override
  String get addToYourStory => 'Add to your story';

  @override
  String userStorySemantic(String name) {
    return '$name story';
  }

  @override
  String levelShort(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Lv $levelString';
  }

  @override
  String get imageUnavailable => 'Image unavailable';

  @override
  String commentsSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Comments, $countString';
  }

  @override
  String reactSemantic(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'React, $countString reactions';
  }

  @override
  String yourReactionSemantic(String reaction, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Your reaction: $reaction, $countString reactions. Tap to remove';
  }

  @override
  String get reactHint => 'Long press for more reactions';

  @override
  String pollVotes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get reply => 'Reply';

  @override
  String get viewReplies => 'View replies';

  @override
  String get noComments => 'No comments yet. Start the conversation.';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get addComment => 'Add a comment';

  @override
  String get sendComment => 'Send comment';

  @override
  String get someone => 'Someone';

  @override
  String couldNotOpenGallery(String error) {
    return 'Could not open your gallery: $error';
  }

  @override
  String get composerEmpty => 'Write something or add a photo or video';

  @override
  String get pollNeedsTwo => 'A poll needs at least 2 options';

  @override
  String get posted => 'Posted';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get pickFutureTime => 'Pick a time in the future';

  @override
  String get newPost => 'New post';

  @override
  String get close => 'Close';

  @override
  String get post => 'Post';

  @override
  String get schedule => 'Schedule';

  @override
  String get composerHint =>
      'What\'s on your mind? Use #hashtags and @mentions';

  @override
  String get uploading => 'Uploading';

  @override
  String get shortReel => 'Short reel';

  @override
  String get regularVideo => 'Regular video';

  @override
  String pollOption(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Option $nString';
  }

  @override
  String get addOption => 'Add option';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get poll => 'Poll';

  @override
  String scheduledAt(String date) {
    return 'At $date';
  }

  @override
  String get clearSchedule => 'Clear schedule';

  @override
  String get whoCanSee => 'Who can see this';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilityFollowers => 'Followers';

  @override
  String get visibilityPrivate => 'Only me';

  @override
  String get selectedPhoto => 'Selected photo';

  @override
  String fileSize(String name, String size) {
    return '$name · $size MB';
  }

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String couldNotOpen(String error) {
    return 'Could not open that: $error';
  }

  @override
  String get storyShared => 'Story shared for 24 hours';

  @override
  String get newStory => 'New story';

  @override
  String get share => 'Share';

  @override
  String get shareMoment => 'Share a moment';

  @override
  String get storiesDisappear => 'Stories disappear after 24 hours.';

  @override
  String get storyPreview => 'Story preview';

  @override
  String get addCaption => 'Add a caption';

  @override
  String get chooseDifferentFile => 'Choose a different file';

  @override
  String reactionSent(String emoji) {
    return 'Sent $emoji';
  }

  @override
  String get storyUnavailable => 'Story unavailable';

  @override
  String storyViews(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString views',
      one: '1 view',
    );
    return '$_temp0';
  }

  @override
  String reactWith(String reaction) {
    return 'React $reaction';
  }

  @override
  String get videoUnavailable => 'Video unavailable';

  @override
  String playVideo(String title) {
    return 'Play video $title';
  }

  @override
  String get forYou => 'For you';

  @override
  String get trending => 'Trending';

  @override
  String get noReels => 'No reels yet';

  @override
  String get noReelsMessage => 'Short videos will show up here.';

  @override
  String get loved => 'Loved';

  @override
  String get chats => 'Chats';

  @override
  String get chat => 'Chat';

  @override
  String get newChat => 'New chat';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get noConversationsMessage => 'Find a friend and say hello.';

  @override
  String get startChat => 'Start a chat';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get sayHello => 'Say hello';

  @override
  String unreadCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString unread';
  }

  @override
  String get typing => 'typing…';

  @override
  String get sending => 'Sending…';

  @override
  String get messageHint => 'Message';

  @override
  String get send => 'Send';

  @override
  String messageNotSent(String error) {
    return 'Message not sent: $error';
  }

  @override
  String sentMedia(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'image': 'Sent a photo',
      'video': 'Sent a video',
      'voice': 'Sent a voice message',
      'file': 'Sent a file',
      'sticker': 'Sent a sticker',
      'other': 'Sent a $type',
    });
    return '$_temp0';
  }

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get walletAndRewards => 'Wallet and rewards';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get inviteFriends => 'Invite friends';

  @override
  String yourCode(String code) {
    return 'Your code: $code';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get signOut => 'Sign out';

  @override
  String get displayName => 'Display name';

  @override
  String get bio => 'Bio';

  @override
  String get save => 'Save';

  @override
  String get luckyDraw => 'Lucky Draw';

  @override
  String get statFollowers => 'Followers';

  @override
  String get statFollowing => 'Following';

  @override
  String get followingButton => 'Following';

  @override
  String get follow => 'Follow';

  @override
  String get message => 'Message';

  @override
  String levelXp(int level, int xp) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return 'Level $levelString · $xpString XP';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get findSomeone => 'Find someone to message';

  @override
  String get searchHint => 'Search people, posts, #tags';

  @override
  String get peopleYouMayKnow => 'People you may know';

  @override
  String mutualCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString mutual';
  }

  @override
  String get noResults => 'No results';

  @override
  String nothingFound(String query) {
    return 'Nothing found for \"$query\".';
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
      other: '$countString followers',
      one: '1 follower',
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
      other: '$countString posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get postsHeader => 'Posts';

  @override
  String streakReward(int streak, int coins) {
    final intl.NumberFormat streakNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String streakString = streakNumberFormat.format(streak);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Day $streakString streak: +$coinsString coins';
  }

  @override
  String get rewardClaimed => 'Reward claimed';

  @override
  String get coins => 'Coins';

  @override
  String get claimDaily => 'Claim daily reward';

  @override
  String get badges => 'Badges';

  @override
  String get noBadges =>
      'No badges yet. Post, comment and invite friends to earn them.';

  @override
  String get challenges => 'Challenges';

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

    return '$progressString/$targetString · +$coinsString coins';
  }

  @override
  String get join => 'Join';

  @override
  String get claim => 'Claim';

  @override
  String get history => 'History';

  @override
  String get noTransactions => 'No transactions yet.';

  @override
  String txReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'daily': 'Daily',
      'referral': 'Referral',
      'luckydraw': 'Luckydraw',
      'challenge': 'Challenge',
      'other': '$reason',
    });
    return '$_temp0';
  }

  @override
  String badgeName(String code, String name) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'first_post': 'First Post',
      'chatterbox': 'Chatterbox',
      'popular': 'Popular',
      'level_5': 'Level 5',
      'streak_7': 'Week Streak',
      'connector': 'Connector',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String get thisWeek => 'This week';

  @override
  String get allTime => 'All time';

  @override
  String get noActivity => 'No activity yet';

  @override
  String levelN(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Level $levelString';
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
  String get allCaughtUp => 'All caught up';

  @override
  String get newActivity => 'New activity will show up here.';

  @override
  String get notAvailable => 'Not available';

  @override
  String get luckyRegion =>
      'Lucky Draw is not available in your region right now.';

  @override
  String get noCampaigns => 'No campaigns right now';

  @override
  String campaignStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'open': 'Open',
      'closed': 'Closed',
      'published': 'Published',
      'cancelled': 'Cancelled',
      'draft': 'Draft',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String get freeEntry => 'Free entry';

  @override
  String coinsPerEntry(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString coins per entry';
  }

  @override
  String entryTerms(String price, int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$price · up to $maxString entries';
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

    return 'Entered! You have $entriesString of $maxString entries';
  }

  @override
  String get getEntry => 'Get an entry';

  @override
  String get callAudio => 'Audio call';

  @override
  String get callVideo => 'Video call';

  @override
  String get callIncomingAudio => 'Incoming audio call';

  @override
  String get callIncomingVideo => 'Incoming video call';

  @override
  String get callCalling => 'Calling…';

  @override
  String get callConnecting => 'Connecting…';

  @override
  String get callReconnecting => 'Reconnecting…';

  @override
  String callEndReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'declined': 'Call declined',
      'busy': 'Busy',
      'noAnswer': 'No answer',
      'missed': 'Missed call',
      'answeredElsewhere': 'Answered on another device',
      'failed': 'Call failed',
      'permissionDenied': 'Allow microphone and camera access to make calls',
      'notConfigured': 'Calling isn\'t available right now',
      'other': 'Call ended',
    });
    return '$_temp0';
  }

  @override
  String get acceptCall => 'Accept';

  @override
  String get declineCall => 'Decline';

  @override
  String get endCall => 'End call';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get cameraOff => 'Turn camera off';

  @override
  String get cameraOn => 'Turn camera on';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get cameraShort => 'Camera';

  @override
  String get flipShort => 'Flip';

  @override
  String get speaker => 'Speaker';

  @override
  String get minimize => 'Minimize';

  @override
  String get returnToCall => 'Tap to return to the call';

  @override
  String get callsTitle => 'Calls';

  @override
  String get callHistory => 'Call history';

  @override
  String get noCalls => 'No calls yet';

  @override
  String get noCallsMessage => 'Your calls will show up here.';

  @override
  String get callOutgoing => 'Outgoing';

  @override
  String get callIncoming => 'Incoming';

  @override
  String get callMissedLabel => 'Missed';

  @override
  String get callDeclinedLabel => 'Declined';

  @override
  String get callBack => 'Call back';

  @override
  String get openSettings => 'Open settings';

  @override
  String get callsUnavailable => 'Calls are available in the mobile app.';

  @override
  String get callNotRinging => 'This call has ended.';

  @override
  String get moreOptions => 'More options';

  @override
  String get reportUser => 'Report';

  @override
  String get blockUser => 'Block';

  @override
  String get cancel => 'Cancel';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'They won\'t be able to see your profile or posts, follow you, message you or call you. They won\'t be told that you blocked them.';

  @override
  String userBlocked(String name) {
    return '$name is blocked';
  }

  @override
  String reportTitle(String name) {
    return 'Report $name';
  }

  @override
  String get reportReasonPrompt => 'Why are you reporting this account?';

  @override
  String reportReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'spam': 'Spam',
      'harassment': 'Harassment or bullying',
      'hate': 'Hate speech',
      'sexual': 'Sexual content',
      'violence': 'Violence or threats',
      'self_harm': 'Self-harm or suicide',
      'other': 'Something else',
    });
    return '$_temp0';
  }

  @override
  String get reportDetailsHint => 'Add details (optional)';

  @override
  String get submitReport => 'Send report';

  @override
  String get reportSent => 'Thanks for telling us. Our team will review it.';

  @override
  String get blockedAccounts => 'Blocked accounts';

  @override
  String get noBlocked => 'You haven\'t blocked anyone.';

  @override
  String get unblock => 'Unblock';

  @override
  String userUnblocked(String name) {
    return '$name is unblocked';
  }

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This permanently removes your profile, posts, comments, stories and uploaded photos and videos, and signs you out on every device. It can\'t be undone.';

  @override
  String deleteTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get reportPost => 'Report post';

  @override
  String get reportComment => 'Report comment';

  @override
  String get reportPostPrompt => 'Why are you reporting this post?';

  @override
  String get reportCommentPrompt => 'Why are you reporting this comment?';

  @override
  String get groups => 'Groups';

  @override
  String get pages => 'Pages';

  @override
  String get yourGroups => 'Your groups';

  @override
  String get yourPages => 'Pages you follow';

  @override
  String get discover => 'Discover';

  @override
  String get searchGroups => 'Search groups';

  @override
  String get searchPages => 'Search pages';

  @override
  String get noYourGroups => 'You haven\'t joined any groups yet.';

  @override
  String get noYourPages => 'You don\'t follow any pages yet.';

  @override
  String get noGroupsFound => 'No groups found';

  @override
  String get noPagesFound => 'No pages found';

  @override
  String get createGroup => 'Create group';

  @override
  String get createPage => 'Create page';

  @override
  String get groupName => 'Group name';

  @override
  String get pageName => 'Page name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get nameTooShort => 'Use at least 2 characters';

  @override
  String get groupPublic => 'Public';

  @override
  String get groupPrivate => 'Private';

  @override
  String get groupPublicHint => 'Anyone can see posts and join.';

  @override
  String get groupPrivateHint =>
      'Only members see posts. Admins approve new members.';

  @override
  String get pageTypeLabel => 'Page type';

  @override
  String pageType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'business': 'Business',
      'community': 'Community',
      'creator': 'Creator',
      'other': '$type',
    });
    return '$_temp0';
  }

  @override
  String get create => 'Create';

  @override
  String get requested => 'Requested';

  @override
  String get leave => 'Leave';

  @override
  String get unfollow => 'Unfollow';

  @override
  String get requestSent => 'Request sent. An admin will review it.';

  @override
  String memberCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get members => 'Members';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'owner': 'Owner',
      'admin': 'Admin',
      'moderator': 'Moderator',
      'other': 'Member',
    });
    return '$_temp0';
  }

  @override
  String get wantsToJoin => 'Wants to join';

  @override
  String get approve => 'Approve';

  @override
  String get declineRequest => 'Decline';

  @override
  String get privateGroupTitle => 'This group is private';

  @override
  String get privateGroupMessage => 'Join to see its posts and members.';

  @override
  String get noCommunityPosts => 'No posts yet';
}

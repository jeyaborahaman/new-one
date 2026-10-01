import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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
    Locale('ar'),
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navReels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get navReels;

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @storyRingSemantic.
  ///
  /// In en, this message translates to:
  /// **'{state, select, seen{{name} seen story} other{{name} new story}}'**
  String storyRingSemantic(String state, String name);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({code})'**
  String errorGeneric(String code);

  /// No description provided for @uploadFailedNetwork.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check your connection.'**
  String get uploadFailedNetwork;

  /// No description provided for @uploadFailedCode.
  ///
  /// In en, this message translates to:
  /// **'Upload failed ({code}).'**
  String uploadFailedCode(String code);

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// Compact "minutes ago"
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String timeMinutes(int n);

  /// Compact "hours ago"
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String timeHours(int n);

  /// Compact "days ago"
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String timeDays(int n);

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @reactionName.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, like{like} love{love} wow{wow} laugh{laugh} sad{sad} other{{kind}}}'**
  String reactionName(String kind);

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see what your friends are up to.'**
  String get authSignInSubtitle;

  /// No description provided for @authTwoStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step check'**
  String get authTwoStepTitle;

  /// No description provided for @authTwoStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app, or a backup code.'**
  String get authTwoStepSubtitle;

  /// No description provided for @fieldEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get fieldEmailOrUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @fieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get fieldCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get continueWithPhone;

  /// No description provided for @newHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get newHere;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @errorEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or username and password'**
  String get errorEnterCredentials;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the community. It takes a minute.'**
  String get registerSubtitle;

  /// No description provided for @fieldDisplayNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get fieldDisplayNameOptional;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @usernameHelper.
  ///
  /// In en, this message translates to:
  /// **'3-30 letters, numbers or _'**
  String get usernameHelper;

  /// No description provided for @usernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 3-30 letters, numbers or _'**
  String get usernameInvalid;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelper;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @fieldReferralOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get fieldReferralOptional;

  /// No description provided for @phoneTitleEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get phoneTitleEnterCode;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneTitle;

  /// No description provided for @phoneCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String phoneCodeSent(String phone);

  /// No description provided for @phoneFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Use international format, e.g. {example}.'**
  String phoneFormatHint(String example);

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get fieldPhone;

  /// No description provided for @field2faCode.
  ///
  /// In en, this message translates to:
  /// **'2FA code'**
  String get field2faCode;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetTitle;

  /// No description provided for @resetSentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If that email has an account, a code is on its way.'**
  String get resetSentSubtitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will email you a 6-digit code.'**
  String get resetSubtitle;

  /// No description provided for @fieldNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get fieldNewPassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Sign in with your new password.'**
  String get passwordUpdated;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your feed is quiet'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Follow people or create your first post.'**
  String get feedEmptyMessage;

  /// No description provided for @yourStory.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get yourStory;

  /// No description provided for @addToYourStory.
  ///
  /// In en, this message translates to:
  /// **'Add to your story'**
  String get addToYourStory;

  /// No description provided for @userStorySemantic.
  ///
  /// In en, this message translates to:
  /// **'{name} story'**
  String userStorySemantic(String name);

  /// No description provided for @levelShort.
  ///
  /// In en, this message translates to:
  /// **'Lv {level}'**
  String levelShort(int level);

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get imageUnavailable;

  /// No description provided for @commentsSemantic.
  ///
  /// In en, this message translates to:
  /// **'Comments, {count}'**
  String commentsSemantic(int count);

  /// No description provided for @reactSemantic.
  ///
  /// In en, this message translates to:
  /// **'React, {count} reactions'**
  String reactSemantic(int count);

  /// No description provided for @yourReactionSemantic.
  ///
  /// In en, this message translates to:
  /// **'Your reaction: {reaction}, {count} reactions. Tap to remove'**
  String yourReactionSemantic(String reaction, int count);

  /// No description provided for @reactHint.
  ///
  /// In en, this message translates to:
  /// **'Long press for more reactions'**
  String get reactHint;

  /// No description provided for @pollVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vote} other{{count} votes}}'**
  String pollVotes(int count);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @viewReplies.
  ///
  /// In en, this message translates to:
  /// **'View replies'**
  String get viewReplies;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Start the conversation.'**
  String get noComments;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get addComment;

  /// No description provided for @sendComment.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get sendComment;

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @couldNotOpenGallery.
  ///
  /// In en, this message translates to:
  /// **'Could not open your gallery: {error}'**
  String couldNotOpenGallery(String error);

  /// No description provided for @composerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write something or add a photo or video'**
  String get composerEmpty;

  /// No description provided for @pollNeedsTwo.
  ///
  /// In en, this message translates to:
  /// **'A poll needs at least 2 options'**
  String get pollNeedsTwo;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @pickFutureTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time in the future'**
  String get pickFutureTime;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind? Use #hashtags and @mentions'**
  String get composerHint;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploading;

  /// No description provided for @shortReel.
  ///
  /// In en, this message translates to:
  /// **'Short reel'**
  String get shortReel;

  /// No description provided for @regularVideo.
  ///
  /// In en, this message translates to:
  /// **'Regular video'**
  String get regularVideo;

  /// No description provided for @pollOption.
  ///
  /// In en, this message translates to:
  /// **'Option {n}'**
  String pollOption(int n);

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @scheduledAt.
  ///
  /// In en, this message translates to:
  /// **'At {date}'**
  String scheduledAt(String date);

  /// No description provided for @clearSchedule.
  ///
  /// In en, this message translates to:
  /// **'Clear schedule'**
  String get clearSchedule;

  /// No description provided for @whoCanSee.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get whoCanSee;

  /// No description provided for @visibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get visibilityPublic;

  /// No description provided for @visibilityFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get visibilityFollowers;

  /// No description provided for @visibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get visibilityPrivate;

  /// No description provided for @selectedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Selected photo'**
  String get selectedPhoto;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'{name} · {size} MB'**
  String fileSize(String name, String size);

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get removeAttachment;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open that: {error}'**
  String couldNotOpen(String error);

  /// No description provided for @storyShared.
  ///
  /// In en, this message translates to:
  /// **'Story shared for 24 hours'**
  String get storyShared;

  /// No description provided for @newStory.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get newStory;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareMoment.
  ///
  /// In en, this message translates to:
  /// **'Share a moment'**
  String get shareMoment;

  /// No description provided for @storiesDisappear.
  ///
  /// In en, this message translates to:
  /// **'Stories disappear after 24 hours.'**
  String get storiesDisappear;

  /// No description provided for @storyPreview.
  ///
  /// In en, this message translates to:
  /// **'Story preview'**
  String get storyPreview;

  /// No description provided for @addCaption.
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get addCaption;

  /// No description provided for @chooseDifferentFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a different file'**
  String get chooseDifferentFile;

  /// No description provided for @reactionSent.
  ///
  /// In en, this message translates to:
  /// **'Sent {emoji}'**
  String reactionSent(String emoji);

  /// No description provided for @storyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Story unavailable'**
  String get storyUnavailable;

  /// No description provided for @storyViews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 view} other{{count} views}}'**
  String storyViews(int count);

  /// No description provided for @reactWith.
  ///
  /// In en, this message translates to:
  /// **'React {reaction}'**
  String reactWith(String reaction);

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get videoUnavailable;

  /// No description provided for @playVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video {title}'**
  String playVideo(String title);

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @noReels.
  ///
  /// In en, this message translates to:
  /// **'No reels yet'**
  String get noReels;

  /// No description provided for @noReelsMessage.
  ///
  /// In en, this message translates to:
  /// **'Short videos will show up here.'**
  String get noReelsMessage;

  /// No description provided for @loved.
  ///
  /// In en, this message translates to:
  /// **'Loved'**
  String get loved;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @noConversationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Find a friend and say hello.'**
  String get noConversationsMessage;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get startChat;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello'**
  String get sayHello;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'Message not sent: {error}'**
  String messageNotSent(String error);

  /// No description provided for @sentMedia.
  ///
  /// In en, this message translates to:
  /// **'{type, select, image{Sent a photo} video{Sent a video} voice{Sent a voice message} file{Sent a file} sticker{Sent a sticker} other{Sent a {type}}}'**
  String sentMedia(String type);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @walletAndRewards.
  ///
  /// In en, this message translates to:
  /// **'Wallet and rewards'**
  String get walletAndRewards;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @yourCode.
  ///
  /// In en, this message translates to:
  /// **'Your code: {code}'**
  String yourCode(String code);

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @luckyDraw.
  ///
  /// In en, this message translates to:
  /// **'Lucky Draw'**
  String get luckyDraw;

  /// No description provided for @statFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get statFollowers;

  /// No description provided for @statFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get statFollowing;

  /// No description provided for @followingButton.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingButton;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @levelXp.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {xp} XP'**
  String levelXp(int level, int xp);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @findSomeone.
  ///
  /// In en, this message translates to:
  /// **'Find someone to message'**
  String get findSomeone;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search people, posts, #tags'**
  String get searchHint;

  /// No description provided for @peopleYouMayKnow.
  ///
  /// In en, this message translates to:
  /// **'People you may know'**
  String get peopleYouMayKnow;

  /// No description provided for @mutualCount.
  ///
  /// In en, this message translates to:
  /// **'{count} mutual'**
  String mutualCount(int count);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for \"{query}\".'**
  String nothingFound(String query);

  /// No description provided for @followersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 follower} other{{count} followers}}'**
  String followersCount(int count);

  /// No description provided for @hashtagPosts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 post} other{{count} posts}}'**
  String hashtagPosts(int count);

  /// No description provided for @postsHeader.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get postsHeader;

  /// No description provided for @streakReward.
  ///
  /// In en, this message translates to:
  /// **'Day {streak} streak: +{coins} coins'**
  String streakReward(int streak, int coins);

  /// No description provided for @rewardClaimed.
  ///
  /// In en, this message translates to:
  /// **'Reward claimed'**
  String get rewardClaimed;

  /// No description provided for @coins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coins;

  /// No description provided for @claimDaily.
  ///
  /// In en, this message translates to:
  /// **'Claim daily reward'**
  String get claimDaily;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @noBadges.
  ///
  /// In en, this message translates to:
  /// **'No badges yet. Post, comment and invite friends to earn them.'**
  String get noBadges;

  /// No description provided for @challenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challenges;

  /// No description provided for @challengeProgress.
  ///
  /// In en, this message translates to:
  /// **'{progress}/{target} · +{coins} coins'**
  String challengeProgress(int progress, int target, int coins);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactions;

  /// No description provided for @txReason.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, daily{Daily} referral{Referral} luckydraw{Luckydraw} challenge{Challenge} other{{reason}}}'**
  String txReason(String reason);

  /// No description provided for @badgeName.
  ///
  /// In en, this message translates to:
  /// **'{code, select, first_post{First Post} chatterbox{Chatterbox} popular{Popular} level_5{Level 5} streak_7{Week Streak} connector{Connector} other{{name}}}'**
  String badgeName(String code, String name);

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @noActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivity;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelN(int level);

  /// No description provided for @xpCount.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String xpCount(int xp);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get allCaughtUp;

  /// No description provided for @newActivity.
  ///
  /// In en, this message translates to:
  /// **'New activity will show up here.'**
  String get newActivity;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @luckyRegion.
  ///
  /// In en, this message translates to:
  /// **'Lucky Draw is not available in your region right now.'**
  String get luckyRegion;

  /// No description provided for @noCampaigns.
  ///
  /// In en, this message translates to:
  /// **'No campaigns right now'**
  String get noCampaigns;

  /// No description provided for @campaignStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, open{Open} closed{Closed} published{Published} cancelled{Cancelled} draft{Draft} other{{status}}}'**
  String campaignStatus(String status);

  /// No description provided for @freeEntry.
  ///
  /// In en, this message translates to:
  /// **'Free entry'**
  String get freeEntry;

  /// No description provided for @coinsPerEntry.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins per entry'**
  String coinsPerEntry(int coins);

  /// No description provided for @entryTerms.
  ///
  /// In en, this message translates to:
  /// **'{price} · up to {max} entries'**
  String entryTerms(String price, int max);

  /// No description provided for @entered.
  ///
  /// In en, this message translates to:
  /// **'Entered! You have {entries} of {max} entries'**
  String entered(int entries, int max);

  /// No description provided for @getEntry.
  ///
  /// In en, this message translates to:
  /// **'Get an entry'**
  String get getEntry;

  /// No description provided for @callAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get callAudio;

  /// No description provided for @callVideo.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get callVideo;

  /// No description provided for @callIncomingAudio.
  ///
  /// In en, this message translates to:
  /// **'Incoming audio call'**
  String get callIncomingAudio;

  /// No description provided for @callIncomingVideo.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get callIncomingVideo;

  /// No description provided for @callCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get callCalling;

  /// No description provided for @callConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get callConnecting;

  /// No description provided for @callReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get callReconnecting;

  /// No description provided for @callEndReason.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, declined{Call declined} busy{Busy} noAnswer{No answer} missed{Missed call} answeredElsewhere{Answered on another device} failed{Call failed} permissionDenied{Allow microphone and camera access to make calls} notConfigured{Calling isn\'t available right now} other{Call ended}}'**
  String callEndReason(String reason);

  /// No description provided for @acceptCall.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptCall;

  /// No description provided for @declineCall.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineCall;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get endCall;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @cameraOff.
  ///
  /// In en, this message translates to:
  /// **'Turn camera off'**
  String get cameraOff;

  /// No description provided for @cameraOn.
  ///
  /// In en, this message translates to:
  /// **'Turn camera on'**
  String get cameraOn;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCamera;

  /// No description provided for @cameraShort.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraShort;

  /// No description provided for @flipShort.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flipShort;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @returnToCall.
  ///
  /// In en, this message translates to:
  /// **'Tap to return to the call'**
  String get returnToCall;

  /// No description provided for @callsTitle.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get callsTitle;

  /// No description provided for @callHistory.
  ///
  /// In en, this message translates to:
  /// **'Call history'**
  String get callHistory;

  /// No description provided for @noCalls.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get noCalls;

  /// No description provided for @noCallsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your calls will show up here.'**
  String get noCallsMessage;

  /// No description provided for @callOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get callOutgoing;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get callIncoming;

  /// No description provided for @callMissedLabel.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callMissedLabel;

  /// No description provided for @callDeclinedLabel.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get callDeclinedLabel;

  /// No description provided for @callBack.
  ///
  /// In en, this message translates to:
  /// **'Call back'**
  String get callBack;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @callsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Calls are available in the mobile app.'**
  String get callsUnavailable;

  /// No description provided for @callNotRinging.
  ///
  /// In en, this message translates to:
  /// **'This call has ended.'**
  String get callNotRinging;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportUser;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockUser;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to see your profile or posts, follow you, message you or call you. They won\'t be told that you blocked them.'**
  String get blockConfirmBody;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked'**
  String userBlocked(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String reportTitle(String name);

  /// No description provided for @reportReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this account?'**
  String get reportReasonPrompt;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, spam{Spam} harassment{Harassment or bullying} hate{Hate speech} sexual{Sexual content} violence{Violence or threats} self_harm{Self-harm or suicide} other{Something else}}'**
  String reportReason(String reason);

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get reportDetailsHint;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get submitReport;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling us. Our team will review it.'**
  String get reportSent;

  /// No description provided for @blockedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get blockedAccounts;

  /// No description provided for @noBlocked.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get noBlocked;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is unblocked'**
  String userUnblocked(String name);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your profile, posts, comments, stories and uploaded photos and videos, and signs you out on every device. It can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deleteTypeToConfirm(String word);

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @reportPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get reportPost;

  /// No description provided for @reportComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get reportComment;

  /// No description provided for @reportPostPrompt.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this post?'**
  String get reportPostPrompt;

  /// No description provided for @reportCommentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this comment?'**
  String get reportCommentPrompt;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pages;

  /// No description provided for @yourGroups.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get yourGroups;

  /// No description provided for @yourPages.
  ///
  /// In en, this message translates to:
  /// **'Pages you follow'**
  String get yourPages;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @searchGroups.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get searchGroups;

  /// No description provided for @searchPages.
  ///
  /// In en, this message translates to:
  /// **'Search pages'**
  String get searchPages;

  /// No description provided for @noYourGroups.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined any groups yet.'**
  String get noYourGroups;

  /// No description provided for @noYourPages.
  ///
  /// In en, this message translates to:
  /// **'You don\'t follow any pages yet.'**
  String get noYourPages;

  /// No description provided for @noGroupsFound.
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get noGroupsFound;

  /// No description provided for @noPagesFound.
  ///
  /// In en, this message translates to:
  /// **'No pages found'**
  String get noPagesFound;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @createPage.
  ///
  /// In en, this message translates to:
  /// **'Create page'**
  String get createPage;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @pageName.
  ///
  /// In en, this message translates to:
  /// **'Page name'**
  String get pageName;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 2 characters'**
  String get nameTooShort;

  /// No description provided for @groupPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get groupPublic;

  /// No description provided for @groupPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get groupPrivate;

  /// No description provided for @groupPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see posts and join.'**
  String get groupPublicHint;

  /// No description provided for @groupPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Only members see posts. Admins approve new members.'**
  String get groupPrivateHint;

  /// No description provided for @pageTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Page type'**
  String get pageTypeLabel;

  /// No description provided for @pageType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, business{Business} community{Community} creator{Creator} other{{type}}}'**
  String pageType(String type);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. An admin will review it.'**
  String get requestSent;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String memberCount(int count);

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @roleName.
  ///
  /// In en, this message translates to:
  /// **'{role, select, owner{Owner} admin{Admin} moderator{Moderator} other{Member}}'**
  String roleName(String role);

  /// No description provided for @wantsToJoin.
  ///
  /// In en, this message translates to:
  /// **'Wants to join'**
  String get wantsToJoin;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @declineRequest.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineRequest;

  /// No description provided for @privateGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'This group is private'**
  String get privateGroupTitle;

  /// No description provided for @privateGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Join to see its posts and members.'**
  String get privateGroupMessage;

  /// No description provided for @noCommunityPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noCommunityPosts;
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
      <String>['ar', 'en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

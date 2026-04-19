import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ja'),
    Locale('ko'),
    Locale('zh')
  ];

  /// Application name displayed in the app bar and title
  ///
  /// In en, this message translates to:
  /// **'AnyNote'**
  String get appTitle;

  /// Login screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to your encrypted vault'**
  String get signInToVault;

  /// Email form field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Validation error when email is empty
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Password form field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Validation error when password is empty
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Sign in button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Link to registration screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccountRegister;

  /// Link to account recovery screen
  ///
  /// In en, this message translates to:
  /// **'Recover from backup'**
  String get recoverFromBackup;

  /// Error when salt is missing during login
  ///
  /// In en, this message translates to:
  /// **'No encryption keys found. Please register first.'**
  String get noEncryptionKeys;

  /// Auth error on login
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get invalidEmailOrPassword;

  /// Auth error when account does not exist
  ///
  /// In en, this message translates to:
  /// **'Account not found. Please register first.'**
  String get accountNotFoundRegister;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Please check your connection.'**
  String get unableToReachServer;

  /// Registration screen heading and submit button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Registration screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Start your encrypted note journey'**
  String get startEncryptedJourney;

  /// Username form field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Validation error when username is empty
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// Confirm password form field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Validation error when passwords differ
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Validation error for short password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// Warning about password importance during registration
  ///
  /// In en, this message translates to:
  /// **'Your data will be encrypted with this password. We cannot recover it if lost.'**
  String get encryptionNotice;

  /// Link to login screen from registration
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccount;

  /// Registration conflict error
  ///
  /// In en, this message translates to:
  /// **'Email or username already taken.'**
  String get emailOrUsernameTaken;

  /// Generic validation error during registration
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Please check your details.'**
  String get invalidInput;

  /// Recovery key dialog title
  ///
  /// In en, this message translates to:
  /// **'Save Your Recovery Key'**
  String get saveRecoveryKey;

  /// Instructions shown with the recovery key
  ///
  /// In en, this message translates to:
  /// **'Store this recovery key in a safe place. You will need it to recover your data if you forget your password.'**
  String get recoveryKeyInstructions;

  /// Tooltip for copy recovery key button
  ///
  /// In en, this message translates to:
  /// **'Copy recovery key'**
  String get copyRecoveryKey;

  /// Snackbar confirmation after copying recovery key
  ///
  /// In en, this message translates to:
  /// **'Recovery key copied to clipboard'**
  String get recoveryKeyCopied;

  /// Button confirming the user saved their recovery key
  ///
  /// In en, this message translates to:
  /// **'I\'ve Saved It'**
  String get iSavedIt;

  /// Recovery screen heading and submit button
  ///
  /// In en, this message translates to:
  /// **'Recover Account'**
  String get recoverAccount;

  /// Recovery screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter your 12-word recovery key to restore your encrypted vault on this device.'**
  String get recoverAccountInstructions;

  /// Form field label for recovery key input
  ///
  /// In en, this message translates to:
  /// **'Recovery Key (12 words)'**
  String get recoveryKeyLabel;

  /// Tooltip for paste button
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// Validation error when recovery key is empty
  ///
  /// In en, this message translates to:
  /// **'Recovery key is required'**
  String get recoveryKeyRequired;

  /// Validation error for wrong word count
  ///
  /// In en, this message translates to:
  /// **'Recovery key must be exactly 12 words'**
  String get recoveryKeyWordCount;

  /// Helper text below the recovery key input
  ///
  /// In en, this message translates to:
  /// **'Enter all 12 words separated by spaces, in the correct order.'**
  String get recoveryKeyFormatHint;

  /// Error when recovery key is malformed
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery key. Please check your words and try again.'**
  String get invalidRecoveryKey;

  /// Error when recovery key does not match account
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery key for this account.'**
  String get invalidRecoveryKeyForAccount;

  /// Error when no account matches the email
  ///
  /// In en, this message translates to:
  /// **'Account not found. Please check your email.'**
  String get accountNotFoundCheckEmail;

  /// Link back to login from recovery screen
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// Button to skip onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Button to go to next onboarding page
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Button to finish onboarding and proceed
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Onboarding page 1 title
  ///
  /// In en, this message translates to:
  /// **'Your Notes, Your Privacy'**
  String get onboardingPrivacyTitle;

  /// Onboarding page 1 description
  ///
  /// In en, this message translates to:
  /// **'AnyNote encrypts every note on your device before it reaches the cloud. No one -- not even us -- can read your notes.'**
  String get onboardingPrivacyDesc;

  /// Onboarding page 2 title
  ///
  /// In en, this message translates to:
  /// **'Master Password'**
  String get onboardingMasterPasswordTitle;

  /// Onboarding page 2 description
  ///
  /// In en, this message translates to:
  /// **'Set a master password that derives your encryption key. Remember it -- there is no password reset without your recovery key.'**
  String get onboardingMasterPasswordDesc;

  /// Onboarding page 3 title
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get onboardingRecoveryKeyTitle;

  /// Onboarding page 3 description
  ///
  /// In en, this message translates to:
  /// **'You will receive a 12-word recovery key. Store it safely -- it is the only way to recover your notes if you forget your password.'**
  String get onboardingRecoveryKeyDesc;

  /// Onboarding page 4 title
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Composing'**
  String get onboardingAITitle;

  /// Onboarding page 4 description
  ///
  /// In en, this message translates to:
  /// **'Use AI to compose, outline, and adapt your notes for any platform. Your content is never logged.'**
  String get onboardingAIDesc;

  /// Search text field hint
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get searchNotes;

  /// Tooltip for collections button and screen title
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// Tooltip for sort menu
  ///
  /// In en, this message translates to:
  /// **'Sort notes'**
  String get sortNotes;

  /// Sort option: newest updated first
  ///
  /// In en, this message translates to:
  /// **'Updated (newest)'**
  String get updatedNewest;

  /// Sort option: oldest updated first
  ///
  /// In en, this message translates to:
  /// **'Updated (oldest)'**
  String get updatedOldest;

  /// Sort option: newest created first
  ///
  /// In en, this message translates to:
  /// **'Created (newest)'**
  String get createdNewest;

  /// Sort option: oldest created first
  ///
  /// In en, this message translates to:
  /// **'Created (oldest)'**
  String get createdOldest;

  /// Sort option: alphabetical by title
  ///
  /// In en, this message translates to:
  /// **'Title A-Z'**
  String get titleAZ;

  /// Tooltip for list view toggle
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// Tooltip for grid view toggle
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// Tooltip for advanced search button
  ///
  /// In en, this message translates to:
  /// **'Advanced search'**
  String get advancedSearch;

  /// Tooltip for closing search
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// Tooltip for opening search
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotesTooltip;

  /// Tooltip for FAB and accessibility label
  ///
  /// In en, this message translates to:
  /// **'Create new note'**
  String get createNewNote;

  /// Empty state title for notes list
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesYet;

  /// Empty state subtitle for notes list
  ///
  /// In en, this message translates to:
  /// **'Tap + to capture your first note'**
  String get tapToCapture;

  /// Action label for creating a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// Empty state title for search results
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// Empty state subtitle for search results
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearch;

  /// Confirmation dialog title for deleting a note
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteNoteQuestion;

  /// Confirmation dialog body for deleting a note
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteNoteConfirm(String title);

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Snackbar after deleting a note
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// Snackbar undo action label
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Context menu item to unpin a note
  ///
  /// In en, this message translates to:
  /// **'Unpin note'**
  String get unpinNote;

  /// Context menu item to pin a note
  ///
  /// In en, this message translates to:
  /// **'Pin note'**
  String get pinNote;

  /// Context menu item to delete a note
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// Create option for a blank note
  ///
  /// In en, this message translates to:
  /// **'Blank Note'**
  String get blankNote;

  /// Create option from a template
  ///
  /// In en, this message translates to:
  /// **'From Template'**
  String get fromTemplate;

  /// Relative time: less than 1 minute ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Relative time: minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// Relative time: hours ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// Relative time: days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// Placeholder title for notes without a title
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// Screen title and tooltip for version history
  ///
  /// In en, this message translates to:
  /// **'Version History'**
  String get versionHistory;

  /// Tooltip for edit note button
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// Tooltip for export/share menu
  ///
  /// In en, this message translates to:
  /// **'Export or share'**
  String get exportOrShare;

  /// Export menu item
  ///
  /// In en, this message translates to:
  /// **'Share via link'**
  String get shareViaLink;

  /// Export menu item
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get exportAsMarkdown;

  /// Export menu item
  ///
  /// In en, this message translates to:
  /// **'Export as HTML'**
  String get exportAsHTML;

  /// Export menu item
  ///
  /// In en, this message translates to:
  /// **'Export as Plain Text'**
  String get exportAsPlainText;

  /// Error title when note loading fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load note'**
  String get failedToLoadNote;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Message when note ID does not exist
  ///
  /// In en, this message translates to:
  /// **'Note not found'**
  String get noteNotFound;

  /// Label for unsynced note status
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get notSynced;

  /// Snackbar when note cannot be loaded for export
  ///
  /// In en, this message translates to:
  /// **'Could not load note for export'**
  String get couldNotLoadForExport;

  /// Delete note dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNoteDialog;

  /// Delete note dialog message
  ///
  /// In en, this message translates to:
  /// **'This note will be moved to trash. You can restore it later.'**
  String get deleteNoteDialogMessage;

  /// Note title text field hint
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Content text field hint in editor
  ///
  /// In en, this message translates to:
  /// **'Start writing...'**
  String get startWriting;

  /// Tooltip for save/close button
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get saveAndClose;

  /// Accessibility label for saving indicator
  ///
  /// In en, this message translates to:
  /// **'Saving note'**
  String get savingNote;

  /// Tooltip for plain text editor toggle
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get plainText;

  /// Tooltip for rich text editor toggle
  ///
  /// In en, this message translates to:
  /// **'Rich text'**
  String get richText;

  /// Edit mode toggle tooltip
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Preview mode toggle tooltip
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Tooltip for tag picker button
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get manageTags;

  /// Tooltip for add image button
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get addImage;

  /// Accessibility label for note content area
  ///
  /// In en, this message translates to:
  /// **'Note content'**
  String get noteContent;

  /// Tag picker sheet heading
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// Tooltip for closing tag picker
  ///
  /// In en, this message translates to:
  /// **'Close tag picker'**
  String get closeTagPicker;

  /// Hint text and accessibility label for new tag input
  ///
  /// In en, this message translates to:
  /// **'New tag name'**
  String get newTagName;

  /// Add button in tag picker
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Empty state in tag picker
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Create one above.'**
  String get noTagsYet;

  /// Error when image insertion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add image: {error}'**
  String failedToAddImage(String error);

  /// Restore version button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Dialog title for confirming version restore
  ///
  /// In en, this message translates to:
  /// **'Restore Version'**
  String get restoreVersion;

  /// Confirmation body for restoring a version
  ///
  /// In en, this message translates to:
  /// **'Replace the current note content with version {version}? A snapshot of the current content will be saved first.'**
  String restoreVersionConfirm(int version);

  /// Snackbar after restoring a version
  ///
  /// In en, this message translates to:
  /// **'Version restored'**
  String get versionRestored;

  /// Error snackbar when restore fails
  ///
  /// In en, this message translates to:
  /// **'Failed to restore: {error}'**
  String failedToRestore(String error);

  /// Error title when versions fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load versions'**
  String get failedToLoadVersions;

  /// Empty state title for version history
  ///
  /// In en, this message translates to:
  /// **'No versions yet'**
  String get noVersionsYet;

  /// Empty state subtitle for version history
  ///
  /// In en, this message translates to:
  /// **'Versions are saved automatically when you edit a note.'**
  String get versionsSavedAutomatically;

  /// Badge label for the current version
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// Settings screen title and nav tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Plan label in settings
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// Upgrade plan button
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// Loading placeholder text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error subtitle for account info
  ///
  /// In en, this message translates to:
  /// **'Unable to load account info'**
  String get unableToLoadAccountInfo;

  /// Settings section header for AI features
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiSection;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'LLM Configuration'**
  String get llmConfiguration;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure your AI providers'**
  String get configureAIProviders;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'AI Quota'**
  String get aiQuota;

  /// AI quota usage display
  ///
  /// In en, this message translates to:
  /// **'{used}/{limit} requests today'**
  String requestsToday(int used, int limit);

  /// Error subtitle for AI quota
  ///
  /// In en, this message translates to:
  /// **'Unable to load quota'**
  String get unableToLoadQuota;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Publishing'**
  String get publishing;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Platform Connections'**
  String get platformConnections;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage connected platforms'**
  String get manageConnectedPlatforms;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get securityPrivacy;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Encryption Settings'**
  String get encryptionSettings;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'E2E encryption active'**
  String get e2eEncryptionActive;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// Subtitle when never synced
  ///
  /// In en, this message translates to:
  /// **'Last synced: Never'**
  String get lastSyncedNever;

  /// Subtitle showing last sync time
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String lastSynced(String time);

  /// Loading state for sync status
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checking;

  /// Error subtitle for sync status
  ///
  /// In en, this message translates to:
  /// **'Unable to load sync status'**
  String get unableToLoadSyncStatus;

  /// Sync button label
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// Snackbar after sync with conflicts
  ///
  /// In en, this message translates to:
  /// **'Sync complete with {count} conflicts'**
  String syncCompleteWithConflicts(int count);

  /// Snackbar after successful sync
  ///
  /// In en, this message translates to:
  /// **'Synced: {pulled} pulled, {pushed} pushed'**
  String synced(int pulled, int pushed);

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Export All Notes'**
  String get exportAllNotes;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Export all notes to a file'**
  String get exportAllNotesDesc;

  /// Export format option
  ///
  /// In en, this message translates to:
  /// **'Markdown (.md)'**
  String get markdownFormat;

  /// Export format option
  ///
  /// In en, this message translates to:
  /// **'HTML (.html)'**
  String get htmlFormat;

  /// Export format option
  ///
  /// In en, this message translates to:
  /// **'Plain Text (.txt)'**
  String get plainTextFormat;

  /// Snackbar when no notes exist
  ///
  /// In en, this message translates to:
  /// **'No notes to export'**
  String get noNotesToExport;

  /// Snackbar when notes have no content
  ///
  /// In en, this message translates to:
  /// **'No notes with content to export'**
  String get noNotesWithContent;

  /// Snackbar on export failure
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Version label in settings
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// Sign out confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? You will need to log in again to access your notes.'**
  String get signOutConfirmMessage;

  /// Snackbar on sign out failure
  ///
  /// In en, this message translates to:
  /// **'Sign out failed: {error}'**
  String signOutFailed(String error);

  /// Encryption screen title
  ///
  /// In en, this message translates to:
  /// **'Security & Encryption'**
  String get securityEncryption;

  /// Status when encryption is set up
  ///
  /// In en, this message translates to:
  /// **'E2E Encryption Active'**
  String get e2eEncryptionActiveStatus;

  /// Status when encryption is not initialized
  ///
  /// In en, this message translates to:
  /// **'Encryption Not Set Up'**
  String get encryptionNotSetUp;

  /// Description of encryption algorithm used
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted with XChaCha20-Poly1305'**
  String get encryptionAlgorithm;

  /// Description of key derivation function
  ///
  /// In en, this message translates to:
  /// **'Key derivation: Argon2id'**
  String get keyDerivation;

  /// Status when master key is available
  ///
  /// In en, this message translates to:
  /// **'Master key: unlocked'**
  String get masterKeyUnlocked;

  /// Status when master key is not available
  ///
  /// In en, this message translates to:
  /// **'Master key: locked'**
  String get masterKeyLocked;

  /// Section header for encrypted item counts
  ///
  /// In en, this message translates to:
  /// **'Encrypted Items'**
  String get encryptedItems;

  /// Label for notes count and nav tab
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Label for tags count
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// Label for collections count
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsLabel;

  /// Label for AI content count
  ///
  /// In en, this message translates to:
  /// **'AI Content'**
  String get aiContent;

  /// Number of items for a category
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// Section header for recovery key
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get recoveryKeySection;

  /// Description of recovery key purpose
  ///
  /// In en, this message translates to:
  /// **'Use this key to recover your data if you forget your password.'**
  String get recoveryKeyUsage;

  /// Button to reveal the recovery key
  ///
  /// In en, this message translates to:
  /// **'View Recovery Key'**
  String get viewRecoveryKey;

  /// Message when no recovery key is found
  ///
  /// In en, this message translates to:
  /// **'No recovery key stored.'**
  String get noRecoveryKeyStored;

  /// Warning about missing recovery key
  ///
  /// In en, this message translates to:
  /// **'The recovery key was generated during registration. If you did not save it, you cannot recover your data without your password.'**
  String get recoveryKeyWarning;

  /// Button to copy recovery key
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// Button to hide the recovery key
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// Error loading recovery key
  ///
  /// In en, this message translates to:
  /// **'Failed to load recovery key'**
  String get failedToLoadRecoveryKey;

  /// Settings item title and dialog title
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Subtitle for change password
  ///
  /// In en, this message translates to:
  /// **'Re-encrypts all data with new key'**
  String get reEncryptsData;

  /// Dialog title for password verification
  ///
  /// In en, this message translates to:
  /// **'Verify Password'**
  String get verifyPassword;

  /// Password verification input label
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// Verify button label
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Snackbar for wrong password
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// Snackbar for verification failure
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// Warning in change password dialog
  ///
  /// In en, this message translates to:
  /// **'Warning: This will re-encrypt all your data.'**
  String get reEncryptWarning;

  /// Change password dialog submit button
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Snackbar for wrong current password
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIncorrect;

  /// Snackbar on successful password change
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccessfully;

  /// Snackbar on password change failure
  ///
  /// In en, this message translates to:
  /// **'Failed to change password: {error}'**
  String failedToChangePassword(String error);

  /// Section header for destructive actions
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Button to delete all data
  ///
  /// In en, this message translates to:
  /// **'Delete All Local Data'**
  String get deleteAllLocalData;

  /// Button to export backup
  ///
  /// In en, this message translates to:
  /// **'Export Encrypted Backup'**
  String get exportEncryptedBackup;

  /// Button to import backup
  ///
  /// In en, this message translates to:
  /// **'Import Encrypted Backup'**
  String get importEncryptedBackup;

  /// Dialog title for delete all
  ///
  /// In en, this message translates to:
  /// **'Delete All Data?'**
  String get deleteAllDataQuestion;

  /// Dialog body for delete all
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your notes, tags, and settings will be permanently deleted.'**
  String get deleteAllDataMessage;

  /// Confirm button for delete all
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get deleteEverything;

  /// Double confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure?'**
  String get areYouAbsolutelySure;

  /// Instruction to type DELETE
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm.'**
  String get typeDeleteToConfirm;

  /// Label for the confirmation input field
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get typeDelete;

  /// Snackbar after data deletion
  ///
  /// In en, this message translates to:
  /// **'All local data has been deleted'**
  String get allLocalDataDeleted;

  /// Snackbar on deletion failure
  ///
  /// In en, this message translates to:
  /// **'Failed to delete data: {error}'**
  String failedToDeleteData(String error);

  /// Dialog title for backup import
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get importBackup;

  /// Dialog body for backup import
  ///
  /// In en, this message translates to:
  /// **'This will import items from the backup file. Existing items will not be overwritten. Continue?'**
  String get importBackupMessage;

  /// Import confirm button
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Snackbar after successful import
  ///
  /// In en, this message translates to:
  /// **'Imported {count} items from backup'**
  String importedItemsFromBackup(int count);

  /// Snackbar on backup export failure
  ///
  /// In en, this message translates to:
  /// **'Backup export failed: {error}'**
  String backupExportFailed(String error);

  /// Snackbar on backup import failure
  ///
  /// In en, this message translates to:
  /// **'Backup import failed: {error}'**
  String backupImportFailed(String error);

  /// LLM config screen title
  ///
  /// In en, this message translates to:
  /// **'LLM Configuration'**
  String get llmConfigTitle;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No LLM configurations'**
  String get noLLMConfigs;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Add an LLM to enable AI features'**
  String get addLLMToEnableAI;

  /// Action label and button text
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get addProvider;

  /// Badge for the default LLM config
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// Tooltip for test button
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// Error message for LLM config loading
  ///
  /// In en, this message translates to:
  /// **'Failed to load configs'**
  String get failedToLoadConfigs;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Add LLM Provider'**
  String get addLLMProvider;

  /// Form field label for name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Form field label for provider dropdown
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// Hint text for model field
  ///
  /// In en, this message translates to:
  /// **'e.g., gpt-4o'**
  String get modelHint;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit LLM Provider'**
  String get editLLMProvider;

  /// Hint for optional API key update
  ///
  /// In en, this message translates to:
  /// **'New API Key (leave blank to keep current)'**
  String get newApiKeyHint;

  /// Snackbar while testing
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get testingConnection;

  /// Snackbar on test success
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccessful;

  /// Snackbar on test failure
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(String error);

  /// Confirmation dialog title for deleting a config
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteConfigQuestion(String name);

  /// Confirmation body for deleting config
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this LLM configuration?'**
  String get removeLLMConfigConfirm;

  /// Empty state for platform connections
  ///
  /// In en, this message translates to:
  /// **'No platforms available'**
  String get noPlatformsAvailable;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Platform connections will appear here'**
  String get platformConnectionsWillAppear;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load platforms'**
  String get failedToLoadPlatforms;

  /// Connect button label
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Verify button label
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// Disconnect button label
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Snackbar after connecting to a platform
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String connectedTo(String name);

  /// Snackbar on connection failure
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String failedToConnect(String error);

  /// Snackbar while verifying
  ///
  /// In en, this message translates to:
  /// **'Verifying connection...'**
  String get verifyingConnection;

  /// Snackbar on verify success
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get connectionVerified;

  /// Snackbar on verify failure
  ///
  /// In en, this message translates to:
  /// **'Connection invalid: {error}'**
  String connectionInvalid(String error);

  /// Snackbar on verification network error
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String verificationFailedError(String error);

  /// Dialog title for disconnecting
  ///
  /// In en, this message translates to:
  /// **'Disconnect {name}'**
  String disconnectPlatform(String name);

  /// Dialog body for disconnecting
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect your {name} account?'**
  String disconnectPlatformConfirm(String name);

  /// Snackbar after disconnecting
  ///
  /// In en, this message translates to:
  /// **'Disconnected from {name}'**
  String disconnectedFrom(String name);

  /// Snackbar on disconnect failure
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect: {error}'**
  String failedToDisconnect(String error);

  /// QR code dialog title
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// Instructions for QR code scanning
  ///
  /// In en, this message translates to:
  /// **'Open {platform} app and scan this QR code to login'**
  String scanQRInstructions(String platform);

  /// Done button label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Tags screen title
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get noTags;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Create tags to organize your notes'**
  String get createTagsToOrganize;

  /// Dialog title for creating a tag
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get newTag;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// Hint text for tag name
  ///
  /// In en, this message translates to:
  /// **'e.g., ideas, work, personal'**
  String get tagNameHint;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Placeholder for encrypted tag name
  ///
  /// In en, this message translates to:
  /// **'(encrypted)'**
  String get encrypted;

  /// Compose screen title and nav tab label
  ///
  /// In en, this message translates to:
  /// **'AI Compose'**
  String get aiCompose;

  /// Hero card title
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Writing'**
  String get aiPoweredWriting;

  /// Hero card description
  ///
  /// In en, this message translates to:
  /// **'Select your notes and let AI help you create polished content for any platform.'**
  String get aiComposeDesc;

  /// Button label to start composing
  ///
  /// In en, this message translates to:
  /// **'Start Composing'**
  String get startComposing;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recent Compositions'**
  String get recentCompositions;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No compositions yet'**
  String get noCompositionsYet;

  /// Bottom sheet heading
  ///
  /// In en, this message translates to:
  /// **'New Composition'**
  String get newComposition;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Topic or theme'**
  String get topicOrTheme;

  /// Hint text for topic input
  ///
  /// In en, this message translates to:
  /// **'What should the composition be about?'**
  String get topicHint;

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Target platform'**
  String get targetPlatform;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Select Notes'**
  String get selectNotes;

  /// Number of notes selected
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// Empty state in note selector
  ///
  /// In en, this message translates to:
  /// **'No notes available.\nCreate some notes first.'**
  String get noNotesAvailableCreate;

  /// Preview sheet heading
  ///
  /// In en, this message translates to:
  /// **'Content Preview'**
  String get contentPreview;

  /// Placeholder when content is empty
  ///
  /// In en, this message translates to:
  /// **'(No content)'**
  String get noContent;

  /// Copy button label
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Button to save content as a note
  ///
  /// In en, this message translates to:
  /// **'Save as Note'**
  String get saveAsNote;

  /// Snackbar after copying content
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Snackbar after saving as note
  ///
  /// In en, this message translates to:
  /// **'Saved as note'**
  String get savedAsNote;

  /// Publish screen title, nav tab label, and submit button
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Connected Platforms'**
  String get connectedPlatforms;

  /// Empty state in publish screen
  ///
  /// In en, this message translates to:
  /// **'No platforms connected'**
  String get noPlatformsConnected;

  /// Button to go to platform connections
  ///
  /// In en, this message translates to:
  /// **'Connect a Platform'**
  String get connectAPlatform;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Publish Content'**
  String get publishContent;

  /// Content form field label
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get tagsCommaSeparated;

  /// Hint for tags input
  ///
  /// In en, this message translates to:
  /// **'tag1, tag2, tag3'**
  String get tagsHint;

  /// Hint to select a platform
  ///
  /// In en, this message translates to:
  /// **'Select a platform above to publish'**
  String get selectPlatformToPublish;

  /// Success message after publishing
  ///
  /// In en, this message translates to:
  /// **'Published! Status: {status}'**
  String publishedStatus(String status);

  /// Validation error in publish form
  ///
  /// In en, this message translates to:
  /// **'Title and content are required'**
  String get titleAndContentRequired;

  /// Snackbar after publish request
  ///
  /// In en, this message translates to:
  /// **'Publish request submitted'**
  String get publishRequestSubmitted;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recent Publications'**
  String get recentPublications;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No publications yet'**
  String get noPublicationsYet;

  /// Button to view all publications
  ///
  /// In en, this message translates to:
  /// **'View All ({count})'**
  String viewAll(int count);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Publish History'**
  String get publishHistory;

  /// Tooltip for filter menu
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get filterByStatus;

  /// Filter option: show all
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Filter option and status
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// Filter option and status
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Filter option and status (in progress)
  ///
  /// In en, this message translates to:
  /// **'Publishing'**
  String get publishingStatus;

  /// Filter option and status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Empty state when filtering by status
  ///
  /// In en, this message translates to:
  /// **'No {status} publications'**
  String noPublicationsWithStatus(String status);

  /// Button to clear status filter
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get clearFilter;

  /// Empty state title (unfiltered)
  ///
  /// In en, this message translates to:
  /// **'No publications'**
  String get noPublications;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Published content will appear here'**
  String get publishedContentWillAppear;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Failed to load publish history'**
  String get failedToLoadPublishHistory;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get publishedDate;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// Detail row label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Section label in publish detail
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get contentLabel;

  /// Error loading publish detail
  ///
  /// In en, this message translates to:
  /// **'Failed to load detail: {error}'**
  String failedToLoadDetail(String error);

  /// Collections screen title
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsTitle;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get noCollectionsYet;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Group your notes into collections'**
  String get groupNotesIntoCollections;

  /// Action label and dialog title
  ///
  /// In en, this message translates to:
  /// **'New Collection'**
  String get newCollection;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get deleteCollectionQuestion;

  /// Confirmation body for deleting collection
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? Notes in this collection will not be deleted.'**
  String deleteCollectionConfirm(String title);

  /// Snackbar after collection deletion
  ///
  /// In en, this message translates to:
  /// **'Collection deleted'**
  String get collectionDeleted;

  /// Placeholder for untitled collections
  ///
  /// In en, this message translates to:
  /// **'Untitled Collection'**
  String get untitledCollection;

  /// Note count display with plural suffix
  ///
  /// In en, this message translates to:
  /// **'{count} note{suffix}'**
  String noteCount(int count, String suffix);

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Collection title'**
  String get collectionTitle;

  /// Hint for collection title
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this collection'**
  String get collectionTitleHint;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Collection not found'**
  String get collectionNotFound;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Failed to load collection'**
  String get failedToLoadCollection;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No notes in this collection'**
  String get noNotesInCollection;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Tap + to add notes'**
  String get tapToAddNotes;

  /// Action label and sheet heading
  ///
  /// In en, this message translates to:
  /// **'Add Notes'**
  String get addNotes;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove from collection?'**
  String get removeFromCollection;

  /// Confirmation body for removing note from collection
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from this collection? The note will not be deleted.'**
  String removeNoteConfirm(String title);

  /// Remove button label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Collection'**
  String get renameCollection;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollectionTooltip;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get deleteCollectionTooltip;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Collection'**
  String get deleteCollectionDialogTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'This collection and all its note associations will be removed. Notes themselves will not be deleted.'**
  String get deleteCollectionDialogMessage;

  /// Empty state in add notes sheet
  ///
  /// In en, this message translates to:
  /// **'No notes available'**
  String get noNotesAvailable;

  /// Tooltip for remove icon
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get removeFromCollectionTooltip;

  /// Search screen title
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Tooltip for clear filters button
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get clearAllFilters;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'Search your notes'**
  String get searchYourNotes;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter a query or use filters to find notes'**
  String get enterQueryOrFilters;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// Button to clear recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// Empty state title for search
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Empty state subtitle for search
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get tryAdjustingSearch;

  /// Error message for search failures
  ///
  /// In en, this message translates to:
  /// **'Search error: {error}'**
  String searchError(String error);

  /// Filter chip label
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// Filter chip label with count
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsFilter;

  /// Filter chip label with count
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsFilter;

  /// Filter chip label when tags are selected
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tagsCount(int count);

  /// Filter chip label when collections are selected
  ///
  /// In en, this message translates to:
  /// **'{count} collections'**
  String collectionsCount(int count);

  /// Search results count display, may show '50 / 320' format
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String resultsCount(String count);

  /// Snackbar when no tags for filter
  ///
  /// In en, this message translates to:
  /// **'No tags available'**
  String get noTagsAvailable;

  /// Snackbar when no collections for filter
  ///
  /// In en, this message translates to:
  /// **'No collections available'**
  String get noCollectionsAvailable;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Select tags'**
  String get selectTags;

  /// Apply button label
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Select collections'**
  String get selectCollections;

  /// Share sheet title
  ///
  /// In en, this message translates to:
  /// **'Share Note'**
  String get shareNote;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Password Protection'**
  String get passwordProtection;

  /// Toggle title
  ///
  /// In en, this message translates to:
  /// **'Require password'**
  String get requirePassword;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Recipients must enter a password to view'**
  String get requirePasswordDesc;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Expires After'**
  String get expiresAfter;

  /// Expiry option
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get oneHour;

  /// Expiry option
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get twentyFourHours;

  /// Expiry option
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get sevenDays;

  /// Expiry option: no expiration
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// Error when password toggle is on but field is empty
  ///
  /// In en, this message translates to:
  /// **'Password is required when password protection is enabled'**
  String get passwordRequiredForShare;

  /// Error when share creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create share link: {error}'**
  String failedToCreateShareLink(String error);

  /// Snackbar after copying share link
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopiedToClipboard;

  /// Button label and tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// Info text for password-protected links
  ///
  /// In en, this message translates to:
  /// **'This link is password-protected. Share the password separately.'**
  String get passwordProtectedShareInfo;

  /// Info text for public links
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can view the note.'**
  String get publicShareInfo;

  /// Expiry info text
  ///
  /// In en, this message translates to:
  /// **'Link expires {expiry}'**
  String linkExpiresIn(String expiry);

  /// Button label while creating share link
  ///
  /// In en, this message translates to:
  /// **'Encrypting...'**
  String get encrypting;

  /// Button label to create share
  ///
  /// In en, this message translates to:
  /// **'Create Share Link'**
  String get createShareLink;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// Notice shown after changing language
  ///
  /// In en, this message translates to:
  /// **'Language will take effect after restarting the app'**
  String get languageChangedNotice;

  /// Toggle for distraction-free writing mode
  ///
  /// In en, this message translates to:
  /// **'Zen mode'**
  String get zenMode;

  /// Tooltip for zen mode button
  ///
  /// In en, this message translates to:
  /// **'Enter focus mode'**
  String get enterZenMode;

  /// Tooltip to exit zen mode
  ///
  /// In en, this message translates to:
  /// **'Exit focus mode'**
  String get exitZenMode;

  /// Word count display
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 words} =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// Character count display
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 characters} =1{1 character} other{{count} characters}}'**
  String charCount(int count);

  /// Tooltip and bottom sheet title for importing notes
  ///
  /// In en, this message translates to:
  /// **'Import Notes'**
  String get importNotes;

  /// Import option for markdown files
  ///
  /// In en, this message translates to:
  /// **'Import Markdown'**
  String get importMarkdown;

  /// Import option for plain text files
  ///
  /// In en, this message translates to:
  /// **'Import Text Files'**
  String get importTextFiles;

  /// Import option for Apple Notes HTML exports
  ///
  /// In en, this message translates to:
  /// **'Import Apple Notes'**
  String get importAppleNotes;

  /// Snackbar after import finishes
  ///
  /// In en, this message translates to:
  /// **'Import complete: {count} notes imported, {skipped} skipped'**
  String importComplete(int count, int skipped);

  /// Screen title for markdown preview
  ///
  /// In en, this message translates to:
  /// **'Markdown Preview'**
  String get markdownPreview;

  /// Restore screen title and settings item
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get restoreFromBackup;

  /// File selection step title
  ///
  /// In en, this message translates to:
  /// **'Select Backup File'**
  String get selectBackupFile;

  /// File selection step description
  ///
  /// In en, this message translates to:
  /// **'Choose an AnyNote encrypted backup file (.enc) to restore your data.'**
  String get selectBackupFileDesc;

  /// Button to open file picker
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get browseFiles;

  /// Label for selected file display
  ///
  /// In en, this message translates to:
  /// **'Selected file'**
  String get selectedFile;

  /// Button to advance to the next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// Button to go back to the previous step
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Section header for backup info
  ///
  /// In en, this message translates to:
  /// **'Backup Details'**
  String get backupDetails;

  /// Label for backup format
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get backupFormat;

  /// Label for backup version number
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get backupVersion;

  /// Label for backup export date
  ///
  /// In en, this message translates to:
  /// **'Export Date'**
  String get exportDate;

  /// Label for total item count
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get totalItems;

  /// Section header for item type counts
  ///
  /// In en, this message translates to:
  /// **'Item Counts'**
  String get itemCounts;

  /// Section header for verification errors
  ///
  /// In en, this message translates to:
  /// **'Verification Errors'**
  String get verificationErrors;

  /// Status when backup is valid
  ///
  /// In en, this message translates to:
  /// **'Backup Verified'**
  String get backupValid;

  /// Status when backup has errors
  ///
  /// In en, this message translates to:
  /// **'Backup Verification Failed'**
  String get backupInvalid;

  /// Hint when crypto is locked
  ///
  /// In en, this message translates to:
  /// **'Unlock encryption to verify backup contents.'**
  String get unlockToVerify;

  /// Section header for restore preview
  ///
  /// In en, this message translates to:
  /// **'Restore Preview'**
  String get restorePreviewTitle;

  /// Note count in restore preview
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesToRestore;

  /// Tag count in restore preview
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsToRestore;

  /// Collection count in restore preview
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsToRestore;

  /// AI content count in restore preview
  ///
  /// In en, this message translates to:
  /// **'AI Content'**
  String get contentsToRestore;

  /// Label for earliest date in preview
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get earliestDate;

  /// Label for latest date in preview
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latestDate;

  /// Message when no conflicts exist
  ///
  /// In en, this message translates to:
  /// **'No conflicts detected. All items will be added as new.'**
  String get noConflictsDetected;

  /// Section header for note titles preview
  ///
  /// In en, this message translates to:
  /// **'Note Titles'**
  String get noteTitlesPreview;

  /// Overflow indicator for preview list
  ///
  /// In en, this message translates to:
  /// **'...and {count} more'**
  String andMoreItems(int count);

  /// Strategy selection title
  ///
  /// In en, this message translates to:
  /// **'Conflict Resolution'**
  String get conflictStrategyTitle;

  /// Strategy selection description
  ///
  /// In en, this message translates to:
  /// **'Choose how to handle items that already exist locally.'**
  String get conflictStrategyDesc;

  /// Overwrite strategy name
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get strategyOverwrite;

  /// Overwrite strategy description
  ///
  /// In en, this message translates to:
  /// **'Replace local items with backup versions'**
  String get strategyOverwriteDesc;

  /// Skip strategy name
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get strategySkip;

  /// Skip strategy description
  ///
  /// In en, this message translates to:
  /// **'Keep local items, skip backup duplicates'**
  String get strategySkipDesc;

  /// Keep both strategy name
  ///
  /// In en, this message translates to:
  /// **'Keep Both'**
  String get strategyKeepBoth;

  /// Keep both strategy description
  ///
  /// In en, this message translates to:
  /// **'Import backup items alongside existing ones (with \'(restored)\' suffix)'**
  String get strategyKeepBothDesc;

  /// Warning before starting restore
  ///
  /// In en, this message translates to:
  /// **'Restored items will be queued for sync. This may take a moment.'**
  String get restoreWarning;

  /// Button to begin restore operation
  ///
  /// In en, this message translates to:
  /// **'Start Restore'**
  String get startRestore;

  /// Status during restore
  ///
  /// In en, this message translates to:
  /// **'Restoring backup...'**
  String get restoringBackup;

  /// Progress text during restore
  ///
  /// In en, this message translates to:
  /// **'Processing {current} of {total}'**
  String restoreProgress(int current, int total);

  /// Success message after restore
  ///
  /// In en, this message translates to:
  /// **'Restore completed successfully'**
  String get restoreCompleted;

  /// Message when restore has errors
  ///
  /// In en, this message translates to:
  /// **'Restore completed with some errors'**
  String get restoreCompletedWithErrors;

  /// Section header for restore results
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get restoreResults;

  /// Count of restored items
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get itemsRestored;

  /// Count of skipped items
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get itemsSkipped;

  /// Count of conflicts
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get conflictsFound;

  /// Section header for error details
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errorsDuringRestore;

  /// Warning about conflicting items
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) already exist locally'**
  String conflictsDetected(int count);

  /// Conflicting notes count
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String existingNotesCount(int count);

  /// Conflicting tags count
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String existingTagsCount(int count);

  /// Conflicting collections count
  ///
  /// In en, this message translates to:
  /// **'{count} collections'**
  String existingCollectionsCount(int count);

  /// Conflicting AI content count
  ///
  /// In en, this message translates to:
  /// **'{count} AI contents'**
  String existingContentsCount(int count);

  /// Error when file picker fails
  ///
  /// In en, this message translates to:
  /// **'Failed to open file picker: {error}'**
  String filePickerError(String error);

  /// Subtitle for restore settings item
  ///
  /// In en, this message translates to:
  /// **'Restore data from an encrypted backup file'**
  String get restoreFromBackupDesc;

  /// Subtitle for import notes settings item
  ///
  /// In en, this message translates to:
  /// **'Import from Markdown, Apple Notes, or plain text'**
  String get importNotesDesc;

  /// Onboarding interactive demo page title
  ///
  /// In en, this message translates to:
  /// **'Write down your thoughts'**
  String get onboardingWriteTitle;

  /// Onboarding interactive demo page description
  ///
  /// In en, this message translates to:
  /// **'Create notes on any device -- your content will be securely encrypted'**
  String get onboardingWriteDesc;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// Discovery feed screen title
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverFeed;

  /// Empty state title when no public shared notes exist
  ///
  /// In en, this message translates to:
  /// **'No public notes yet'**
  String get noPublicNotes;

  /// Empty state subtitle for discovery feed
  ///
  /// In en, this message translates to:
  /// **'Shared notes marked as public will appear here.'**
  String get noPublicNotesDesc;

  /// Error message when discovery feed fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load discovery feed'**
  String get failedToLoadDiscoverFeed;

  /// Placeholder title for encrypted shared notes in discovery feed
  ///
  /// In en, this message translates to:
  /// **'Encrypted note'**
  String get encryptedNote;

  /// Error message when toggling a reaction fails
  ///
  /// In en, this message translates to:
  /// **'Failed to react'**
  String get reactionFailed;

  /// Relative time: months ago
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String monthsAgo(int count);

  /// File menu label
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// Menu item: create a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get menuNewNote;

  /// Menu item: save current note
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get menuSave;

  /// Menu item: import notes
  ///
  /// In en, this message translates to:
  /// **'Import...'**
  String get menuImport;

  /// Menu item: export notes
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get menuExport;

  /// Menu item: close current tab/view
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get menuCloseTab;

  /// Edit menu label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// Menu item: undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menuUndo;

  /// Menu item: redo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get menuRedo;

  /// Menu item: cut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get menuCut;

  /// Menu item: copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get menuCopy;

  /// Menu item: paste
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get menuPaste;

  /// Menu item: select all
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get menuSelectAll;

  /// Menu item: find/search
  ///
  /// In en, this message translates to:
  /// **'Find...'**
  String get menuFind;

  /// View menu label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// Menu item: toggle sidebar
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get menuToggleSidebar;

  /// Menu item: toggle markdown preview
  ///
  /// In en, this message translates to:
  /// **'Toggle Preview'**
  String get menuTogglePreview;

  /// Menu item: toggle distraction-free zen mode
  ///
  /// In en, this message translates to:
  /// **'Zen Mode'**
  String get menuZenMode;

  /// Menu item: enter full screen
  ///
  /// In en, this message translates to:
  /// **'Enter Full Screen'**
  String get menuFullScreen;

  /// Menu item: exit full screen
  ///
  /// In en, this message translates to:
  /// **'Exit Full Screen'**
  String get menuExitFullScreen;

  /// Help menu label
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Menu item: show about dialog
  ///
  /// In en, this message translates to:
  /// **'About AnyNote'**
  String get menuAbout;

  /// Menu item: show keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get menuKeyboardShortcuts;

  /// Title of the about dialog
  ///
  /// In en, this message translates to:
  /// **'About AnyNote'**
  String get aboutDialogTitle;

  /// App description in the about dialog
  ///
  /// In en, this message translates to:
  /// **'Local-first, privacy-first note-taking with end-to-end encryption.'**
  String get aboutDescription;

  /// Version display in about dialog
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Title of the keyboard shortcuts dialog
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutsDialogTitle;

  /// Shortcut description for creating a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get shortcutNewNote;

  /// Shortcut description for saving
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shortcutSave;

  /// Shortcut description for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shortcutSearch;

  /// Shortcut description for toggling sidebar
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get shortcutToggleSidebar;

  /// Shortcut description for export to PDF
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get shortcutExportPdf;

  /// Shortcut description for opening settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get shortcutSettings;

  /// Shortcut description for closing current note
  ///
  /// In en, this message translates to:
  /// **'Close Note'**
  String get shortcutCloseNote;

  /// Shortcut description for cycling to next note
  ///
  /// In en, this message translates to:
  /// **'Next Note'**
  String get shortcutNextNote;

  /// Shortcut description for toggling full screen
  ///
  /// In en, this message translates to:
  /// **'Toggle Full Screen'**
  String get shortcutFullScreen;

  /// Shortcut description for exiting zen mode or closing dialog
  ///
  /// In en, this message translates to:
  /// **'Exit Zen Mode / Close Dialog'**
  String get shortcutExitZen;

  /// Accessibility label for the Notes navigation tab
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTabLabel;

  /// Accessibility label for the Compose navigation tab
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get composeTabLabel;

  /// Accessibility label for the Publish navigation tab
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishTabLabel;

  /// Accessibility label for the Settings navigation tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTabLabel;
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
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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

  /// Fallback title for notes without a title
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

  /// Button label to retry a failed operation
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

  /// Feature row label in plan comparison
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

  /// Empty state in context note selector
  ///
  /// In en, this message translates to:
  /// **'No notes available. Create a note first.'**
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

  /// Snackbar after copying text
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

  /// Note count display with proper pluralization
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 notes} =1{1 note} other{{count} notes}}'**
  String noteCount(int count);

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

  /// Accessibility label for a version history item
  ///
  /// In en, this message translates to:
  /// **'Version {versionNumber}, {title}, {date}{currentSuffix}'**
  String versionSemanticLabel(
      int versionNumber, String title, String date, String currentSuffix);

  /// Appended to version semantic label for the current version
  ///
  /// In en, this message translates to:
  /// **', current'**
  String get currentSuffix;

  /// Semantic label prefix for note title
  ///
  /// In en, this message translates to:
  /// **'Note title: {title}'**
  String noteTitleLabel(String title);

  /// Label showing when a note was last updated
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String updatedDate(String date);

  /// Semantic label for the delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm delete note dialog'**
  String get confirmDeleteNoteDialog;

  /// Share link expiry: already expired
  ///
  /// In en, this message translates to:
  /// **'immediately'**
  String get expiryImmediately;

  /// Share link expiry: less than one hour remaining
  ///
  /// In en, this message translates to:
  /// **'in less than 1 hour'**
  String get expiryLessThanOneHour;

  /// Share link expiry: hours remaining
  ///
  /// In en, this message translates to:
  /// **'in {count} hours'**
  String expiryInHours(int count);

  /// Share link expiry: days remaining with pluralization
  ///
  /// In en, this message translates to:
  /// **'in {count} day{count, plural, =1{} other{s}}'**
  String expiryInDays(int count);

  /// Accessibility label for a composition card
  ///
  /// In en, this message translates to:
  /// **'Composition: {title}. {time}{platformSuffix}'**
  String compositionSemanticLabel(
      String title, String time, String platformSuffix);

  /// Appended to composition semantic label when platform is set
  ///
  /// In en, this message translates to:
  /// **'. Platform: {platform}'**
  String platformSuffix(String platform);

  /// Display name for generic platform in compose
  ///
  /// In en, this message translates to:
  /// **'Generic'**
  String get platformGeneric;

  /// Display name for XHS (Xiaohongshu) platform
  ///
  /// In en, this message translates to:
  /// **'XHS'**
  String get platformXhs;

  /// Display name for Twitter platform
  ///
  /// In en, this message translates to:
  /// **'Twitter'**
  String get platformTwitter;

  /// Display name for Blog platform
  ///
  /// In en, this message translates to:
  /// **'Blog'**
  String get platformBlog;

  /// Display name for LinkedIn platform
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get platformLinkedin;

  /// Title of the note clustering screen
  ///
  /// In en, this message translates to:
  /// **'Note Clusters'**
  String get noteClusters;

  /// Loading message while AI clusters notes
  ///
  /// In en, this message translates to:
  /// **'Clustering your notes...'**
  String get clusteringNotes;

  /// Sub-status during note clustering
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing {count} notes about \"{topic}\"'**
  String analyzingNotes(int count, String topic);

  /// Info header after clustering completes
  ///
  /// In en, this message translates to:
  /// **'AI found {count} themes. Select the ones to include.'**
  String foundThemesSelect(int count);

  /// Number of notes in a cluster
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String notesCount(int count);

  /// Number of selected clusters
  ///
  /// In en, this message translates to:
  /// **'{count} clusters selected'**
  String clustersSelected(int count);

  /// Button to generate outline from selected clusters
  ///
  /// In en, this message translates to:
  /// **'Generate Outline'**
  String get generateOutline;

  /// Title of the compose editor screen
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorTitle;

  /// Tooltip for style adaptation button
  ///
  /// In en, this message translates to:
  /// **'Adapt style for {platform}'**
  String adaptStyleFor(String platform);

  /// Tooltip for the save button in compose editor
  ///
  /// In en, this message translates to:
  /// **'Save as note'**
  String get saveNoteTooltip;

  /// Streaming indicator while AI generates content
  ///
  /// In en, this message translates to:
  /// **'AI is writing...'**
  String get aiWriting;

  /// Character count display
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String charsCount(int count);

  /// Hint text in empty compose editor
  ///
  /// In en, this message translates to:
  /// **'Your composition will appear here...'**
  String get compositionHint;

  /// Button label to go back to outline view
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outlineButton;

  /// Word count display
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordsCount(int count);

  /// SnackBar action to view a saved note
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewAction;

  /// Error message when saving a note fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save note'**
  String get failedToSaveNote;

  /// Title of the outline screen
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outlineTitle;

  /// Tooltip for the edit title button in outline screen
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get editTitleTooltip;

  /// Loading message while AI generates outline
  ///
  /// In en, this message translates to:
  /// **'Generating outline...'**
  String get generatingOutline;

  /// Sub-status during outline generation
  ///
  /// In en, this message translates to:
  /// **'Building structure from {count} clusters'**
  String buildingStructureFromClusters(int count);

  /// Message when outline generation produced nothing
  ///
  /// In en, this message translates to:
  /// **'No outline generated.'**
  String get noOutlineGenerated;

  /// Section count with reorder hint
  ///
  /// In en, this message translates to:
  /// **'{count} sections -- drag to reorder'**
  String sectionsDragToReorder(int count);

  /// Label before the list of key points in an outline section
  ///
  /// In en, this message translates to:
  /// **'Key Points:'**
  String get keyPoints;

  /// Source cluster label in outline section
  ///
  /// In en, this message translates to:
  /// **'From cluster {number}'**
  String fromCluster(int number);

  /// Button to expand outline into full draft
  ///
  /// In en, this message translates to:
  /// **'Expand to Draft'**
  String get expandToDraft;

  /// Dialog title for editing the outline title
  ///
  /// In en, this message translates to:
  /// **'Edit Title'**
  String get editTitle;

  /// Semantic label for the login screen icon
  ///
  /// In en, this message translates to:
  /// **'AnyNote login screen'**
  String get loginScreenLabel;

  /// Semantic label prefix for error messages
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorLabel(String message);

  /// Semantic label for the registration screen icon
  ///
  /// In en, this message translates to:
  /// **'AnyNote registration screen'**
  String get registrationScreenLabel;

  /// Error when crypto key derivation fails during registration
  ///
  /// In en, this message translates to:
  /// **'Key derivation failed. Please try again.'**
  String get keyDerivationFailed;

  /// Animated demo text in onboarding page 3
  ///
  /// In en, this message translates to:
  /// **'My secret note...'**
  String get demoSecretNote;

  /// Error message when note import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// Placeholder text in tablet layout detail pane
  ///
  /// In en, this message translates to:
  /// **'Select a note to view'**
  String get selectNoteToView;

  /// Fallback title when collection has no plain title
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionFallback;

  /// Fallback value for unknown data
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Free plan display name
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePlan;

  /// Description of the Markdown import format
  ///
  /// In en, this message translates to:
  /// **'Import Markdown (.md) files with optional YAML frontmatter. Supported frontmatter fields: title, date, and tags. Falls back to filename for the title if none is specified.'**
  String get importMarkdownDesc;

  /// Section header for the import source picker
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceHeader;

  /// Button to select files for import
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// Subtitle for the Markdown file picker button
  ///
  /// In en, this message translates to:
  /// **'Choose one or more .md files'**
  String get selectMdFilesSubtitle;

  /// Button to select a folder for import
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get selectFolder;

  /// Subtitle for the Markdown folder picker button
  ///
  /// In en, this message translates to:
  /// **'Import all .md files from a folder'**
  String get importMdFolderSubtitle;

  /// File picker dialog title for Markdown files
  ///
  /// In en, this message translates to:
  /// **'Select Markdown Files'**
  String get selectMdFilesTitle;

  /// SnackBar when no valid Markdown files were chosen
  ///
  /// In en, this message translates to:
  /// **'No .md files selected.'**
  String get noMdFilesSelected;

  /// SnackBar when a feature requiring filesystem access is used on web platform
  ///
  /// In en, this message translates to:
  /// **'This feature is not supported on web.'**
  String get notSupportedOnWeb;

  /// Folder picker dialog title for Markdown import
  ///
  /// In en, this message translates to:
  /// **'Select Folder with Markdown Files'**
  String get selectMdFolderTitle;

  /// Section header for Apple Notes import
  ///
  /// In en, this message translates to:
  /// **'Apple Notes Export'**
  String get appleNotesExportHeader;

  /// Description of the Apple Notes import format
  ///
  /// In en, this message translates to:
  /// **'Import notes exported from the Apple Notes app. Select a folder containing HTML files exported from Apple Notes (one file per note). Basic formatting (bold, italic, headings, lists) will be converted to Markdown.'**
  String get appleNotesImportDesc;

  /// Subtitle for the Apple Notes folder picker
  ///
  /// In en, this message translates to:
  /// **'Choose a folder with Apple Notes HTML files'**
  String get selectAppleNotesFolderSubtitle;

  /// Folder picker dialog title for Apple Notes import
  ///
  /// In en, this message translates to:
  /// **'Select Apple Notes Export Folder'**
  String get selectAppleNotesFolderTitle;

  /// Section header for plain text import
  ///
  /// In en, this message translates to:
  /// **'Plain Text Files'**
  String get plainTextFilesHeader;

  /// Description of the plain text import format
  ///
  /// In en, this message translates to:
  /// **'Import plain text (.txt) files as notes. The first line of each file becomes the note title (if shorter than 100 characters); otherwise the filename is used as the title.'**
  String get plainTextImportDesc;

  /// Subtitle for the text file picker button
  ///
  /// In en, this message translates to:
  /// **'Choose one or more .txt files'**
  String get selectTxtFilesSubtitle;

  /// Subtitle for the text folder picker button
  ///
  /// In en, this message translates to:
  /// **'Import all .txt files from a folder'**
  String get importTxtFolderSubtitle;

  /// File picker dialog title for text files
  ///
  /// In en, this message translates to:
  /// **'Select Text Files'**
  String get selectTextFilesTitle;

  /// SnackBar when no valid text files were chosen
  ///
  /// In en, this message translates to:
  /// **'No .txt files selected.'**
  String get noTxtFilesSelected;

  /// Folder picker dialog title for text import
  ///
  /// In en, this message translates to:
  /// **'Select Folder with Text Files'**
  String get selectTextFolderTitle;

  /// Import result: number of files skipped with pluralization
  ///
  /// In en, this message translates to:
  /// **'{count} file{count, plural, =1{} other{s}}'**
  String fileCount(int count);

  /// Truncated error list suffix
  ///
  /// In en, this message translates to:
  /// **'... and {count} more errors'**
  String andMoreErrors(int count);

  /// Step label in restore flow: select file
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get stepFile;

  /// Step label in restore flow: verify backup
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get stepVerify;

  /// Step label in restore flow: preview contents
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get stepPreview;

  /// Step label in restore flow: choose restore strategy
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get stepStrategy;

  /// Step label in restore flow: execute restore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get stepRestore;

  /// Error when shared note decryption fails
  ///
  /// In en, this message translates to:
  /// **'Failed to decrypt the shared note. The link may be corrupted or expired.'**
  String get decryptFailed;

  /// Loading message while decrypting a shared note
  ///
  /// In en, this message translates to:
  /// **'Decrypting shared note...'**
  String get decryptingSharedNote;

  /// Fallback error title for decryption failure
  ///
  /// In en, this message translates to:
  /// **'Could not decrypt the shared note'**
  String get couldNotDecryptSharedNote;

  /// Error detail explaining why decryption failed
  ///
  /// In en, this message translates to:
  /// **'The link may be corrupted, expired, or incomplete.'**
  String get linkCorruptedExpired;

  /// Title of the password input section for protected shares
  ///
  /// In en, this message translates to:
  /// **'Password Required'**
  String get passwordRequiredTitle;

  /// Instruction text above the password field for shared notes
  ///
  /// In en, this message translates to:
  /// **'Enter the password to view this shared note.'**
  String get enterPasswordToView;

  /// Button to decrypt a password-protected shared note
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// Label for server-shared notes
  ///
  /// In en, this message translates to:
  /// **'Shared via link'**
  String get sharedViaLink;

  /// Label for self-contained shared notes
  ///
  /// In en, this message translates to:
  /// **'Shared note'**
  String get sharedNote;

  /// Semantic label for a platform card in publish screen
  ///
  /// In en, this message translates to:
  /// **'Platform: {name}{subtitleSuffix}{selectedSuffix}'**
  String platformSemanticLabel(
      String name, String subtitleSuffix, String selectedSuffix);

  /// Semantic label for a publish history item
  ///
  /// In en, this message translates to:
  /// **'Published: {title}. Platform: {platform}. Status: {status}{dateSuffix}'**
  String publishedSemanticLabel(
      String title, String platform, String status, String dateSuffix);

  /// Semantic label for the open-in-browser button
  ///
  /// In en, this message translates to:
  /// **'Open published article in browser'**
  String get openInBrowser;

  /// Semantic label for status chip
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);

  /// Semantic indicator that an item is selected
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectedLabel;

  /// Date range display format
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String dateRangeFormat(String start, String end);

  /// Tab label for built-in templates
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtInTab;

  /// Tab label for user-created templates
  ///
  /// In en, this message translates to:
  /// **'My Templates'**
  String get myTemplatesTab;

  /// Dialog title for template deletion
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplateConfirm;

  /// Dialog body for template deletion
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteTemplateMessage(String name);

  /// Label for the template name text field
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateNameLabel;

  /// Hint for the template content text field
  ///
  /// In en, this message translates to:
  /// **'Use [date] for current date'**
  String get templateDateHint;

  /// Banner text shown when the device is offline
  ///
  /// In en, this message translates to:
  /// **'You are offline — changes will sync when connected'**
  String get offlineBanner;

  /// Message shown when encryption keys are not unlocked
  ///
  /// In en, this message translates to:
  /// **'Please unlock your vault first'**
  String get unlockRequired;

  /// Placeholder text in the detail pane when no item is selected
  ///
  /// In en, this message translates to:
  /// **'Select an item to view'**
  String get selectAnItemToView;

  /// Title for features not yet available
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Message for features not yet available
  ///
  /// In en, this message translates to:
  /// **'This feature is not yet available. Stay tuned for future updates!'**
  String get comingSoonMessage;

  /// Button label to dismiss a dialog
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// User message for network errors
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Please check your internet connection.'**
  String get errorConnection;

  /// User message for server errors
  ///
  /// In en, this message translates to:
  /// **'A server error occurred. Please try again later.'**
  String get errorServer;

  /// User message for auth errors
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errorSessionExpired;

  /// User message for forbidden errors
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get errorAccessDenied;

  /// User message for not-found errors
  ///
  /// In en, this message translates to:
  /// **'The requested item could not be found.'**
  String get errorNotFound;

  /// User message for rate-limit errors without specific time
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// User message for rate-limit errors with specific retry time
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait {seconds} seconds and try again.'**
  String errorRateLimitedSeconds(int seconds);

  /// User message for conflict errors
  ///
  /// In en, this message translates to:
  /// **'A conflict was detected. Please refresh and try again.'**
  String get errorConflict;

  /// User message for crypto-locked errors
  ///
  /// In en, this message translates to:
  /// **'Encryption keys are locked. Please unlock to continue.'**
  String get errorCryptoLocked;

  /// User message for key derivation errors
  ///
  /// In en, this message translates to:
  /// **'Key derivation failed. Please check your password.'**
  String get errorKeyDerivation;

  /// User message for crypto operation errors
  ///
  /// In en, this message translates to:
  /// **'An encryption error occurred. Please try again.'**
  String get errorCryptoOperation;

  /// User message for sync errors
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {message}'**
  String errorSync(String message);

  /// User message for storage errors
  ///
  /// In en, this message translates to:
  /// **'A local storage error occurred. Please restart the app.'**
  String get errorStorage;

  /// User message for unknown errors
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnexpected;

  /// Dialog title for network errors
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get errorTitleConnection;

  /// Dialog title for server errors
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get errorTitleServer;

  /// Dialog title for auth errors
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get errorTitleSessionExpired;

  /// Dialog title for forbidden errors
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get errorTitleAccessDenied;

  /// Dialog title for not-found errors
  ///
  /// In en, this message translates to:
  /// **'Not Found'**
  String get errorTitleNotFound;

  /// Dialog title for rate-limit errors
  ///
  /// In en, this message translates to:
  /// **'Rate Limited'**
  String get errorTitleRateLimited;

  /// Dialog title for validation errors
  ///
  /// In en, this message translates to:
  /// **'Invalid Input'**
  String get errorTitleInvalidInput;

  /// Dialog title for conflict errors
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get errorTitleConflict;

  /// Dialog title for crypto-locked errors
  ///
  /// In en, this message translates to:
  /// **'Encryption Locked'**
  String get errorTitleCryptoLocked;

  /// Dialog title for key derivation errors
  ///
  /// In en, this message translates to:
  /// **'Key Error'**
  String get errorTitleKeyError;

  /// Dialog title for crypto operation errors
  ///
  /// In en, this message translates to:
  /// **'Encryption Error'**
  String get errorTitleCrypto;

  /// Dialog title for sync errors
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get errorTitleSync;

  /// Dialog title for storage errors
  ///
  /// In en, this message translates to:
  /// **'Storage Error'**
  String get errorTitleStorage;

  /// Placeholder content shown when Terms of Service is not yet available
  ///
  /// In en, this message translates to:
  /// **'Terms of Service are currently being drafted. For now, our Privacy Policy governs the use of AnyNote services.'**
  String get termsOfServiceContent;

  /// Dialog title for KDF parameter migration prompt
  ///
  /// In en, this message translates to:
  /// **'Security Upgrade Available'**
  String get kdfMigrationTitle;

  /// Body text explaining the KDF migration benefit
  ///
  /// In en, this message translates to:
  /// **'Your encryption keys use older, weaker parameters. We recommend upgrading to stronger key derivation parameters for better security. This requires re-deriving your keys and will take a moment.'**
  String get kdfMigrationMessage;

  /// Button label to accept KDF migration
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get kdfMigrationUpgrade;

  /// Button label to decline KDF migration
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get kdfMigrationSkip;

  /// Loading message shown during KDF migration
  ///
  /// In en, this message translates to:
  /// **'Upgrading encryption parameters...'**
  String get kdfMigrationInProgress;

  /// Success message after KDF migration completes
  ///
  /// In en, this message translates to:
  /// **'Encryption parameters upgraded successfully.'**
  String get kdfMigrationSuccess;

  /// Error message when KDF migration fails
  ///
  /// In en, this message translates to:
  /// **'Migration failed. You can continue, but your keys use older parameters.'**
  String get kdfMigrationFailed;

  /// Title for the web/native encryption incompatibility warning
  ///
  /// In en, this message translates to:
  /// **'Cross-Platform Encryption Notice'**
  String get crossPlatformWarningTitle;

  /// Body text explaining why web and native ciphertexts are incompatible
  ///
  /// In en, this message translates to:
  /// **'Notes encrypted on mobile (Android/iOS) cannot be decrypted on web, and vice versa. This is because mobile uses Argon2id while web uses PBKDF2 for key derivation, producing different encryption keys even with the same password.'**
  String get crossPlatformWarningMessage;

  /// Title of the AI chat screen
  ///
  /// In en, this message translates to:
  /// **'AI Chat Assistant'**
  String get aiChatAssistant;

  /// Welcome message in empty AI chat
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your notes'**
  String get aiChatWelcome;

  /// Subtitle for the AI chat empty state
  ///
  /// In en, this message translates to:
  /// **'Select notes as context for more relevant answers.'**
  String get aiChatWelcomeDesc;

  /// Tooltip and title for context note selector
  ///
  /// In en, this message translates to:
  /// **'Select Context Notes'**
  String get selectContextNotes;

  /// Indicator showing how many notes are selected as chat context
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} selected as context'**
  String contextNotesCount(int count);

  /// Tooltip for starting a new chat session
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Hint text in the chat input field
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeYourMessage;

  /// Title of the AI summary bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Smart Summary'**
  String get smartSummary;

  /// Description shown before generating a summary
  ///
  /// In en, this message translates to:
  /// **'Generate a concise AI summary of your note content.'**
  String get summaryPromptDesc;

  /// Button to trigger AI summary generation
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get generateSummary;

  /// Replace button label
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// Title of the AI tag suggestion bottom sheet
  ///
  /// In en, this message translates to:
  /// **'AI Tag Suggestion'**
  String get aiTagSuggestion;

  /// Button to trigger AI tag suggestion
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get suggestTags;

  /// Loading message while AI analyzes content for tags
  ///
  /// In en, this message translates to:
  /// **'Analyzing content...'**
  String get analyzingContent;

  /// Description before tag suggestions are generated
  ///
  /// In en, this message translates to:
  /// **'Tap \"Suggest\" to let AI analyze your note and recommend tags.'**
  String get tapSuggestTagsDesc;

  /// Instruction text above suggested tag chips
  ///
  /// In en, this message translates to:
  /// **'Select the tags you want to apply:'**
  String get selectTagsToApply;

  /// Button to apply selected tags
  ///
  /// In en, this message translates to:
  /// **'Apply {count} tag{count, plural, =1{} other{s}}'**
  String applyTags(int count);

  /// Title of the AI translation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'AI Translation'**
  String get aiTranslation;

  /// Label before the language selector
  ///
  /// In en, this message translates to:
  /// **'Translate to:'**
  String get translateTo;

  /// Button to trigger translation
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// Placeholder text before translation
  ///
  /// In en, this message translates to:
  /// **'Translation will appear here...'**
  String get translationWillAppear;

  /// Button to insert translated text below selection
  ///
  /// In en, this message translates to:
  /// **'Insert Below'**
  String get insertBelow;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// Title of the grammar/writing polish bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Writing Polish'**
  String get writingPolish;

  /// Description before grammar check
  ///
  /// In en, this message translates to:
  /// **'Fix grammar, spelling, and improve readability with AI.'**
  String get writingPolishDesc;

  /// Button to trigger grammar check
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get checkGrammar;

  /// Loading message during grammar check
  ///
  /// In en, this message translates to:
  /// **'Checking grammar...'**
  String get checkingGrammar;

  /// Label for the original text in diff view
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// Label for the corrected text in diff view
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get corrected;

  /// Button to reject the AI suggestion
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Button to accept all corrections
  ///
  /// In en, this message translates to:
  /// **'Accept All'**
  String get acceptAll;

  /// Tooltip for the AI features overflow menu in the editor
  ///
  /// In en, this message translates to:
  /// **'AI Features'**
  String get aiFeatures;

  /// Plan screen title
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTitle;

  /// Current plan display
  ///
  /// In en, this message translates to:
  /// **'Current Plan: {plan}'**
  String currentPlan(String plan);

  /// Label for notes count in plan usage
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get planNotesCount;

  /// Label for AI usage in plan usage
  ///
  /// In en, this message translates to:
  /// **'AI Usage'**
  String get aiUsage;

  /// Label for storage used in plan usage
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageUsed;

  /// Unlimited plan limit display
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// Section header for plan comparison
  ///
  /// In en, this message translates to:
  /// **'Compare Plans'**
  String get comparePlans;

  /// Feature row label in plan comparison
  ///
  /// In en, this message translates to:
  /// **'Max Notes'**
  String get maxNotes;

  /// Feature row label in plan comparison
  ///
  /// In en, this message translates to:
  /// **'AI Daily Quota'**
  String get aiDailyQuota;

  /// Feature row label in plan comparison
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Feature row label in plan comparison
  ///
  /// In en, this message translates to:
  /// **'Max Devices'**
  String get maxDevices;

  /// Feature row label in plan comparison
  ///
  /// In en, this message translates to:
  /// **'Collaboration'**
  String get collaboration;

  /// Negative answer in plan comparison
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Positive answer in plan comparison
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Button to restore previous purchase
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// Message when restore purchase is not yet available
  ///
  /// In en, this message translates to:
  /// **'Restore purchase will be available soon.'**
  String get restorePurchaseComingSoon;

  /// Badge text for lifetime plan users
  ///
  /// In en, this message translates to:
  /// **'Lifetime Member -- all features unlocked forever.'**
  String get lifetimeMember;

  /// Upgrade dialog title
  ///
  /// In en, this message translates to:
  /// **'Select a Plan'**
  String get selectPlan;

  /// Pro plan description in upgrade dialog
  ///
  /// In en, this message translates to:
  /// **'Unlimited notes, 500 AI requests/day, 5 GB storage'**
  String get proPlanDescription;

  /// Lifetime plan description in upgrade dialog
  ///
  /// In en, this message translates to:
  /// **'All Pro features, forever -- one-time payment'**
  String get lifetimePlanDescription;

  /// Error when plan info fails to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load plan info.'**
  String get unableToLoadPlan;

  /// Profile settings item title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Profile settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Edit display name and bio'**
  String get editPublicProfile;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileTitle;

  /// Form field label for display name
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// Hint for display name field
  ///
  /// In en, this message translates to:
  /// **'How others see you'**
  String get displayNameHint;

  /// Form field label for bio
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// Hint for bio field
  ///
  /// In en, this message translates to:
  /// **'Tell others about yourself'**
  String get bioHint;

  /// Toggle title for public profile visibility
  ///
  /// In en, this message translates to:
  /// **'Public Profile'**
  String get publicProfile;

  /// Toggle subtitle for public profile
  ///
  /// In en, this message translates to:
  /// **'Allow others to find and view your profile'**
  String get publicProfileDesc;

  /// Snackbar after profile save
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// Snackbar when profile save fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile'**
  String get profileSaveFailed;

  /// Error when profile fails to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile.'**
  String get unableToLoadProfile;

  /// Onboarding page 1 title
  ///
  /// In en, this message translates to:
  /// **'Secure Notes'**
  String get onboardingSecureNotesTitle;

  /// Onboarding page 1 description
  ///
  /// In en, this message translates to:
  /// **'Every note is encrypted end-to-end on your device before it reaches the cloud. No one -- not even us -- can read your notes.'**
  String get onboardingSecureNotesDesc;

  /// Onboarding page 3 title
  ///
  /// In en, this message translates to:
  /// **'Publish Everywhere'**
  String get onboardingPublishTitle;

  /// Onboarding page 3 description
  ///
  /// In en, this message translates to:
  /// **'One-click publish to your favorite platforms. Share your ideas with the world instantly.'**
  String get onboardingPublishDesc;

  /// Onboarding page 4 title
  ///
  /// In en, this message translates to:
  /// **'Collaborate in Real-time'**
  String get onboardingCollaborateTitle;

  /// Onboarding page 4 description
  ///
  /// In en, this message translates to:
  /// **'Work together on notes with live updates. Changes sync instantly across all devices.'**
  String get onboardingCollaborateDesc;
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

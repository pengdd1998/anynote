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

  /// Sort option: manual drag-and-drop reordering
  ///
  /// In en, this message translates to:
  /// **'Custom Order'**
  String get sortCustom;

  /// Hint shown when custom sort is active
  ///
  /// In en, this message translates to:
  /// **'Drag notes to reorder'**
  String get reorderModeHint;

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

  /// Empty state message when there are no notes
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

  /// Button to exit selection mode
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

  /// Title of share dialog and tooltip for share button
  ///
  /// In en, this message translates to:
  /// **'Share this note'**
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

  /// Keyboard shortcut description for creating a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get shortcutNewNote;

  /// Shortcut description for saving
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shortcutSave;

  /// Keyboard shortcut description for opening search
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

  /// Generic label for templates feature
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// Title of the template picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Choose a Template'**
  String get templatePicker;

  /// Menu option to create a note from a template
  ///
  /// In en, this message translates to:
  /// **'Create from Template'**
  String get createFromTemplate;

  /// Card option to create a blank note without a template
  ///
  /// In en, this message translates to:
  /// **'Create from Scratch'**
  String get createFromScratch;

  /// Title of the template management screen
  ///
  /// In en, this message translates to:
  /// **'Template Management'**
  String get templateManagement;

  /// Button label to create a new template
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get newTemplate;

  /// Button label to edit an existing template
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get editTemplate;

  /// Button label to delete a template
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get deleteTemplate;

  /// Form field label for template name
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// Form field label for template description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get templateDescription;

  /// Form field label for template content
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get templateContent;

  /// Form field label for template category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get templateCategory;

  /// Category label for work templates
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryWork;

  /// Category label for personal templates
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// Category label for creative templates
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get categoryCreative;

  /// Section header for built-in templates
  ///
  /// In en, this message translates to:
  /// **'Built-in Templates'**
  String get builtInTemplates;

  /// Section header for user-created templates
  ///
  /// In en, this message translates to:
  /// **'My Templates'**
  String get userTemplates;

  /// Shows how many times a template has been used
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String templateUsed(int count);

  /// Button label to duplicate a built-in template
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateTemplate;

  /// Empty state message when no templates exist
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get noTemplates;

  /// Snackbar confirmation after saving a template
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateSaved;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Meeting Notes'**
  String get templateMeetingNotes;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Daily Journal'**
  String get templateDailyJournal;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Project Plan'**
  String get templateProjectPlan;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Reading Notes'**
  String get templateReadingNotes;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Weekly Review'**
  String get templateWeeklyReview;

  /// Built-in template name
  ///
  /// In en, this message translates to:
  /// **'Brainstorm'**
  String get templateBrainstorm;

  /// Built-in template name for empty template
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get templateBlank;

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

  /// Title for note links section
  ///
  /// In en, this message translates to:
  /// **'Note Links'**
  String get noteLinks;

  /// Title for backlinks bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Backlinks'**
  String get backlinks;

  /// Empty state when no notes link to this note
  ///
  /// In en, this message translates to:
  /// **'No backlinks found'**
  String get noBacklinks;

  /// Title for the knowledge graph screen
  ///
  /// In en, this message translates to:
  /// **'Knowledge Graph'**
  String get knowledgeGraph;

  /// Empty state when graph has no nodes
  ///
  /// In en, this message translates to:
  /// **'No links to display'**
  String get graphEmpty;

  /// Title for the AI agent action screen
  ///
  /// In en, this message translates to:
  /// **'AI Agent'**
  String get aiAgent;

  /// Section header for AI agent actions
  ///
  /// In en, this message translates to:
  /// **'Select an action'**
  String get selectAction;

  /// AI agent action: organize notes
  ///
  /// In en, this message translates to:
  /// **'Organize Notes'**
  String get organizeNotes;

  /// AI agent action: summarize notes
  ///
  /// In en, this message translates to:
  /// **'Summarize Notes'**
  String get summarizeNotes;

  /// AI agent action: create a note
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get createNote;

  /// Error status for AI agent
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get agentFailed;

  /// Success status for AI agent
  ///
  /// In en, this message translates to:
  /// **'Action complete'**
  String get agentComplete;

  /// Tooltip for backlinks button in editor
  ///
  /// In en, this message translates to:
  /// **'View backlinks'**
  String get viewBacklinks;

  /// Button tooltip for inserting wiki-style [[links]]
  ///
  /// In en, this message translates to:
  /// **'Wiki Link'**
  String get wikiLink;

  /// Title for wiki link picker sheet
  ///
  /// In en, this message translates to:
  /// **'Link to Note'**
  String get linkToNote;

  /// Section header for notes linked from current note
  ///
  /// In en, this message translates to:
  /// **'Related Notes'**
  String get relatedNotes;

  /// Empty state when no outbound links exist
  ///
  /// In en, this message translates to:
  /// **'No related notes'**
  String get noRelatedNotes;

  /// Placeholder hint in wiki link picker
  ///
  /// In en, this message translates to:
  /// **'Start typing to search notes'**
  String get startTypingToSearch;

  /// Empty state message when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No notes found'**
  String get noNotesFound;

  /// Settings toggle title for periodic background sync
  ///
  /// In en, this message translates to:
  /// **'Background sync'**
  String get backgroundSync;

  /// Settings toggle subtitle for background sync
  ///
  /// In en, this message translates to:
  /// **'Sync notes periodically when the app is closed'**
  String get backgroundSyncDesc;

  /// Toggle state label: enabled
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// Toggle state label: disabled
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// Trash screen title
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// Action to permanently delete all trashed notes
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get emptyTrash;

  /// Confirmation message for emptying trash
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete all notes in the trash? This action cannot be undone.'**
  String get emptyTrashConfirm;

  /// Snackbar message after emptying trash
  ///
  /// In en, this message translates to:
  /// **'Trash emptied'**
  String get emptyTrashDone;

  /// Empty state title when trash is empty
  ///
  /// In en, this message translates to:
  /// **'No deleted notes'**
  String get noDeletedNotes;

  /// Action to restore a note from trash
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreNote;

  /// Action to permanently delete a note
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get permanentlyDelete;

  /// Label showing when a note was deleted
  ///
  /// In en, this message translates to:
  /// **'Deleted {date}'**
  String deletedAt(String date);

  /// Label showing deletion date in trash
  ///
  /// In en, this message translates to:
  /// **'Deleted on {date}'**
  String deletedOn(String date);

  /// Empty state title when trash has no notes
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmpty;

  /// Empty state subtitle for trash
  ///
  /// In en, this message translates to:
  /// **'Notes you delete will appear here'**
  String get trashEmptyDesc;

  /// Confirmation dialog for permanently deleting a note
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{title}\"?'**
  String permanentlyDeleteNoteConfirm(String title);

  /// Action to select all notes in batch mode
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// Action to deselect all notes in batch mode
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// Batch action to pin selected notes
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get batchPin;

  /// Batch action to unpin selected notes
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get batchUnpin;

  /// Batch action to delete selected notes
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get batchDelete;

  /// Batch action to add tags to selected notes
  ///
  /// In en, this message translates to:
  /// **'Add Tags'**
  String get batchAddTags;

  /// Label showing count of selected notes
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedNotes(int count);

  /// Confirmation for batch deleting notes
  ///
  /// In en, this message translates to:
  /// **'Delete {count} note{count, plural, =1{} other{s}}?'**
  String deleteSelectedNotes(int count);

  /// Confirmation message for batch delete
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the selected notes? They will be moved to trash.'**
  String get deleteSelectedNotesConfirm;

  /// Snackbar message after batch deleting notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} moved to trash'**
  String notesDeleted(int count);

  /// Snackbar message after batch pinning notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} pinned'**
  String notesPinned(int count);

  /// Snackbar message after batch unpinning notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} unpinned'**
  String notesUnpinned(int count);

  /// Settings section header for appearance settings
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Theme settings item title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Theme option: light mode
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option: dark mode
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Theme option: follow system setting
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme option: high contrast light mode (WCAG AAA)
  ///
  /// In en, this message translates to:
  /// **'High Contrast Light'**
  String get themeHighContrastLight;

  /// Theme option: high contrast dark mode (WCAG AAA)
  ///
  /// In en, this message translates to:
  /// **'High Contrast Dark'**
  String get themeHighContrastDark;

  /// Settings toggle title for reduce motion accessibility
  ///
  /// In en, this message translates to:
  /// **'Reduce Motion'**
  String get reduceMotion;

  /// Settings toggle subtitle for reduce motion
  ///
  /// In en, this message translates to:
  /// **'Minimize animations throughout the app'**
  String get reduceMotionDesc;

  /// Reduce motion subtitle when following system
  ///
  /// In en, this message translates to:
  /// **'Following system setting'**
  String get reduceMotionSystem;

  /// Reduce motion subtitle when manually enabled
  ///
  /// In en, this message translates to:
  /// **'On (animations disabled)'**
  String get reduceMotionOn;

  /// Reduce motion subtitle when manually disabled
  ///
  /// In en, this message translates to:
  /// **'Off (animations enabled)'**
  String get reduceMotionOff;

  /// Button label to copy invite code
  ///
  /// In en, this message translates to:
  /// **'Copy Invite Code'**
  String get copyInviteCode;

  /// Snackbar message after invite code is copied
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get inviteCodeCopied;

  /// Label for text field to enter an invite code
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code'**
  String get enterInviteCode;

  /// Button label and snackbar message to join a shared note
  ///
  /// In en, this message translates to:
  /// **'Join shared note: {code}'**
  String joinSharedNote(String code);

  /// Security notice for E2E encrypted sharing
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted: only you and your collaborators can read this note.'**
  String get e2eSharingNotice;

  /// Instruction text for sharing invite code
  ///
  /// In en, this message translates to:
  /// **'Share this invite code with others to let them collaborate:'**
  String get anyoneWithCode;

  /// Instruction on how to share the invite code securely
  ///
  /// In en, this message translates to:
  /// **'Share the code securely (e.g., via encrypted messaging app) to maintain end-to-end encryption.'**
  String get shareSecurely;

  /// Presence text when only current user is in room
  ///
  /// In en, this message translates to:
  /// **'No one else is viewing'**
  String get nooneInRoom;

  /// Presence text when one other person is viewing
  ///
  /// In en, this message translates to:
  /// **'1 person viewing'**
  String get onePersonInRoom;

  /// Presence text when multiple people are viewing
  ///
  /// In en, this message translates to:
  /// **'{count} people viewing'**
  String multiplePeopleInRoom(int count);

  /// Title of the properties dashboard screen
  ///
  /// In en, this message translates to:
  /// **'Properties Dashboard'**
  String get propertiesDashboard;

  /// Label for total notes count in dashboard
  ///
  /// In en, this message translates to:
  /// **'Total Notes'**
  String get totalNotes;

  /// Label for notes with properties percentage in dashboard
  ///
  /// In en, this message translates to:
  /// **'With Properties'**
  String get withProperties;

  /// Section title for priority distribution chart
  ///
  /// In en, this message translates to:
  /// **'Priority Distribution'**
  String get priorityDistribution;

  /// Empty state message when no notes have priority set
  ///
  /// In en, this message translates to:
  /// **'No priorities set'**
  String get noPrioritiesSet;

  /// Section title for kanban-style status columns
  ///
  /// In en, this message translates to:
  /// **'Notes by Status'**
  String get notesByStatus;

  /// Hint text for empty dashboard state
  ///
  /// In en, this message translates to:
  /// **'Create your first note to see the dashboard'**
  String get createFirstNoteHint;

  /// Title for the daily notes / journal screen
  ///
  /// In en, this message translates to:
  /// **'Daily Notes'**
  String get dailyNotes;

  /// Label for a single daily note
  ///
  /// In en, this message translates to:
  /// **'Daily Note'**
  String get dailyNote;

  /// Label for today's daily note
  ///
  /// In en, this message translates to:
  /// **'Today\'s Note'**
  String get todaysNote;

  /// Button to create a daily note for today
  ///
  /// In en, this message translates to:
  /// **'Create today\'s note'**
  String get createTodaysNote;

  /// Message when no daily note exists for a date
  ///
  /// In en, this message translates to:
  /// **'No note for this day'**
  String get noDailyNote;

  /// Button to open an existing daily note
  ///
  /// In en, this message translates to:
  /// **'Open daily note'**
  String get openDailyNote;

  /// Button to jump the calendar to today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get goToToday;

  /// Accessibility label for calendar dot indicator
  ///
  /// In en, this message translates to:
  /// **'Has note'**
  String get hasNote;

  /// Label for calendar navigation
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// Section header for recent daily notes list
  ///
  /// In en, this message translates to:
  /// **'Recent Daily Notes'**
  String get recentDailyNotes;

  /// Tooltip and title for the command palette feature
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get commandPalette;

  /// Placeholder text in the command palette search field
  ///
  /// In en, this message translates to:
  /// **'Type to search notes and commands...'**
  String get commandSearchHint;

  /// Section header for recently opened notes in command palette
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get commandRecentNotes;

  /// Section header for note results in command palette
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commandNotesSection;

  /// Section header for action results in command palette
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commandActions;

  /// Command palette action to create a new note
  ///
  /// In en, this message translates to:
  /// **'Create New Note'**
  String get commandCreateNewNote;

  /// Command palette action to open daily notes
  ///
  /// In en, this message translates to:
  /// **'Open Daily Notes'**
  String get commandOpenDailyNotes;

  /// Command palette action to open the knowledge graph
  ///
  /// In en, this message translates to:
  /// **'Open Graph View'**
  String get commandOpenGraph;

  /// Command palette action to open the properties dashboard
  ///
  /// In en, this message translates to:
  /// **'Open Dashboard'**
  String get commandOpenDashboard;

  /// Command palette action to open the trash screen
  ///
  /// In en, this message translates to:
  /// **'Open Trash'**
  String get commandOpenTrash;

  /// Command palette action to open the settings screen
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commandOpenSettings;

  /// Empty state when command palette search has no matches
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get commandNoResultsFound;

  /// Slash command: insert heading level 1
  ///
  /// In en, this message translates to:
  /// **'Heading 1'**
  String get slashHeading1;

  /// Slash command: insert heading level 2
  ///
  /// In en, this message translates to:
  /// **'Heading 2'**
  String get slashHeading2;

  /// Slash command: insert heading level 3
  ///
  /// In en, this message translates to:
  /// **'Heading 3'**
  String get slashHeading3;

  /// Slash command: insert bullet list
  ///
  /// In en, this message translates to:
  /// **'Bullet List'**
  String get slashBulletList;

  /// Slash command: insert numbered list
  ///
  /// In en, this message translates to:
  /// **'Numbered List'**
  String get slashNumberedList;

  /// Slash command: insert to-do / checklist
  ///
  /// In en, this message translates to:
  /// **'To-do List'**
  String get slashTodoList;

  /// Slash command: insert code block
  ///
  /// In en, this message translates to:
  /// **'Code Block'**
  String get slashCodeBlock;

  /// Slash command: insert blockquote
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get slashQuote;

  /// Slash command: insert horizontal divider
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get slashDivider;

  /// Slash command: insert table
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get slashTable;

  /// Slash command: insert image
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get slashImage;

  /// Slash command: insert wiki-style [[link]]
  ///
  /// In en, this message translates to:
  /// **'Wiki Link'**
  String get slashWikilink;

  /// Slash command: insert note transclusion ![[note]]
  ///
  /// In en, this message translates to:
  /// **'Transclusion'**
  String get slashTransclusion;

  /// Slash command: insert callout block
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get slashCallout;

  /// Empty state when slash command filter has no matches
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get slashNoResults;

  /// Button tooltip to activate side-by-side note editing
  ///
  /// In en, this message translates to:
  /// **'Split View'**
  String get splitView;

  /// Menu item or action to open a note in the secondary split pane
  ///
  /// In en, this message translates to:
  /// **'Open in Split View'**
  String get openInSplitView;

  /// Tooltip for closing the secondary pane in split view
  ///
  /// In en, this message translates to:
  /// **'Close Split View'**
  String get closeSplitView;

  /// Title of the note picker sheet for split view
  ///
  /// In en, this message translates to:
  /// **'Select note for split view'**
  String get selectNoteForSplit;

  /// Section header for search operator hints
  ///
  /// In en, this message translates to:
  /// **'Search operators'**
  String get searchOperators;

  /// Search operator hint for tag filter
  ///
  /// In en, this message translates to:
  /// **'tag:name -- Filter by tag'**
  String get searchOperatorTag;

  /// Search operator hint for status filter
  ///
  /// In en, this message translates to:
  /// **'status:todo|in-progress|done|blocked|cancelled'**
  String get searchOperatorStatus;

  /// Search operator hint for priority filter
  ///
  /// In en, this message translates to:
  /// **'priority:high|medium|low'**
  String get searchOperatorPriority;

  /// Search operator hint for date filter
  ///
  /// In en, this message translates to:
  /// **'date:YYYY-MM-DD -- Filter by date'**
  String get searchOperatorDate;

  /// Search operator hint for collection filter
  ///
  /// In en, this message translates to:
  /// **'collection:name -- Filter by collection'**
  String get searchOperatorCollection;

  /// Search operator hint for links filter
  ///
  /// In en, this message translates to:
  /// **'links:true|false -- Filter by link status'**
  String get searchOperatorLinks;

  /// Example query showing combined search operators
  ///
  /// In en, this message translates to:
  /// **'Example: tag:work status:todo project plan'**
  String get searchOperatorsExample;

  /// Tab and section header for saved searches
  ///
  /// In en, this message translates to:
  /// **'Saved Searches'**
  String get savedSearches;

  /// Button label and dialog title for saving a search
  ///
  /// In en, this message translates to:
  /// **'Save Search'**
  String get saveSearch;

  /// Label for the search name input field
  ///
  /// In en, this message translates to:
  /// **'Search name'**
  String get saveSearchName;

  /// Snackbar confirmation after saving a search
  ///
  /// In en, this message translates to:
  /// **'Search saved'**
  String get searchSaved;

  /// Tooltip and confirmation dialog title for deleting a saved search
  ///
  /// In en, this message translates to:
  /// **'Delete saved search'**
  String get deleteSavedSearch;

  /// Confirmation body for deleting a saved search
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteSavedSearchConfirm(String name);

  /// Section header for search history
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get searchHistory;

  /// Button to clear all search history
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// Empty state title for saved searches
  ///
  /// In en, this message translates to:
  /// **'No saved searches yet'**
  String get noSavedSearches;

  /// Empty state subtitle for saved searches
  ///
  /// In en, this message translates to:
  /// **'Search for something, then tap the bookmark icon to save it'**
  String get saveSearchHint;

  /// Empty state title for search history
  ///
  /// In en, this message translates to:
  /// **'No search history'**
  String get noSearchHistory;

  /// Button to expand search operator hints
  ///
  /// In en, this message translates to:
  /// **'Show search hints'**
  String get showSearchHints;

  /// Button to collapse search operator hints
  ///
  /// In en, this message translates to:
  /// **'Hide search hints'**
  String get hideSearchHints;

  /// Placeholder hint in the operator search field
  ///
  /// In en, this message translates to:
  /// **'Search with operators: tag:work status:todo ...'**
  String get searchNotesHint;

  /// Empty state subtitle for operator search
  ///
  /// In en, this message translates to:
  /// **'Enter a query with operators to find notes'**
  String get enterQueryOrOperators;

  /// Title for the image gallery viewer screen
  ///
  /// In en, this message translates to:
  /// **'Image Gallery'**
  String get imageGallery;

  /// Option to pick an image from the photo gallery
  ///
  /// In en, this message translates to:
  /// **'From Gallery'**
  String get fromGallery;

  /// Option to capture an image with the camera
  ///
  /// In en, this message translates to:
  /// **'From Camera'**
  String get fromCamera;

  /// Title of the bottom sheet for choosing image source
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// Tooltip for the paste image from clipboard button
  ///
  /// In en, this message translates to:
  /// **'Paste Image'**
  String get pasteImage;

  /// Button or dialog title to delete an image
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get deleteImage;

  /// Confirmation message when deleting an image
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this image?'**
  String get deleteImageConfirm;

  /// Title of the image management settings screen
  ///
  /// In en, this message translates to:
  /// **'Image Management'**
  String get imageManagement;

  /// Label for total image storage used
  ///
  /// In en, this message translates to:
  /// **'Total Storage'**
  String get totalStorage;

  /// Label showing the number of stored images
  ///
  /// In en, this message translates to:
  /// **'{count} image{count, plural, =1{} other{s}}'**
  String imageCount(int count);

  /// Label for images whose note has been deleted
  ///
  /// In en, this message translates to:
  /// **'Orphaned Images'**
  String get orphanedImages;

  /// Button to delete orphaned images
  ///
  /// In en, this message translates to:
  /// **'Clean up orphaned images'**
  String get cleanupOrphaned;

  /// Snackbar after cleaning up orphaned images
  ///
  /// In en, this message translates to:
  /// **'Cleaned up {count} orphaned image{count, plural, =1{} other{s}}'**
  String cleanupComplete(int count);

  /// Button to delete all stored images
  ///
  /// In en, this message translates to:
  /// **'Delete all images'**
  String get deleteAllImages;

  /// Confirmation message when deleting all images
  ///
  /// In en, this message translates to:
  /// **'This will delete all stored images. This cannot be undone.'**
  String get deleteAllImagesConfirm;

  /// Empty state when no images are stored
  ///
  /// In en, this message translates to:
  /// **'No images stored'**
  String get noImagesStored;

  /// Snackbar after an image is deleted
  ///
  /// In en, this message translates to:
  /// **'Image deleted'**
  String get imageDeleted;

  /// Tooltip/button to share an image
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get shareImage;

  /// Button to compare two note versions
  ///
  /// In en, this message translates to:
  /// **'Compare Versions'**
  String get compareVersions;

  /// Title of version diff screen
  ///
  /// In en, this message translates to:
  /// **'Version Diff'**
  String get versionDiff;

  /// Summary stat showing how many lines were added
  ///
  /// In en, this message translates to:
  /// **'{count} lines added'**
  String linesAdded(int count);

  /// Summary stat showing how many lines were removed
  ///
  /// In en, this message translates to:
  /// **'{count} lines removed'**
  String linesRemoved(int count);

  /// Hint shown when fewer than two versions are selected for comparison
  ///
  /// In en, this message translates to:
  /// **'Select two versions to compare'**
  String get selectTwoVersions;

  /// Label shown when two versions are identical
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// Label for a specific version number
  ///
  /// In en, this message translates to:
  /// **'Version {number}'**
  String versionNumber(int number);

  /// Estimated reading time display
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String readingTime(int minutes);

  /// Reading time when under 1 minute
  ///
  /// In en, this message translates to:
  /// **'Less than 1 min read'**
  String get lessThan1Min;

  /// Line count display
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 lines} =1{1 line} other{{count} lines}}'**
  String lineCount(int count);

  /// Paragraph count display
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 paragraphs} =1{1 paragraph} other{{count} paragraphs}}'**
  String paragraphCount(int count);

  /// Toggle for focus/dim mode in the editor
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get focusMode;

  /// Toggle for typewriter-style scrolling in the editor
  ///
  /// In en, this message translates to:
  /// **'Typewriter Scroll'**
  String get typewriterScroll;

  /// Label for the writing statistics bar
  ///
  /// In en, this message translates to:
  /// **'Writing Stats'**
  String get writingStats;

  /// Tooltip for the writing stats visibility toggle
  ///
  /// In en, this message translates to:
  /// **'Toggle writing stats'**
  String get toggleWritingStats;

  /// Character count without spaces
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 chars (no spaces)} =1{1 char (no spaces)} other{{count} chars (no spaces)}}'**
  String charCountNoSpaces(int count);

  /// Title of the statistics screen
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Label for total word count
  ///
  /// In en, this message translates to:
  /// **'Total Words'**
  String get totalWords;

  /// Label for average words per note
  ///
  /// In en, this message translates to:
  /// **'Avg Words/Note'**
  String get averageWords;

  /// Label for number of active days
  ///
  /// In en, this message translates to:
  /// **'Days Active'**
  String get daysActive;

  /// Subtitle for the 30-day activity period
  ///
  /// In en, this message translates to:
  /// **'last 30 days'**
  String get last30Days;

  /// Title for the writing streak card
  ///
  /// In en, this message translates to:
  /// **'Writing Streak'**
  String get writingStreak;

  /// Current writing streak in days
  ///
  /// In en, this message translates to:
  /// **'Current: {count} days'**
  String currentStreak(int count);

  /// Longest writing streak in days
  ///
  /// In en, this message translates to:
  /// **'Longest: {count} days'**
  String longestStreak(int count);

  /// Title for the monthly activity chart
  ///
  /// In en, this message translates to:
  /// **'Monthly Activity'**
  String get monthlyActivity;

  /// Title for the top tags section
  ///
  /// In en, this message translates to:
  /// **'Top Tags'**
  String get topTags;

  /// Title for the top collections section
  ///
  /// In en, this message translates to:
  /// **'Top Collections'**
  String get topCollections;

  /// Title for the status distribution chart
  ///
  /// In en, this message translates to:
  /// **'Status Distribution'**
  String get statusDistribution;

  /// Title for the knowledge graph statistics section
  ///
  /// In en, this message translates to:
  /// **'Knowledge Graph'**
  String get knowledgeGraphStats;

  /// Label for total link count
  ///
  /// In en, this message translates to:
  /// **'Total Links'**
  String get totalLinks;

  /// Label for orphaned note count
  ///
  /// In en, this message translates to:
  /// **'{count} orphaned notes'**
  String orphanedNotesCount(int count);

  /// Label for the most connected note
  ///
  /// In en, this message translates to:
  /// **'Most Connected'**
  String get mostConnectedNote;

  /// Empty state when no statistics are available
  ///
  /// In en, this message translates to:
  /// **'No statistics yet'**
  String get noStatistics;

  /// Label for count of notes that have properties
  ///
  /// In en, this message translates to:
  /// **'Notes with properties'**
  String get notesWithProperties;

  /// Label for count of notes that have links
  ///
  /// In en, this message translates to:
  /// **'Notes with links'**
  String get notesWithLinks;

  /// Title for export bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Export Notes'**
  String get exportNotes;

  /// Loading message during export
  ///
  /// In en, this message translates to:
  /// **'Exporting notes...'**
  String get exportingNotes;

  /// Snackbar after successful export
  ///
  /// In en, this message translates to:
  /// **'Export complete'**
  String get exportComplete;

  /// Button to export selected notes
  ///
  /// In en, this message translates to:
  /// **'Export Selected'**
  String get exportSelectedNotes;

  /// Button to export the current note
  ///
  /// In en, this message translates to:
  /// **'Export Current Note'**
  String get exportCurrentNote;

  /// Label indicating number of selected notes for export
  ///
  /// In en, this message translates to:
  /// **'{count} selected notes'**
  String exportSelected(int count);

  /// Menu option to export with YAML frontmatter
  ///
  /// In en, this message translates to:
  /// **'Export with metadata'**
  String get exportWithFrontmatter;

  /// Menu option to export as ZIP
  ///
  /// In en, this message translates to:
  /// **'Export as ZIP archive'**
  String get exportAsZip;

  /// Toggle for YAML frontmatter in export
  ///
  /// In en, this message translates to:
  /// **'Include metadata (frontmatter)'**
  String get includeFrontmatter;

  /// Description of frontmatter option
  ///
  /// In en, this message translates to:
  /// **'Add YAML metadata header with tags, dates, and properties'**
  String get frontmatterDesc;

  /// Label for export organization option
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get exportOrganization;

  /// Flat file organization
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get exportFlat;

  /// Organize exported files by date
  ///
  /// In en, this message translates to:
  /// **'By Date'**
  String get exportByDate;

  /// Organize exported files by collection
  ///
  /// In en, this message translates to:
  /// **'By Collection'**
  String get exportByCollection;

  /// Organize exported files by tag
  ///
  /// In en, this message translates to:
  /// **'By Tag'**
  String get exportByTag;

  /// Snackbar message after export
  ///
  /// In en, this message translates to:
  /// **'{count} notes exported'**
  String notesExported(int count);

  /// Button to import from .md files
  ///
  /// In en, this message translates to:
  /// **'Import from Markdown'**
  String get importFromMarkdown;

  /// Button to import from a ZIP archive
  ///
  /// In en, this message translates to:
  /// **'Import from ZIP'**
  String get importFromZip;

  /// Button to import from an Obsidian vault folder
  ///
  /// In en, this message translates to:
  /// **'Import from Obsidian Vault'**
  String get importFromObsidian;

  /// Progress message during note import
  ///
  /// In en, this message translates to:
  /// **'Importing notes...'**
  String get importingNotes;

  /// Message showing how many notes were imported
  ///
  /// In en, this message translates to:
  /// **'{count} notes imported'**
  String notesImported(int count);

  /// Toggle to keep dates from frontmatter
  ///
  /// In en, this message translates to:
  /// **'Preserve original dates'**
  String get preserveDates;

  /// Toggle to import tags from frontmatter
  ///
  /// In en, this message translates to:
  /// **'Import tags'**
  String get importTags;

  /// Toggle to import properties from frontmatter
  ///
  /// In en, this message translates to:
  /// **'Import properties'**
  String get importProperties;

  /// Message when no files were selected for import
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get noFilesSelected;

  /// Header for import options section
  ///
  /// In en, this message translates to:
  /// **'Import Options'**
  String get importOptions;

  /// Title for quick capture screen
  ///
  /// In en, this message translates to:
  /// **'Quick Capture'**
  String get quickCapture;

  /// Hint text in quick capture input
  ///
  /// In en, this message translates to:
  /// **'Type something...'**
  String get typeSomething;

  /// Indicator that note was auto-saved
  ///
  /// In en, this message translates to:
  /// **'Auto-saved'**
  String get autoSaved;

  /// Confirmation to discard draft
  ///
  /// In en, this message translates to:
  /// **'Discard draft?'**
  String get discardDraft;

  /// Body of discard confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Your unsaved changes will be lost.'**
  String get discardDraftMessage;

  /// Button to discard changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Quick action shortcut for new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNoteShortcut;

  /// Quick action shortcut for new checklist
  ///
  /// In en, this message translates to:
  /// **'New Checklist'**
  String get newChecklistShortcut;

  /// Quick action shortcut for daily note
  ///
  /// In en, this message translates to:
  /// **'Daily Note'**
  String get dailyNoteShortcut;

  /// Confirmation when content is shared to app
  ///
  /// In en, this message translates to:
  /// **'Shared to AnyNote'**
  String get sharedToAnynote;

  /// Tooltip for priority selector in quick capture
  ///
  /// In en, this message translates to:
  /// **'Set Priority'**
  String get setPriority;

  /// Description for quick capture action
  ///
  /// In en, this message translates to:
  /// **'Quickly capture a thought'**
  String get quickCaptureDesc;

  /// Label showing pending sync count
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingSync(int count);

  /// Label showing failed sync count
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String syncFailedCount(int count);

  /// Title for sync queue sheet
  ///
  /// In en, this message translates to:
  /// **'Sync Queue'**
  String get syncQueue;

  /// Label for pending sync operations
  ///
  /// In en, this message translates to:
  /// **'Pending Operations'**
  String get pendingOperations;

  /// Label for failed sync operations
  ///
  /// In en, this message translates to:
  /// **'Failed Operations'**
  String get failedOperations;

  /// Button to retry all failed operations
  ///
  /// In en, this message translates to:
  /// **'Retry All'**
  String get retryAll;

  /// Button to clear completed operations
  ///
  /// In en, this message translates to:
  /// **'Clear Completed'**
  String get clearCompleted;

  /// Error message for failed operation
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String operationFailed(String error);

  /// Loading text during sync retry
  ///
  /// In en, this message translates to:
  /// **'Retrying sync...'**
  String get retryingSync;

  /// Snackbar after clearing completed ops
  ///
  /// In en, this message translates to:
  /// **'Completed operations cleared'**
  String get queueCleared;

  /// Empty state when no sync operations pending
  ///
  /// In en, this message translates to:
  /// **'No pending operations'**
  String get noPendingOperations;

  /// Screen reader label for a note card
  ///
  /// In en, this message translates to:
  /// **'Note: {title}'**
  String noteSemantics(String title);

  /// Screen reader label for deleting a note via swipe
  ///
  /// In en, this message translates to:
  /// **'Delete note {title}'**
  String deleteNoteSemantics(String title);

  /// Screen reader label for archiving a note via swipe
  ///
  /// In en, this message translates to:
  /// **'Archive note {title}'**
  String archiveNoteSemantics(String title);

  /// Screen reader label for pinning a note via swipe
  ///
  /// In en, this message translates to:
  /// **'Pin note {title}'**
  String pinNoteSemantics(String title);

  /// Screen reader label for unpinning a note via swipe
  ///
  /// In en, this message translates to:
  /// **'Unpin note {title}'**
  String unpinNoteSemantics(String title);

  /// Screen reader hint for the note editor area
  ///
  /// In en, this message translates to:
  /// **'Note content editor. Double-tap to edit.'**
  String get noteContentEditor;

  /// Screen reader summary of the knowledge graph
  ///
  /// In en, this message translates to:
  /// **'{nodeCount} notes with {linkCount} links'**
  String graphSummary(int nodeCount, int linkCount);

  /// Screen reader label indicating a note is pinned
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedNote;

  /// Screen reader label for a settings section group
  ///
  /// In en, this message translates to:
  /// **'{section} settings'**
  String settingsGroup(String section);

  /// Screen reader label for restoring a trashed note
  ///
  /// In en, this message translates to:
  /// **'Restore note {title}'**
  String restoreNoteSemantics(String title);

  /// Screen reader label for permanent delete swipe action
  ///
  /// In en, this message translates to:
  /// **'Permanently delete note {title}'**
  String permanentlyDeleteNoteSemantics(String title);

  /// Screen reader label for deleting a collection via swipe
  ///
  /// In en, this message translates to:
  /// **'Delete collection {title}'**
  String deleteCollectionSemantics(String title);

  /// Screen reader label for a calendar day cell
  ///
  /// In en, this message translates to:
  /// **'{date}. {hasNote}'**
  String calendarDaySemantics(String date, String hasNote);

  /// Screen reader label for note count in a collection
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String noteCountSemantics(int count);

  /// Label for a single reminder
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// Button and sheet title for setting a reminder
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get setReminder;

  /// Label for the date/time of a reminder
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderAt;

  /// Button to remove an existing reminder
  ///
  /// In en, this message translates to:
  /// **'Remove Reminder'**
  String get removeReminder;

  /// Preset option: remind in 2 hours
  ///
  /// In en, this message translates to:
  /// **'Later Today'**
  String get laterToday;

  /// Preset option: remind at 9am tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow Morning'**
  String get tomorrowMorning;

  /// Preset option: remind next Monday at 9am
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get nextWeek;

  /// Empty state when there are no reminders
  ///
  /// In en, this message translates to:
  /// **'No Reminders'**
  String get noReminders;

  /// Label for recurring reminder selector
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// Recurring option: repeat every day
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// Recurring option: repeat every week
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// Recurring option: repeat every month
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// Title for the reminders list screen
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// Snackbar message when a reminder fires
  ///
  /// In en, this message translates to:
  /// **'Reminder Fired'**
  String get reminderFired;

  /// Generic label for color
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// Title of the color picker sheet
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// Button to remove the current color
  ///
  /// In en, this message translates to:
  /// **'Remove Color'**
  String get removeColor;

  /// Label for the note color setting
  ///
  /// In en, this message translates to:
  /// **'Note Color'**
  String get noteColor;

  /// Toggle label for entering a custom hex color
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// Label for the color filter in search
  ///
  /// In en, this message translates to:
  /// **'Color Filter'**
  String get colorFilter;

  /// Search operator hint for color filter
  ///
  /// In en, this message translates to:
  /// **'color:#RRGGBB or color:name -- Filter by color'**
  String get searchOperatorColor;

  /// Option label for no selection / no recurrence
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// Button label to compare two notes
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compareNotes;

  /// Title of the note compare picker sheet
  ///
  /// In en, this message translates to:
  /// **'Select Notes to Compare'**
  String get selectNotesToCompare;

  /// Segmented button label for unified diff view
  ///
  /// In en, this message translates to:
  /// **'Unified'**
  String get unifiedView;

  /// Segmented button label for side-by-side diff view
  ///
  /// In en, this message translates to:
  /// **'Side-by-side'**
  String get sideBySideView;

  /// Label for added lines in diff
  ///
  /// In en, this message translates to:
  /// **'Additions'**
  String get additions;

  /// Label for removed lines in diff
  ///
  /// In en, this message translates to:
  /// **'Deletions'**
  String get deletions;

  /// Hint when fewer or more than 2 notes are selected for comparison
  ///
  /// In en, this message translates to:
  /// **'Select exactly 2 notes to compare'**
  String get selectTwoNotes;

  /// Title of the note comparison diff screen
  ///
  /// In en, this message translates to:
  /// **'Note Diff'**
  String get noteDiff;

  /// Summary stat for diff between two notes
  ///
  /// In en, this message translates to:
  /// **'{added} lines added, {removed} lines removed'**
  String linesChanged(int added, int removed);

  /// Label for a mermaid diagram code block
  ///
  /// In en, this message translates to:
  /// **'Mermaid Diagram'**
  String get mermaidDiagram;

  /// Button label to view/copy a mermaid diagram
  ///
  /// In en, this message translates to:
  /// **'View Diagram'**
  String get viewDiagram;

  /// Tooltip for copying mermaid diagram source code
  ///
  /// In en, this message translates to:
  /// **'Copy Mermaid Code'**
  String get copyMermaidCode;

  /// Snackbar after copying mermaid diagram code
  ///
  /// In en, this message translates to:
  /// **'Diagram code copied'**
  String get diagramCopied;

  /// Label for the mermaid diagram template inserted via slash command
  ///
  /// In en, this message translates to:
  /// **'Mermaid Template'**
  String get mermaidTemplate;

  /// Generic label for inserting a diagram
  ///
  /// In en, this message translates to:
  /// **'Insert Diagram'**
  String get insertDiagram;

  /// Slash command: insert mermaid diagram block
  ///
  /// In en, this message translates to:
  /// **'Mermaid Diagram'**
  String get slashMermaid;

  /// Button label to toggle mermaid diagram source code view
  ///
  /// In en, this message translates to:
  /// **'View Source'**
  String get viewSource;

  /// Error message when mermaid diagram rendering fails
  ///
  /// In en, this message translates to:
  /// **'Failed to render diagram'**
  String get diagramError;

  /// Tooltip for copying the mermaid diagram source code
  ///
  /// In en, this message translates to:
  /// **'Copy Diagram Source'**
  String get copyDiagramSource;

  /// Menu item to lock a note (make it read-only)
  ///
  /// In en, this message translates to:
  /// **'Lock Note'**
  String get lockNote;

  /// Menu item to unlock a note (allow editing)
  ///
  /// In en, this message translates to:
  /// **'Unlock Note'**
  String get unlockNote;

  /// Label shown when a note is in locked (read-only) state
  ///
  /// In en, this message translates to:
  /// **'Note Locked'**
  String get noteLocked;

  /// Banner message shown at top of a locked note
  ///
  /// In en, this message translates to:
  /// **'This note is locked. Tap to unlock.'**
  String get lockedNoteBanner;

  /// Snackbar confirmation after batch coloring notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} colored'**
  String notesColored(int count);

  /// Snackbar confirmation after removing color from notes
  ///
  /// In en, this message translates to:
  /// **'Color removed from {count} note{count, plural, =1{} other{s}}'**
  String colorRemovedFromNotes(int count);

  /// Batch action to set color on selected notes
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get batchColor;

  /// Batch action to lock selected notes
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get batchLock;

  /// Batch action to unlock selected notes
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get batchUnlock;

  /// Snackbar confirmation after batch locking notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} locked'**
  String notesLocked(int count);

  /// Snackbar confirmation after batch unlocking notes
  ///
  /// In en, this message translates to:
  /// **'{count} note{count, plural, =1{} other{s}} unlocked'**
  String notesUnlocked(int count);

  /// Title for collection picker sheet
  ///
  /// In en, this message translates to:
  /// **'Move to Collection'**
  String get moveToCollection;

  /// Search hint in collection picker
  ///
  /// In en, this message translates to:
  /// **'Search collections...'**
  String get searchCollections;

  /// Empty state in collection picker
  ///
  /// In en, this message translates to:
  /// **'No collections found'**
  String get noCollections;

  /// Snackbar confirmation after moving notes
  ///
  /// In en, this message translates to:
  /// **'{count} notes moved to \"{name}\"'**
  String notesMovedToCollection(int count, String name);

  /// Snackbar confirmation after moving a single note
  ///
  /// In en, this message translates to:
  /// **'Note moved to \"{name}\"'**
  String noteMovedToCollection(String name);

  /// Context menu item and batch action label
  ///
  /// In en, this message translates to:
  /// **'Add to Collection'**
  String get addToCollection;

  /// Tooltip for the scroll-to-top FAB on the notes list
  ///
  /// In en, this message translates to:
  /// **'Scroll to top'**
  String get scrollToTop;

  /// Menu item and sheet title for printing a note
  ///
  /// In en, this message translates to:
  /// **'Print note'**
  String get printNote;

  /// Header for the print preview bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printPreview;

  /// Toggle label to include tags, dates, etc. in the printed output
  ///
  /// In en, this message translates to:
  /// **'Include metadata'**
  String get includeMetadata;

  /// Toggle label to include images in the printed output
  ///
  /// In en, this message translates to:
  /// **'Include images'**
  String get includeImages;

  /// Button label to share the note as an HTML file
  ///
  /// In en, this message translates to:
  /// **'Share as HTML'**
  String get shareAsHtml;

  /// Snackbar message after HTML export completes
  ///
  /// In en, this message translates to:
  /// **'Exported as HTML'**
  String get exportedAsHtml;

  /// Tooltip and label for the fold/outline view toggle in the editor
  ///
  /// In en, this message translates to:
  /// **'Fold View'**
  String get foldView;

  /// Button label to collapse all heading sections
  ///
  /// In en, this message translates to:
  /// **'Fold All'**
  String get foldAll;

  /// Button label to expand all heading sections
  ///
  /// In en, this message translates to:
  /// **'Unfold All'**
  String get unfoldAll;

  /// Label showing how many content lines are hidden under a folded heading
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String sectionLines(int count);

  /// Label showing the number of currently folded sections
  ///
  /// In en, this message translates to:
  /// **'{count} folded section{count, plural, =1{} other{s}}'**
  String foldedSections(int count);

  /// Tooltip for the fold/unfold chevron icon on a heading
  ///
  /// In en, this message translates to:
  /// **'Toggle fold'**
  String get toggleFold;

  /// Title for the TOC bottom sheet and its AppBar button tooltip
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// Empty state message when a note has no headings for the TOC
  ///
  /// In en, this message translates to:
  /// **'No headings found'**
  String get noHeadings;

  /// Accessibility label describing the heading level in the TOC
  ///
  /// In en, this message translates to:
  /// **'Heading level {level}'**
  String headingLevel(int level);

  /// Button to start text-to-speech reading of the note
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get readAloud;

  /// Button to stop TTS playback
  ///
  /// In en, this message translates to:
  /// **'Stop Reading'**
  String get stopReading;

  /// Button to pause TTS playback
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseReading;

  /// Button to resume TTS playback
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeReading;

  /// Tooltip for the speed selector in the TTS player bar
  ///
  /// In en, this message translates to:
  /// **'Reading Speed'**
  String get readingSpeed;

  /// Title for the keyboard shortcuts settings screen
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// Category label for general keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Category label for editor keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// Category label for navigation keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// Keyboard shortcut description for bold text
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get shortcutBold;

  /// Keyboard shortcut description for italic text
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get shortcutItalic;

  /// Keyboard shortcut description for strikethrough text
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get shortcutStrikethrough;

  /// Keyboard shortcut description for undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get shortcutUndo;

  /// Keyboard shortcut description for redo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get shortcutRedo;

  /// Keyboard shortcut description for printing the current note
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get shortcutPrint;

  /// Keyboard shortcut description for inserting a link
  ///
  /// In en, this message translates to:
  /// **'Insert Link'**
  String get shortcutLink;

  /// Keyboard shortcut description for toggling inline code
  ///
  /// In en, this message translates to:
  /// **'Inline Code'**
  String get shortcutCode;

  /// Keyboard shortcut description for cycling heading levels
  ///
  /// In en, this message translates to:
  /// **'Toggle Heading'**
  String get shortcutHeading;

  /// Keyboard shortcut description for opening command palette
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get shortcutCommandPalette;

  /// Keyboard shortcut description for toggling focus mode
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get shortcutFocusMode;

  /// Default title for reminder local notifications
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderNotificationTitle;

  /// Body text for reminder local notifications
  ///
  /// In en, this message translates to:
  /// **'Time to review: {title}'**
  String reminderNotificationBody(String title);

  /// Android notification channel name for reminder notifications
  ///
  /// In en, this message translates to:
  /// **'Note Reminders'**
  String get notificationChannelName;

  /// Android notification channel description for reminder notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications for note reminders'**
  String get notificationChannelDescription;

  /// Label for PDF export format
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get exportPdf;

  /// Button label to generate a PDF from note content
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get generatePdf;

  /// Snackbar confirmation that PDF was generated
  ///
  /// In en, this message translates to:
  /// **'PDF generated'**
  String get pdfGenerated;

  /// Button label to share a generated PDF
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get sharePdf;

  /// Format option label for PDF in export sheet
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get exportFormatPdf;

  /// Title for the code snippets screen
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get snippets;

  /// Label for snippet title field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get snippetTitle;

  /// Label for snippet code field
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get snippetCode;

  /// Label for snippet language dropdown
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get snippetLanguage;

  /// Label for snippet description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get snippetDescription;

  /// Label for snippet category field
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get snippetCategory;

  /// Label for snippet tags field
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get snippetTags;

  /// Button to create a new snippet
  ///
  /// In en, this message translates to:
  /// **'New Snippet'**
  String get newSnippet;

  /// Button to edit an existing snippet
  ///
  /// In en, this message translates to:
  /// **'Edit Snippet'**
  String get editSnippet;

  /// Button to delete a snippet
  ///
  /// In en, this message translates to:
  /// **'Delete Snippet'**
  String get deleteSnippet;

  /// Confirmation message for deleting a snippet
  ///
  /// In en, this message translates to:
  /// **'Delete this snippet?'**
  String get deleteSnippetConfirm;

  /// Button to copy snippet code to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// Snackbar after copying code to clipboard
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// Slash command and title for snippet picker sheet
  ///
  /// In en, this message translates to:
  /// **'Insert Snippet'**
  String get insertSnippet;

  /// Empty state when no code snippets exist
  ///
  /// In en, this message translates to:
  /// **'No snippets yet'**
  String get noSnippets;

  /// Placeholder in snippet search field
  ///
  /// In en, this message translates to:
  /// **'Search snippets...'**
  String get searchSnippets;

  /// Label showing how many times a snippet has been used
  ///
  /// In en, this message translates to:
  /// **'Used {count} time{count, plural, =1{} other{s}}'**
  String usageCount(int count);

  /// Dropdown hint for no language filter
  ///
  /// In en, this message translates to:
  /// **'All Languages'**
  String get allLanguages;

  /// Dropdown hint for no category filter
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// Title for the tag hierarchy / tree view feature
  ///
  /// In en, this message translates to:
  /// **'Tag Hierarchy'**
  String get tagHierarchy;

  /// Context menu option to create a child tag under a parent
  ///
  /// In en, this message translates to:
  /// **'Create Sub-tag'**
  String get createSubTag;

  /// Context menu option to change a tag's parent
  ///
  /// In en, this message translates to:
  /// **'Move to Parent'**
  String get moveToParent;

  /// Option to set a tag as root-level (no parent)
  ///
  /// In en, this message translates to:
  /// **'No Parent (Root)'**
  String get noParent;

  /// Title of the parent tag picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Select Parent Tag'**
  String get selectParentTag;

  /// Button to expand all collapsible tag tree nodes
  ///
  /// In en, this message translates to:
  /// **'Expand All'**
  String get expandAll;

  /// Button to collapse all tag tree nodes
  ///
  /// In en, this message translates to:
  /// **'Collapse All'**
  String get collapseAll;

  /// Tooltip shown over a remote collaborator's cursor
  ///
  /// In en, this message translates to:
  /// **'{name}\'s cursor'**
  String userCursor(String name);

  /// Fallback label when remote user name is unknown
  ///
  /// In en, this message translates to:
  /// **'Remote user'**
  String get remoteUser;

  /// Hint shown when dragging an image over the editor
  ///
  /// In en, this message translates to:
  /// **'Drop image here'**
  String get dropImageHere;

  /// Snackbar confirmation after an image is added via drag-and-drop
  ///
  /// In en, this message translates to:
  /// **'Image added'**
  String get imageAdded;

  /// Snackbar message when a non-image file is dropped on the editor
  ///
  /// In en, this message translates to:
  /// **'Only image files are supported'**
  String get unsupportedFileType;

  /// Home screen quick action: create a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get quickNote;

  /// Home screen quick action: create a new checklist
  ///
  /// In en, this message translates to:
  /// **'New Checklist'**
  String get quickChecklist;

  /// Home screen quick action: open today's daily note
  ///
  /// In en, this message translates to:
  /// **'Daily Note'**
  String get quickDailyNote;

  /// Tooltip for overflow menu button in app bar
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// Error message when trash notes fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load trash'**
  String get failedToLoadTrash;

  /// Snackbar error when restoring a note from trash fails
  ///
  /// In en, this message translates to:
  /// **'Failed to restore: {error}'**
  String failedToRestoreError(String error);

  /// Snackbar error when permanently deleting a note fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDeleteError(String error);

  /// Dialog title for deleting a custom property
  ///
  /// In en, this message translates to:
  /// **'Delete Property'**
  String get deleteProperty;

  /// Confirmation message when deleting a property
  ///
  /// In en, this message translates to:
  /// **'Remove this property from the note?'**
  String get removePropertyConfirm;

  /// Header title in the properties bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get propertiesTitle;

  /// Empty state when no properties exist on a note
  ///
  /// In en, this message translates to:
  /// **'No properties'**
  String get noProperties;

  /// Subtitle encouraging users to add properties
  ///
  /// In en, this message translates to:
  /// **'Add custom metadata to this note'**
  String get addCustomMetadata;

  /// Button label to add a new property
  ///
  /// In en, this message translates to:
  /// **'Add Property'**
  String get addPropertyButton;

  /// Dialog title for editing an existing property
  ///
  /// In en, this message translates to:
  /// **'Edit Property'**
  String get editProperty;

  /// Dialog title for creating a custom property
  ///
  /// In en, this message translates to:
  /// **'Custom Property'**
  String get customPropertyTitle;

  /// Label for the property key selector section
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get propertyLabel;

  /// Form field label for a text property value
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueLabel;

  /// Form field label for a number property value
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberLabel;

  /// Validation error when property value is empty
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get enterValue;

  /// Validation error when number property is empty
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterNumber;

  /// Placeholder text for date property picker
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectDateLabel;

  /// Header title for the link management bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Link Management'**
  String get linkManagementTitle;

  /// Filter chip label for outbound links
  ///
  /// In en, this message translates to:
  /// **'Outbound Links'**
  String get outboundLinks;

  /// Dialog title for confirming link deletion
  ///
  /// In en, this message translates to:
  /// **'Delete Link'**
  String get deleteLinkTitle;

  /// Confirmation message when deleting a link
  ///
  /// In en, this message translates to:
  /// **'Remove this connection between notes?'**
  String get removeLinkConfirm;

  /// Empty state when no links match the current filters
  ///
  /// In en, this message translates to:
  /// **'No links to display. Adjust filters to see more.'**
  String get noLinksToDisplay;

  /// Subtitle for a backlink item
  ///
  /// In en, this message translates to:
  /// **'Links to this note'**
  String get linksToThisNote;

  /// Subtitle for an outbound link item
  ///
  /// In en, this message translates to:
  /// **'This note links to'**
  String get thisNoteLinksTo;

  /// Tooltip for the delete button on a link tile
  ///
  /// In en, this message translates to:
  /// **'Delete link'**
  String get deleteLinkTooltip;

  /// Title of the table picker dialog
  ///
  /// In en, this message translates to:
  /// **'Insert Table'**
  String get insertTable;

  /// Hint text in the table picker dialog
  ///
  /// In en, this message translates to:
  /// **'Drag to select table size'**
  String get dragToSelectTableSize;

  /// Pro plan name in upgrade dialog and comparison table
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proPlan;

  /// Lifetime plan name in upgrade dialog and comparison table
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetimePlan;

  /// Price display for the Pro plan
  ///
  /// In en, this message translates to:
  /// **'\$4.99/mo'**
  String get proPrice;

  /// Price display for the Lifetime plan
  ///
  /// In en, this message translates to:
  /// **'\$49.99'**
  String get lifetimePrice;

  /// High priority label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// Medium priority label
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// Low priority label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// Label showing the number of selected tags
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tagsCountLabel(int count);

  /// Tooltip for orphaned notes button
  ///
  /// In en, this message translates to:
  /// **'Orphaned notes'**
  String get orphanedNotes;

  /// Filter chip label when no filters are active
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Filter chip label for active priority filter
  ///
  /// In en, this message translates to:
  /// **'Priority: {priority}'**
  String priorityLabel(String priority);

  /// Empty state when property filters yield no results
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noMatchingNotes;

  /// Empty state subtitle when property filters yield no results
  ///
  /// In en, this message translates to:
  /// **'Try changing your filters'**
  String get tryChangingFilters;

  /// Title of the property filter bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Filter by Properties'**
  String get filterByProperties;

  /// Priority section header in filter sheet
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// Tooltip for the properties button in editor
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get viewProperties;

  /// Semantics label for the note title text field
  ///
  /// In en, this message translates to:
  /// **'Note title'**
  String get noteTitle;

  /// Label for the date property type section
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// Display text showing the name of an existing property
  ///
  /// In en, this message translates to:
  /// **'Property: {name}'**
  String propertyOf(String name);

  /// Insert button label in table picker dialog
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertLabel;

  /// SnackBar message when loading more discover feed items fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more: {error}'**
  String failedToLoadMore(String error);

  /// SnackBar confirmation after a note link is created
  ///
  /// In en, this message translates to:
  /// **'Link created'**
  String get linkCreated;

  /// SnackBar error when creating a note link fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create link: {error}'**
  String failedToCreateLink(String error);

  /// Title of the link suggestions bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Suggested Links'**
  String get suggestedLinks;

  /// Info banner text in the link suggestions sheet
  ///
  /// In en, this message translates to:
  /// **'Notes with similar titles or content. Tap to create a link.'**
  String get similarContentDesc;

  /// Empty state title when there are no link suggestions
  ///
  /// In en, this message translates to:
  /// **'No Suggestions'**
  String get noSuggestions;

  /// Empty state subtitle when there are no link suggestions
  ///
  /// In en, this message translates to:
  /// **'Create more notes to get suggestions.'**
  String get createMoreNotes;

  /// SnackBar message when a native-only feature is used on web
  ///
  /// In en, this message translates to:
  /// **'This feature is not available on web'**
  String get notAvailableOnWeb;

  /// OK button label in dialogs
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// Error message when a deferred screen fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoadDeferred;

  /// Generic error title in error cards
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Title of the sync status bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatusTitle;

  /// Label indicating device is offline in sync status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// Label indicating device is connected in sync status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedLabel;

  /// Label for pending sync operations count
  ///
  /// In en, this message translates to:
  /// **'Pending operations'**
  String get pendingOpsLabel;

  /// Label for last sync timestamp
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get lastSyncedLabel;

  /// Section header for failed sync items
  ///
  /// In en, this message translates to:
  /// **'Failed items'**
  String get failedItemsLabel;

  /// Tooltip for sync icon when device is offline
  ///
  /// In en, this message translates to:
  /// **'Offline -- changes will sync when connected'**
  String get offlineSyncTooltip;

  /// Label for sync pull phase
  ///
  /// In en, this message translates to:
  /// **'Pulling'**
  String get pullingLabel;

  /// Label for sync push phase
  ///
  /// In en, this message translates to:
  /// **'Pushing'**
  String get pushingLabel;

  /// Tooltip when sync is in progress
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncingLabel;

  /// Tooltip when all changes are synced
  ///
  /// In en, this message translates to:
  /// **'All changes synced'**
  String get allChangesSyncedLabel;

  /// Tooltip for pending sync operations count (singular/plural handled by ICU if needed)
  ///
  /// In en, this message translates to:
  /// **'{count} pending operation'**
  String pendingOpTooltip(int count);

  /// Tooltip for pending sync operations count (plural)
  ///
  /// In en, this message translates to:
  /// **'{count} pending operations'**
  String pendingOpsTooltip(int count);

  /// Tooltip for sync badge when there is a conflict
  ///
  /// In en, this message translates to:
  /// **'Sync conflict'**
  String get syncConflictBadge;

  /// Short label for sync badge conflict state
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get conflictLabel;

  /// Short label for sync badge synced state
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedLabel;

  /// Short label for sync badge pending state
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingSyncLabel;

  /// Tooltip for sync badge when sync is pending
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSyncBadge;

  /// Screen reader label for the monthly activity bar chart
  ///
  /// In en, this message translates to:
  /// **'Bar chart showing notes by month: {entries}'**
  String barChartSemanticLabel(String entries);

  /// Screen reader label for the priority distribution donut chart
  ///
  /// In en, this message translates to:
  /// **'Donut chart showing distribution: {entries}'**
  String donutChartSemanticLabel(String entries);

  /// Screen reader label for a tag item in the tags list
  ///
  /// In en, this message translates to:
  /// **'Tag: {name}'**
  String tagItemSemanticLabel(String name);

  /// Screen reader hint for long-pressing a tag item to open its edit menu
  ///
  /// In en, this message translates to:
  /// **'Long press to edit'**
  String get tagItemSemanticHint;
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

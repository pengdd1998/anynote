// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AnyNote';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get signInToVault => 'Sign in to your encrypted vault';

  @override
  String get email => 'Email';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signIn => 'Sign In';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get recoverFromBackup => 'Recover from backup';

  @override
  String get noEncryptionKeys =>
      'No encryption keys found. Please register first.';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password.';

  @override
  String get accountNotFoundRegister =>
      'Account not found. Please register first.';

  @override
  String get unableToReachServer =>
      'Unable to reach the server. Please check your connection.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get startEncryptedJourney => 'Start your encrypted note journey';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get encryptionNotice =>
      'Your data will be encrypted with this password. We cannot recover it if lost.';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get emailOrUsernameTaken => 'Email or username already taken.';

  @override
  String get invalidInput => 'Invalid input. Please check your details.';

  @override
  String get saveRecoveryKey => 'Save Your Recovery Key';

  @override
  String get recoveryKeyInstructions =>
      'Store this recovery key in a safe place. You will need it to recover your data if you forget your password.';

  @override
  String get copyRecoveryKey => 'Copy recovery key';

  @override
  String get recoveryKeyCopied => 'Recovery key copied to clipboard';

  @override
  String get iSavedIt => 'I\'ve Saved It';

  @override
  String get recoverAccount => 'Recover Account';

  @override
  String get recoverAccountInstructions =>
      'Enter your 12-word recovery key to restore your encrypted vault on this device.';

  @override
  String get recoveryKeyLabel => 'Recovery Key (12 words)';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get recoveryKeyRequired => 'Recovery key is required';

  @override
  String get recoveryKeyWordCount => 'Recovery key must be exactly 12 words';

  @override
  String get recoveryKeyFormatHint =>
      'Enter all 12 words separated by spaces, in the correct order.';

  @override
  String get invalidRecoveryKey =>
      'Invalid recovery key. Please check your words and try again.';

  @override
  String get invalidRecoveryKeyForAccount =>
      'Invalid recovery key for this account.';

  @override
  String get accountNotFoundCheckEmail =>
      'Account not found. Please check your email.';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboardingPrivacyTitle => 'Your Notes, Your Privacy';

  @override
  String get onboardingPrivacyDesc =>
      'AnyNote encrypts every note on your device before it reaches the cloud. No one -- not even us -- can read your notes.';

  @override
  String get onboardingMasterPasswordTitle => 'Master Password';

  @override
  String get onboardingMasterPasswordDesc =>
      'Set a master password that derives your encryption key. Remember it -- there is no password reset without your recovery key.';

  @override
  String get onboardingRecoveryKeyTitle => 'Recovery Key';

  @override
  String get onboardingRecoveryKeyDesc =>
      'You will receive a 12-word recovery key. Store it safely -- it is the only way to recover your notes if you forget your password.';

  @override
  String get onboardingAITitle => 'AI-Powered Composing';

  @override
  String get onboardingAIDesc =>
      'Use AI to compose, outline, and adapt your notes for any platform. Your content is never logged.';

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get collections => 'Collections';

  @override
  String get sortNotes => 'Sort notes';

  @override
  String get updatedNewest => 'Updated (newest)';

  @override
  String get updatedOldest => 'Updated (oldest)';

  @override
  String get createdNewest => 'Created (newest)';

  @override
  String get createdOldest => 'Created (oldest)';

  @override
  String get titleAZ => 'Title A-Z';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get advancedSearch => 'Advanced search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchNotesTooltip => 'Search notes';

  @override
  String get createNewNote => 'Create new note';

  @override
  String get noNotesYet => 'No notes yet';

  @override
  String get tapToCapture => 'Tap + to capture your first note';

  @override
  String get newNote => 'New Note';

  @override
  String get noResults => 'No results';

  @override
  String get tryDifferentSearch => 'Try a different search term';

  @override
  String get deleteNoteQuestion => 'Delete note?';

  @override
  String deleteNoteConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get undo => 'Undo';

  @override
  String get unpinNote => 'Unpin note';

  @override
  String get pinNote => 'Pin note';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get blankNote => 'Blank Note';

  @override
  String get fromTemplate => 'From Template';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get untitled => 'Untitled';

  @override
  String get versionHistory => 'Version History';

  @override
  String get editNote => 'Edit note';

  @override
  String get exportOrShare => 'Export or share';

  @override
  String get shareViaLink => 'Share via link';

  @override
  String get exportAsMarkdown => 'Export as Markdown';

  @override
  String get exportAsHTML => 'Export as HTML';

  @override
  String get exportAsPlainText => 'Export as Plain Text';

  @override
  String get failedToLoadNote => 'Failed to load note';

  @override
  String get retry => 'Retry';

  @override
  String get noteNotFound => 'Note not found';

  @override
  String get notSynced => 'Not synced';

  @override
  String get couldNotLoadForExport => 'Could not load note for export';

  @override
  String get deleteNoteDialog => 'Delete Note';

  @override
  String get deleteNoteDialogMessage =>
      'This note will be moved to trash. You can restore it later.';

  @override
  String get title => 'Title';

  @override
  String get startWriting => 'Start writing...';

  @override
  String get saveAndClose => 'Save and close';

  @override
  String get savingNote => 'Saving note';

  @override
  String get plainText => 'Plain text';

  @override
  String get richText => 'Rich text';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

  @override
  String get manageTags => 'Manage tags';

  @override
  String get addImage => 'Add image';

  @override
  String get noteContent => 'Note content';

  @override
  String get tags => 'Tags';

  @override
  String get closeTagPicker => 'Close tag picker';

  @override
  String get newTagName => 'New tag name';

  @override
  String get add => 'Add';

  @override
  String get noTagsYet => 'No tags yet. Create one above.';

  @override
  String failedToAddImage(String error) {
    return 'Failed to add image: $error';
  }

  @override
  String get restore => 'Restore';

  @override
  String get close => 'Close';

  @override
  String get restoreVersion => 'Restore Version';

  @override
  String restoreVersionConfirm(int version) {
    return 'Replace the current note content with version $version? A snapshot of the current content will be saved first.';
  }

  @override
  String get versionRestored => 'Version restored';

  @override
  String failedToRestore(String error) {
    return 'Failed to restore: $error';
  }

  @override
  String get failedToLoadVersions => 'Failed to load versions';

  @override
  String get noVersionsYet => 'No versions yet';

  @override
  String get versionsSavedAutomatically =>
      'Versions are saved automatically when you edit a note.';

  @override
  String get current => 'Current';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get plan => 'Plan';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get loading => 'Loading...';

  @override
  String get unableToLoadAccountInfo => 'Unable to load account info';

  @override
  String get aiSection => 'AI';

  @override
  String get llmConfiguration => 'LLM Configuration';

  @override
  String get configureAIProviders => 'Configure your AI providers';

  @override
  String get aiQuota => 'AI Quota';

  @override
  String requestsToday(int used, int limit) {
    return '$used/$limit requests today';
  }

  @override
  String get unableToLoadQuota => 'Unable to load quota';

  @override
  String get publishing => 'Publishing';

  @override
  String get platformConnections => 'Platform Connections';

  @override
  String get manageConnectedPlatforms => 'Manage connected platforms';

  @override
  String get securityPrivacy => 'Security & Privacy';

  @override
  String get encryptionSettings => 'Encryption Settings';

  @override
  String get e2eEncryptionActive => 'E2E encryption active';

  @override
  String get sync => 'Sync';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get lastSyncedNever => 'Last synced: Never';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get checking => 'Checking...';

  @override
  String get unableToLoadSyncStatus => 'Unable to load sync status';

  @override
  String get syncNow => 'Sync Now';

  @override
  String syncCompleteWithConflicts(int count) {
    return 'Sync complete with $count conflicts';
  }

  @override
  String synced(int pulled, int pushed) {
    return 'Synced: $pulled pulled, $pushed pushed';
  }

  @override
  String get data => 'Data';

  @override
  String get exportAllNotes => 'Export All Notes';

  @override
  String get exportAllNotesDesc => 'Export all notes to a file';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get htmlFormat => 'HTML (.html)';

  @override
  String get plainTextFormat => 'Plain Text (.txt)';

  @override
  String get noNotesToExport => 'No notes to export';

  @override
  String get noNotesWithContent => 'No notes with content to export';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessage =>
      'Are you sure you want to sign out? You will need to log in again to access your notes.';

  @override
  String signOutFailed(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String get securityEncryption => 'Security & Encryption';

  @override
  String get e2eEncryptionActiveStatus => 'E2E Encryption Active';

  @override
  String get encryptionNotSetUp => 'Encryption Not Set Up';

  @override
  String get encryptionAlgorithm =>
      'Your data is encrypted with XChaCha20-Poly1305';

  @override
  String get keyDerivation => 'Key derivation: Argon2id';

  @override
  String get masterKeyUnlocked => 'Master key: unlocked';

  @override
  String get masterKeyLocked => 'Master key: locked';

  @override
  String get encryptedItems => 'Encrypted Items';

  @override
  String get notes => 'Notes';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get collectionsLabel => 'Collections';

  @override
  String get aiContent => 'AI Content';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get recoveryKeySection => 'Recovery Key';

  @override
  String get recoveryKeyUsage =>
      'Use this key to recover your data if you forget your password.';

  @override
  String get viewRecoveryKey => 'View Recovery Key';

  @override
  String get noRecoveryKeyStored => 'No recovery key stored.';

  @override
  String get recoveryKeyWarning =>
      'The recovery key was generated during registration. If you did not save it, you cannot recover your data without your password.';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String get hide => 'Hide';

  @override
  String get failedToLoadRecoveryKey => 'Failed to load recovery key';

  @override
  String get changePassword => 'Change Password';

  @override
  String get reEncryptsData => 'Re-encrypts all data with new key';

  @override
  String get verifyPassword => 'Verify Password';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get verify => 'Verify';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get reEncryptWarning => 'Warning: This will re-encrypt all your data.';

  @override
  String get change => 'Change';

  @override
  String get currentPasswordIncorrect => 'Current password is incorrect';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully';

  @override
  String failedToChangePassword(String error) {
    return 'Failed to change password: $error';
  }

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get deleteAllLocalData => 'Delete All Local Data';

  @override
  String get exportEncryptedBackup => 'Export Encrypted Backup';

  @override
  String get importEncryptedBackup => 'Import Encrypted Backup';

  @override
  String get deleteAllDataQuestion => 'Delete All Data?';

  @override
  String get deleteAllDataMessage =>
      'This action is irreversible. All your notes, tags, and settings will be permanently deleted.';

  @override
  String get deleteEverything => 'Delete Everything';

  @override
  String get areYouAbsolutelySure => 'Are you absolutely sure?';

  @override
  String get typeDeleteToConfirm => 'Type DELETE to confirm.';

  @override
  String get typeDelete => 'Type DELETE';

  @override
  String get allLocalDataDeleted => 'All local data has been deleted';

  @override
  String failedToDeleteData(String error) {
    return 'Failed to delete data: $error';
  }

  @override
  String get importBackup => 'Import Backup';

  @override
  String get importBackupMessage =>
      'This will import items from the backup file. Existing items will not be overwritten. Continue?';

  @override
  String get import => 'Import';

  @override
  String importedItemsFromBackup(int count) {
    return 'Imported $count items from backup';
  }

  @override
  String backupExportFailed(String error) {
    return 'Backup export failed: $error';
  }

  @override
  String backupImportFailed(String error) {
    return 'Backup import failed: $error';
  }

  @override
  String get llmConfigTitle => 'LLM Configuration';

  @override
  String get noLLMConfigs => 'No LLM configurations';

  @override
  String get addLLMToEnableAI => 'Add an LLM to enable AI features';

  @override
  String get addProvider => 'Add Provider';

  @override
  String get defaultLabel => 'Default';

  @override
  String get testConnection => 'Test connection';

  @override
  String get failedToLoadConfigs => 'Failed to load configs';

  @override
  String get addLLMProvider => 'Add LLM Provider';

  @override
  String get name => 'Name';

  @override
  String get provider => 'Provider';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => 'Model';

  @override
  String get modelHint => 'e.g., gpt-4o';

  @override
  String get save => 'Save';

  @override
  String get editLLMProvider => 'Edit LLM Provider';

  @override
  String get newApiKeyHint => 'New API Key (leave blank to keep current)';

  @override
  String get testingConnection => 'Testing connection...';

  @override
  String get connectionSuccessful => 'Connection successful';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String deleteConfigQuestion(String name) {
    return 'Delete $name?';
  }

  @override
  String get removeLLMConfigConfirm =>
      'Are you sure you want to remove this LLM configuration?';

  @override
  String get noPlatformsAvailable => 'No platforms available';

  @override
  String get platformConnectionsWillAppear =>
      'Platform connections will appear here';

  @override
  String get failedToLoadPlatforms => 'Failed to load platforms';

  @override
  String get connect => 'Connect';

  @override
  String get verifyButton => 'Verify';

  @override
  String get disconnect => 'Disconnect';

  @override
  String connectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String failedToConnect(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String get verifyingConnection => 'Verifying connection...';

  @override
  String get connectionVerified => 'Connection verified';

  @override
  String connectionInvalid(String error) {
    return 'Connection invalid: $error';
  }

  @override
  String verificationFailedError(String error) {
    return 'Verification failed: $error';
  }

  @override
  String disconnectPlatform(String name) {
    return 'Disconnect $name';
  }

  @override
  String disconnectPlatformConfirm(String name) {
    return 'Are you sure you want to disconnect your $name account?';
  }

  @override
  String disconnectedFrom(String name) {
    return 'Disconnected from $name';
  }

  @override
  String failedToDisconnect(String error) {
    return 'Failed to disconnect: $error';
  }

  @override
  String get scanQRCode => 'Scan QR Code';

  @override
  String scanQRInstructions(String platform) {
    return 'Open $platform app and scan this QR code to login';
  }

  @override
  String get done => 'Done';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get noTags => 'No tags';

  @override
  String get createTagsToOrganize => 'Create tags to organize your notes';

  @override
  String get newTag => 'New Tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagNameHint => 'e.g., ideas, work, personal';

  @override
  String get create => 'Create';

  @override
  String get encrypted => '(encrypted)';

  @override
  String get aiCompose => 'AI Compose';

  @override
  String get aiPoweredWriting => 'AI-Powered Writing';

  @override
  String get aiComposeDesc =>
      'Select your notes and let AI help you create polished content for any platform.';

  @override
  String get startComposing => 'Start Composing';

  @override
  String get recentCompositions => 'Recent Compositions';

  @override
  String get noCompositionsYet => 'No compositions yet';

  @override
  String get newComposition => 'New Composition';

  @override
  String get topicOrTheme => 'Topic or theme';

  @override
  String get topicHint => 'What should the composition be about?';

  @override
  String get targetPlatform => 'Target platform';

  @override
  String get selectNotes => 'Select Notes';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get noNotesAvailableCreate =>
      'No notes available. Create a note first.';

  @override
  String get contentPreview => 'Content Preview';

  @override
  String get noContent => '(No content)';

  @override
  String get copy => 'Copy';

  @override
  String get saveAsNote => 'Save as Note';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get savedAsNote => 'Saved as note';

  @override
  String get publish => 'Publish';

  @override
  String get connectedPlatforms => 'Connected Platforms';

  @override
  String get noPlatformsConnected => 'No platforms connected';

  @override
  String get connectAPlatform => 'Connect a Platform';

  @override
  String get publishContent => 'Publish Content';

  @override
  String get content => 'Content';

  @override
  String get tagsCommaSeparated => 'Tags (comma separated)';

  @override
  String get tagsHint => 'tag1, tag2, tag3';

  @override
  String get selectPlatformToPublish => 'Select a platform above to publish';

  @override
  String publishedStatus(String status) {
    return 'Published! Status: $status';
  }

  @override
  String get titleAndContentRequired => 'Title and content are required';

  @override
  String get publishRequestSubmitted => 'Publish request submitted';

  @override
  String get recentPublications => 'Recent Publications';

  @override
  String get noPublicationsYet => 'No publications yet';

  @override
  String viewAll(int count) {
    return 'View All ($count)';
  }

  @override
  String get publishHistory => 'Publish History';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get all => 'All';

  @override
  String get published => 'Published';

  @override
  String get failed => 'Failed';

  @override
  String get publishingStatus => 'Publishing';

  @override
  String get pending => 'Pending';

  @override
  String noPublicationsWithStatus(String status) {
    return 'No $status publications';
  }

  @override
  String get clearFilter => 'Clear Filter';

  @override
  String get noPublications => 'No publications';

  @override
  String get publishedContentWillAppear => 'Published content will appear here';

  @override
  String get failedToLoadPublishHistory => 'Failed to load publish history';

  @override
  String get viewDetails => 'View Details';

  @override
  String get platform => 'Platform';

  @override
  String get status => 'Status';

  @override
  String get created => 'Created';

  @override
  String get publishedDate => 'Published';

  @override
  String get url => 'URL';

  @override
  String get error => 'Error';

  @override
  String get contentLabel => 'Content';

  @override
  String failedToLoadDetail(String error) {
    return 'Failed to load detail: $error';
  }

  @override
  String get collectionsTitle => 'Collections';

  @override
  String get noCollectionsYet => 'No collections yet';

  @override
  String get groupNotesIntoCollections => 'Group your notes into collections';

  @override
  String get newCollection => 'New Collection';

  @override
  String get deleteCollectionQuestion => 'Delete collection?';

  @override
  String deleteCollectionConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"? Notes in this collection will not be deleted.';
  }

  @override
  String get collectionDeleted => 'Collection deleted';

  @override
  String get untitledCollection => 'Untitled Collection';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: '0 notes',
    );
    return '$_temp0';
  }

  @override
  String get collectionTitle => 'Collection title';

  @override
  String get collectionTitleHint => 'Enter a name for this collection';

  @override
  String get collectionNotFound => 'Collection not found';

  @override
  String get failedToLoadCollection => 'Failed to load collection';

  @override
  String get noNotesInCollection => 'No notes in this collection';

  @override
  String get tapToAddNotes => 'Tap + to add notes';

  @override
  String get addNotes => 'Add Notes';

  @override
  String get removeFromCollection => 'Remove from collection?';

  @override
  String removeNoteConfirm(String title) {
    return 'Remove \"$title\" from this collection? The note will not be deleted.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get renameCollection => 'Rename Collection';

  @override
  String get renameCollectionTooltip => 'Rename collection';

  @override
  String get deleteCollectionTooltip => 'Delete collection';

  @override
  String get deleteCollectionDialogTitle => 'Delete Collection';

  @override
  String get deleteCollectionDialogMessage =>
      'This collection and all its note associations will be removed. Notes themselves will not be deleted.';

  @override
  String get noNotesAvailable => 'No notes available';

  @override
  String get removeFromCollectionTooltip => 'Remove from collection';

  @override
  String get search => 'Search';

  @override
  String get clearAllFilters => 'Clear all filters';

  @override
  String get searchYourNotes => 'Search your notes';

  @override
  String get enterQueryOrFilters =>
      'Enter a query or use filters to find notes';

  @override
  String get recentSearches => 'Recent Searches';

  @override
  String get clearAll => 'Clear all';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryAdjustingSearch => 'Try adjusting your search or filters';

  @override
  String searchError(String error) {
    return 'Search error: $error';
  }

  @override
  String get dateRange => 'Date Range';

  @override
  String get tagsFilter => 'Tags';

  @override
  String get collectionsFilter => 'Collections';

  @override
  String tagsCount(int count) {
    return '$count tags';
  }

  @override
  String collectionsCount(int count) {
    return '$count collections';
  }

  @override
  String resultsCount(String count) {
    return '$count results';
  }

  @override
  String get noTagsAvailable => 'No tags available';

  @override
  String get noCollectionsAvailable => 'No collections available';

  @override
  String get selectTags => 'Select tags';

  @override
  String get apply => 'Apply';

  @override
  String get selectCollections => 'Select collections';

  @override
  String get shareNote => 'Share Note';

  @override
  String get passwordProtection => 'Password Protection';

  @override
  String get requirePassword => 'Require password';

  @override
  String get requirePasswordDesc => 'Recipients must enter a password to view';

  @override
  String get expiresAfter => 'Expires After';

  @override
  String get oneHour => '1 hour';

  @override
  String get twentyFourHours => '24 hours';

  @override
  String get sevenDays => '7 days';

  @override
  String get never => 'Never';

  @override
  String get passwordRequiredForShare =>
      'Password is required when password protection is enabled';

  @override
  String failedToCreateShareLink(String error) {
    return 'Failed to create share link: $error';
  }

  @override
  String get linkCopiedToClipboard => 'Link copied to clipboard';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get passwordProtectedShareInfo =>
      'This link is password-protected. Share the password separately.';

  @override
  String get publicShareInfo => 'Anyone with this link can view the note.';

  @override
  String linkExpiresIn(String expiry) {
    return 'Link expires $expiry';
  }

  @override
  String get encrypting => 'Encrypting...';

  @override
  String get createShareLink => 'Create Share Link';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get languageChangedNotice =>
      'Language will take effect after restarting the app';

  @override
  String get zenMode => 'Zen mode';

  @override
  String get enterZenMode => 'Enter focus mode';

  @override
  String get exitZenMode => 'Exit focus mode';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
      zero: '0 words',
    );
    return '$_temp0';
  }

  @override
  String charCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
      zero: '0 characters',
    );
    return '$_temp0';
  }

  @override
  String get importNotes => 'Import Notes';

  @override
  String get importMarkdown => 'Import Markdown';

  @override
  String get importTextFiles => 'Import Text Files';

  @override
  String get importAppleNotes => 'Import Apple Notes';

  @override
  String importComplete(int count, int skipped) {
    return 'Import complete: $count notes imported, $skipped skipped';
  }

  @override
  String get markdownPreview => 'Markdown Preview';

  @override
  String get restoreFromBackup => 'Restore from Backup';

  @override
  String get selectBackupFile => 'Select Backup File';

  @override
  String get selectBackupFileDesc =>
      'Choose an AnyNote encrypted backup file (.enc) to restore your data.';

  @override
  String get browseFiles => 'Browse Files';

  @override
  String get selectedFile => 'Selected file';

  @override
  String get nextStep => 'Next';

  @override
  String get back => 'Back';

  @override
  String get backupDetails => 'Backup Details';

  @override
  String get backupFormat => 'Format';

  @override
  String get backupVersion => 'Version';

  @override
  String get exportDate => 'Export Date';

  @override
  String get totalItems => 'Total Items';

  @override
  String get itemCounts => 'Item Counts';

  @override
  String get verificationErrors => 'Verification Errors';

  @override
  String get backupValid => 'Backup Verified';

  @override
  String get backupInvalid => 'Backup Verification Failed';

  @override
  String get unlockToVerify => 'Unlock encryption to verify backup contents.';

  @override
  String get restorePreviewTitle => 'Restore Preview';

  @override
  String get notesToRestore => 'Notes';

  @override
  String get tagsToRestore => 'Tags';

  @override
  String get collectionsToRestore => 'Collections';

  @override
  String get contentsToRestore => 'AI Content';

  @override
  String get earliestDate => 'Earliest';

  @override
  String get latestDate => 'Latest';

  @override
  String get noConflictsDetected =>
      'No conflicts detected. All items will be added as new.';

  @override
  String get noteTitlesPreview => 'Note Titles';

  @override
  String andMoreItems(int count) {
    return '...and $count more';
  }

  @override
  String get conflictStrategyTitle => 'Conflict Resolution';

  @override
  String get conflictStrategyDesc =>
      'Choose how to handle items that already exist locally.';

  @override
  String get strategyOverwrite => 'Overwrite';

  @override
  String get strategyOverwriteDesc =>
      'Replace local items with backup versions';

  @override
  String get strategySkip => 'Skip';

  @override
  String get strategySkipDesc => 'Keep local items, skip backup duplicates';

  @override
  String get strategyKeepBoth => 'Keep Both';

  @override
  String get strategyKeepBothDesc =>
      'Import backup items alongside existing ones (with \'(restored)\' suffix)';

  @override
  String get restoreWarning =>
      'Restored items will be queued for sync. This may take a moment.';

  @override
  String get startRestore => 'Start Restore';

  @override
  String get restoringBackup => 'Restoring backup...';

  @override
  String restoreProgress(int current, int total) {
    return 'Processing $current of $total';
  }

  @override
  String get restoreCompleted => 'Restore completed successfully';

  @override
  String get restoreCompletedWithErrors => 'Restore completed with some errors';

  @override
  String get restoreResults => 'Results';

  @override
  String get itemsRestored => 'Restored';

  @override
  String get itemsSkipped => 'Skipped';

  @override
  String get conflictsFound => 'Conflicts';

  @override
  String get errorsDuringRestore => 'Errors';

  @override
  String conflictsDetected(int count) {
    return '$count item(s) already exist locally';
  }

  @override
  String existingNotesCount(int count) {
    return '$count notes';
  }

  @override
  String existingTagsCount(int count) {
    return '$count tags';
  }

  @override
  String existingCollectionsCount(int count) {
    return '$count collections';
  }

  @override
  String existingContentsCount(int count) {
    return '$count AI contents';
  }

  @override
  String filePickerError(String error) {
    return 'Failed to open file picker: $error';
  }

  @override
  String get restoreFromBackupDesc =>
      'Restore data from an encrypted backup file';

  @override
  String get importNotesDesc =>
      'Import from Markdown, Apple Notes, or plain text';

  @override
  String get onboardingWriteTitle => 'Write down your thoughts';

  @override
  String get onboardingWriteDesc =>
      'Create notes on any device -- your content will be securely encrypted';

  @override
  String get japanese => 'Japanese';

  @override
  String get korean => 'Korean';

  @override
  String get discoverFeed => 'Discover';

  @override
  String get noPublicNotes => 'No public notes yet';

  @override
  String get noPublicNotesDesc =>
      'Shared notes marked as public will appear here.';

  @override
  String get failedToLoadDiscoverFeed => 'Failed to load discovery feed';

  @override
  String get encryptedNote => 'Encrypted note';

  @override
  String get reactionFailed => 'Failed to react';

  @override
  String monthsAgo(int count) {
    return '${count}mo ago';
  }

  @override
  String get menuFile => 'File';

  @override
  String get menuNewNote => 'New Note';

  @override
  String get menuSave => 'Save';

  @override
  String get menuImport => 'Import...';

  @override
  String get menuExport => 'Export...';

  @override
  String get menuCloseTab => 'Close Tab';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuUndo => 'Undo';

  @override
  String get menuRedo => 'Redo';

  @override
  String get menuCut => 'Cut';

  @override
  String get menuCopy => 'Copy';

  @override
  String get menuPaste => 'Paste';

  @override
  String get menuSelectAll => 'Select All';

  @override
  String get menuFind => 'Find...';

  @override
  String get menuView => 'View';

  @override
  String get menuToggleSidebar => 'Toggle Sidebar';

  @override
  String get menuTogglePreview => 'Toggle Preview';

  @override
  String get menuZenMode => 'Zen Mode';

  @override
  String get menuFullScreen => 'Enter Full Screen';

  @override
  String get menuExitFullScreen => 'Exit Full Screen';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuAbout => 'About AnyNote';

  @override
  String get menuKeyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get aboutDialogTitle => 'About AnyNote';

  @override
  String get aboutDescription =>
      'Local-first, privacy-first note-taking with end-to-end encryption.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get shortcutsDialogTitle => 'Keyboard Shortcuts';

  @override
  String get shortcutNewNote => 'New Note';

  @override
  String get shortcutSave => 'Save';

  @override
  String get shortcutSearch => 'Search';

  @override
  String get shortcutToggleSidebar => 'Toggle Sidebar';

  @override
  String get shortcutExportPdf => 'Export to PDF';

  @override
  String get shortcutSettings => 'Open Settings';

  @override
  String get shortcutCloseNote => 'Close Note';

  @override
  String get shortcutNextNote => 'Next Note';

  @override
  String get shortcutFullScreen => 'Toggle Full Screen';

  @override
  String get shortcutExitZen => 'Exit Zen Mode / Close Dialog';

  @override
  String get notesTabLabel => 'Notes';

  @override
  String get composeTabLabel => 'Compose';

  @override
  String get publishTabLabel => 'Publish';

  @override
  String get settingsTabLabel => 'Settings';

  @override
  String versionSemanticLabel(
      int versionNumber, String title, String date, String currentSuffix) {
    return 'Version $versionNumber, $title, $date$currentSuffix';
  }

  @override
  String get currentSuffix => ', current';

  @override
  String noteTitleLabel(String title) {
    return 'Note title: $title';
  }

  @override
  String updatedDate(String date) {
    return 'Updated $date';
  }

  @override
  String get confirmDeleteNoteDialog => 'Confirm delete note dialog';

  @override
  String get expiryImmediately => 'immediately';

  @override
  String get expiryLessThanOneHour => 'in less than 1 hour';

  @override
  String expiryInHours(int count) {
    return 'in $count hours';
  }

  @override
  String expiryInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'in $count day$_temp0';
  }

  @override
  String compositionSemanticLabel(
      String title, String time, String platformSuffix) {
    return 'Composition: $title. $time$platformSuffix';
  }

  @override
  String platformSuffix(String platform) {
    return '. Platform: $platform';
  }

  @override
  String get platformGeneric => 'Generic';

  @override
  String get platformXhs => 'XHS';

  @override
  String get platformTwitter => 'Twitter';

  @override
  String get platformBlog => 'Blog';

  @override
  String get platformLinkedin => 'LinkedIn';

  @override
  String get noteClusters => 'Note Clusters';

  @override
  String get clusteringNotes => 'Clustering your notes...';

  @override
  String analyzingNotes(int count, String topic) {
    return 'AI is analyzing $count notes about \"$topic\"';
  }

  @override
  String foundThemesSelect(int count) {
    return 'AI found $count themes. Select the ones to include.';
  }

  @override
  String notesCount(int count) {
    return '$count notes';
  }

  @override
  String clustersSelected(int count) {
    return '$count clusters selected';
  }

  @override
  String get generateOutline => 'Generate Outline';

  @override
  String get editorTitle => 'Editor';

  @override
  String adaptStyleFor(String platform) {
    return 'Adapt style for $platform';
  }

  @override
  String get saveNoteTooltip => 'Save as note';

  @override
  String get aiWriting => 'AI is writing...';

  @override
  String charsCount(int count) {
    return '$count chars';
  }

  @override
  String get compositionHint => 'Your composition will appear here...';

  @override
  String get outlineButton => 'Outline';

  @override
  String wordsCount(int count) {
    return '$count words';
  }

  @override
  String get viewAction => 'View';

  @override
  String get failedToSaveNote => 'Failed to save note';

  @override
  String get outlineTitle => 'Outline';

  @override
  String get editTitleTooltip => 'Edit title';

  @override
  String get generatingOutline => 'Generating outline...';

  @override
  String buildingStructureFromClusters(int count) {
    return 'Building structure from $count clusters';
  }

  @override
  String get noOutlineGenerated => 'No outline generated.';

  @override
  String sectionsDragToReorder(int count) {
    return '$count sections -- drag to reorder';
  }

  @override
  String get keyPoints => 'Key Points:';

  @override
  String fromCluster(int number) {
    return 'From cluster $number';
  }

  @override
  String get expandToDraft => 'Expand to Draft';

  @override
  String get editTitle => 'Edit Title';

  @override
  String get loginScreenLabel => 'AnyNote login screen';

  @override
  String errorLabel(String message) {
    return 'Error: $message';
  }

  @override
  String get registrationScreenLabel => 'AnyNote registration screen';

  @override
  String get keyDerivationFailed => 'Key derivation failed. Please try again.';

  @override
  String get demoSecretNote => 'My secret note...';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get selectNoteToView => 'Select a note to view';

  @override
  String get collectionFallback => 'Collection';

  @override
  String get unknown => 'Unknown';

  @override
  String get freePlan => 'Free';

  @override
  String get importMarkdownDesc =>
      'Import Markdown (.md) files with optional YAML frontmatter. Supported frontmatter fields: title, date, and tags. Falls back to filename for the title if none is specified.';

  @override
  String get sourceHeader => 'Source';

  @override
  String get selectFiles => 'Select Files';

  @override
  String get selectMdFilesSubtitle => 'Choose one or more .md files';

  @override
  String get selectFolder => 'Select Folder';

  @override
  String get importMdFolderSubtitle => 'Import all .md files from a folder';

  @override
  String get selectMdFilesTitle => 'Select Markdown Files';

  @override
  String get noMdFilesSelected => 'No .md files selected.';

  @override
  String get notSupportedOnWeb => 'This feature is not supported on web.';

  @override
  String get selectMdFolderTitle => 'Select Folder with Markdown Files';

  @override
  String get appleNotesExportHeader => 'Apple Notes Export';

  @override
  String get appleNotesImportDesc =>
      'Import notes exported from the Apple Notes app. Select a folder containing HTML files exported from Apple Notes (one file per note). Basic formatting (bold, italic, headings, lists) will be converted to Markdown.';

  @override
  String get selectAppleNotesFolderSubtitle =>
      'Choose a folder with Apple Notes HTML files';

  @override
  String get selectAppleNotesFolderTitle => 'Select Apple Notes Export Folder';

  @override
  String get plainTextFilesHeader => 'Plain Text Files';

  @override
  String get plainTextImportDesc =>
      'Import plain text (.txt) files as notes. The first line of each file becomes the note title (if shorter than 100 characters); otherwise the filename is used as the title.';

  @override
  String get selectTxtFilesSubtitle => 'Choose one or more .txt files';

  @override
  String get importTxtFolderSubtitle => 'Import all .txt files from a folder';

  @override
  String get selectTextFilesTitle => 'Select Text Files';

  @override
  String get noTxtFilesSelected => 'No .txt files selected.';

  @override
  String get selectTextFolderTitle => 'Select Folder with Text Files';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count file$_temp0';
  }

  @override
  String andMoreErrors(int count) {
    return '... and $count more errors';
  }

  @override
  String get stepFile => 'File';

  @override
  String get stepVerify => 'Verify';

  @override
  String get stepPreview => 'Preview';

  @override
  String get stepStrategy => 'Strategy';

  @override
  String get stepRestore => 'Restore';

  @override
  String get decryptFailed =>
      'Failed to decrypt the shared note. The link may be corrupted or expired.';

  @override
  String get decryptingSharedNote => 'Decrypting shared note...';

  @override
  String get couldNotDecryptSharedNote => 'Could not decrypt the shared note';

  @override
  String get linkCorruptedExpired =>
      'The link may be corrupted, expired, or incomplete.';

  @override
  String get passwordRequiredTitle => 'Password Required';

  @override
  String get enterPasswordToView =>
      'Enter the password to view this shared note.';

  @override
  String get unlock => 'Unlock';

  @override
  String get sharedViaLink => 'Shared via link';

  @override
  String get sharedNote => 'Shared note';

  @override
  String platformSemanticLabel(
      String name, String subtitleSuffix, String selectedSuffix) {
    return 'Platform: $name$subtitleSuffix$selectedSuffix';
  }

  @override
  String publishedSemanticLabel(
      String title, String platform, String status, String dateSuffix) {
    return 'Published: $title. Platform: $platform. Status: $status$dateSuffix';
  }

  @override
  String get openInBrowser => 'Open published article in browser';

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String get selectedLabel => 'Selected';

  @override
  String dateRangeFormat(String start, String end) {
    return '$start - $end';
  }

  @override
  String get builtInTab => 'Built-in';

  @override
  String get myTemplatesTab => 'My Templates';

  @override
  String get deleteTemplateConfirm => 'Delete template?';

  @override
  String deleteTemplateMessage(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get templateNameLabel => 'Template name';

  @override
  String get templateDateHint => 'Use [date] for current date';

  @override
  String get offlineBanner =>
      'You are offline — changes will sync when connected';

  @override
  String get unlockRequired => 'Please unlock your vault first';

  @override
  String get selectAnItemToView => 'Select an item to view';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get comingSoonMessage =>
      'This feature is not yet available. Stay tuned for future updates!';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get errorConnection =>
      'Unable to connect to the server. Please check your internet connection.';

  @override
  String get errorServer => 'A server error occurred. Please try again later.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get errorAccessDenied =>
      'You do not have permission to perform this action.';

  @override
  String get errorNotFound => 'The requested item could not be found.';

  @override
  String get errorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String errorRateLimitedSeconds(int seconds) {
    return 'Too many requests. Please wait $seconds seconds and try again.';
  }

  @override
  String get errorConflict =>
      'A conflict was detected. Please refresh and try again.';

  @override
  String get errorCryptoLocked =>
      'Encryption keys are locked. Please unlock to continue.';

  @override
  String get errorKeyDerivation =>
      'Key derivation failed. Please check your password.';

  @override
  String get errorCryptoOperation =>
      'An encryption error occurred. Please try again.';

  @override
  String errorSync(String message) {
    return 'Sync failed: $message';
  }

  @override
  String get errorStorage =>
      'A local storage error occurred. Please restart the app.';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get errorTitleConnection => 'Connection Error';

  @override
  String get errorTitleServer => 'Server Error';

  @override
  String get errorTitleSessionExpired => 'Session Expired';

  @override
  String get errorTitleAccessDenied => 'Access Denied';

  @override
  String get errorTitleNotFound => 'Not Found';

  @override
  String get errorTitleRateLimited => 'Rate Limited';

  @override
  String get errorTitleInvalidInput => 'Invalid Input';

  @override
  String get errorTitleConflict => 'Conflict';

  @override
  String get errorTitleCryptoLocked => 'Encryption Locked';

  @override
  String get errorTitleKeyError => 'Key Error';

  @override
  String get errorTitleCrypto => 'Encryption Error';

  @override
  String get errorTitleSync => 'Sync Error';

  @override
  String get errorTitleStorage => 'Storage Error';

  @override
  String get termsOfServiceContent =>
      'Terms of Service are currently being drafted. For now, our Privacy Policy governs the use of AnyNote services.';

  @override
  String get kdfMigrationTitle => 'Security Upgrade Available';

  @override
  String get kdfMigrationMessage =>
      'Your encryption keys use older, weaker parameters. We recommend upgrading to stronger key derivation parameters for better security. This requires re-deriving your keys and will take a moment.';

  @override
  String get kdfMigrationUpgrade => 'Upgrade Now';

  @override
  String get kdfMigrationSkip => 'Skip for Now';

  @override
  String get kdfMigrationInProgress => 'Upgrading encryption parameters...';

  @override
  String get kdfMigrationSuccess =>
      'Encryption parameters upgraded successfully.';

  @override
  String get kdfMigrationFailed =>
      'Migration failed. You can continue, but your keys use older parameters.';

  @override
  String get crossPlatformWarningTitle => 'Cross-Platform Encryption Notice';

  @override
  String get crossPlatformWarningMessage =>
      'Notes encrypted on mobile (Android/iOS) cannot be decrypted on web, and vice versa. This is because mobile uses Argon2id while web uses PBKDF2 for key derivation, producing different encryption keys even with the same password.';

  @override
  String get aiChatAssistant => 'AI Chat Assistant';

  @override
  String get aiChatWelcome => 'Ask me anything about your notes';

  @override
  String get aiChatWelcomeDesc =>
      'Select notes as context for more relevant answers.';

  @override
  String get selectContextNotes => 'Select Context Notes';

  @override
  String contextNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 selected as context';
  }

  @override
  String get newChat => 'New Chat';

  @override
  String get typeYourMessage => 'Type your message...';

  @override
  String get smartSummary => 'Smart Summary';

  @override
  String get summaryPromptDesc =>
      'Generate a concise AI summary of your note content.';

  @override
  String get generateSummary => 'Generate Summary';

  @override
  String get replace => 'Replace';

  @override
  String get aiTagSuggestion => 'AI Tag Suggestion';

  @override
  String get suggestTags => 'Suggest';

  @override
  String get analyzingContent => 'Analyzing content...';

  @override
  String get tapSuggestTagsDesc =>
      'Tap \"Suggest\" to let AI analyze your note and recommend tags.';

  @override
  String get selectTagsToApply => 'Select the tags you want to apply:';

  @override
  String applyTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Apply $count tag$_temp0';
  }

  @override
  String get aiTranslation => 'AI Translation';

  @override
  String get translateTo => 'Translate to:';

  @override
  String get translate => 'Translate';

  @override
  String get translationWillAppear => 'Translation will appear here...';

  @override
  String get insertBelow => 'Insert Below';

  @override
  String get french => 'French';

  @override
  String get german => 'German';

  @override
  String get spanish => 'Spanish';

  @override
  String get writingPolish => 'Writing Polish';

  @override
  String get writingPolishDesc =>
      'Fix grammar, spelling, and improve readability with AI.';

  @override
  String get checkGrammar => 'Check';

  @override
  String get checkingGrammar => 'Checking grammar...';

  @override
  String get original => 'Original';

  @override
  String get corrected => 'Corrected';

  @override
  String get reject => 'Reject';

  @override
  String get acceptAll => 'Accept All';

  @override
  String get aiFeatures => 'AI Features';

  @override
  String get planTitle => 'Plan';

  @override
  String currentPlan(String plan) {
    return 'Current Plan: $plan';
  }

  @override
  String get planNotesCount => 'Notes';

  @override
  String get aiUsage => 'AI Usage';

  @override
  String get storageUsed => 'Storage';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get comparePlans => 'Compare Plans';

  @override
  String get maxNotes => 'Max Notes';

  @override
  String get aiDailyQuota => 'AI Daily Quota';

  @override
  String get storage => 'Storage';

  @override
  String get maxDevices => 'Max Devices';

  @override
  String get collaboration => 'Collaboration';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get restorePurchase => 'Restore Purchase';

  @override
  String get restorePurchaseComingSoon =>
      'Restore purchase will be available soon.';

  @override
  String get lifetimeMember =>
      'Lifetime Member -- all features unlocked forever.';

  @override
  String get selectPlan => 'Select a Plan';

  @override
  String get proPlanDescription =>
      'Unlimited notes, 500 AI requests/day, 5 GB storage';

  @override
  String get lifetimePlanDescription =>
      'All Pro features, forever -- one-time payment';

  @override
  String get unableToLoadPlan => 'Unable to load plan info.';

  @override
  String get profile => 'Profile';

  @override
  String get editPublicProfile => 'Edit display name and bio';

  @override
  String get profileTitle => 'Edit Profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get displayNameHint => 'How others see you';

  @override
  String get bio => 'Bio';

  @override
  String get bioHint => 'Tell others about yourself';

  @override
  String get publicProfile => 'Public Profile';

  @override
  String get publicProfileDesc => 'Allow others to find and view your profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileSaveFailed => 'Failed to save profile';

  @override
  String get unableToLoadProfile => 'Unable to load profile.';

  @override
  String get onboardingSecureNotesTitle => 'Secure Notes';

  @override
  String get onboardingSecureNotesDesc =>
      'Every note is encrypted end-to-end on your device before it reaches the cloud. No one -- not even us -- can read your notes.';

  @override
  String get onboardingPublishTitle => 'Publish Everywhere';

  @override
  String get onboardingPublishDesc =>
      'One-click publish to your favorite platforms. Share your ideas with the world instantly.';

  @override
  String get onboardingCollaborateTitle => 'Collaborate in Real-time';

  @override
  String get onboardingCollaborateDesc =>
      'Work together on notes with live updates. Changes sync instantly across all devices.';
}

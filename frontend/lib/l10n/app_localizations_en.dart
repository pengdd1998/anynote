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
  String get sortCustom => 'Custom Order';

  @override
  String get reorderModeHint => 'Drag notes to reorder';

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
  String get shareNote => 'Share this note';

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
  String get templates => 'Templates';

  @override
  String get templatePicker => 'Choose a Template';

  @override
  String get createFromTemplate => 'Create from Template';

  @override
  String get createFromScratch => 'Create from Scratch';

  @override
  String get templateManagement => 'Template Management';

  @override
  String get newTemplate => 'New Template';

  @override
  String get editTemplate => 'Edit Template';

  @override
  String get deleteTemplate => 'Delete Template';

  @override
  String get templateName => 'Template Name';

  @override
  String get templateDescription => 'Description';

  @override
  String get templateContent => 'Content';

  @override
  String get templateCategory => 'Category';

  @override
  String get categoryWork => 'Work';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryCreative => 'Creative';

  @override
  String get builtInTemplates => 'Built-in Templates';

  @override
  String get userTemplates => 'My Templates';

  @override
  String templateUsed(int count) {
    return 'Used $count times';
  }

  @override
  String get duplicateTemplate => 'Duplicate';

  @override
  String get noTemplates => 'No templates yet';

  @override
  String get templateSaved => 'Template saved';

  @override
  String get templateMeetingNotes => 'Meeting Notes';

  @override
  String get templateDailyJournal => 'Daily Journal';

  @override
  String get templateProjectPlan => 'Project Plan';

  @override
  String get templateReadingNotes => 'Reading Notes';

  @override
  String get templateWeeklyReview => 'Weekly Review';

  @override
  String get templateBrainstorm => 'Brainstorm';

  @override
  String get templateBlank => 'Blank';

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

  @override
  String get noteLinks => 'Note Links';

  @override
  String get backlinks => 'Backlinks';

  @override
  String get noBacklinks => 'No backlinks found';

  @override
  String get knowledgeGraph => 'Knowledge Graph';

  @override
  String get graphEmpty => 'No links to display';

  @override
  String get aiAgent => 'AI Agent';

  @override
  String get selectAction => 'Select an action';

  @override
  String get organizeNotes => 'Organize Notes';

  @override
  String get summarizeNotes => 'Summarize Notes';

  @override
  String get createNote => 'Create Note';

  @override
  String get agentFailed => 'Action failed';

  @override
  String get agentComplete => 'Action complete';

  @override
  String get viewBacklinks => 'View backlinks';

  @override
  String get wikiLink => 'Wiki Link';

  @override
  String get linkToNote => 'Link to Note';

  @override
  String get relatedNotes => 'Related Notes';

  @override
  String get noRelatedNotes => 'No related notes';

  @override
  String get startTypingToSearch => 'Start typing to search notes';

  @override
  String get noNotesFound => 'No notes found';

  @override
  String get backgroundSync => 'Background sync';

  @override
  String get backgroundSyncDesc =>
      'Sync notes periodically when the app is closed';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get trash => 'Trash';

  @override
  String get emptyTrash => 'Empty Trash';

  @override
  String get emptyTrashConfirm =>
      'Are you sure you want to permanently delete all notes in the trash? This action cannot be undone.';

  @override
  String get emptyTrashDone => 'Trash emptied';

  @override
  String get noDeletedNotes => 'No deleted notes';

  @override
  String get restoreNote => 'Restore';

  @override
  String get permanentlyDelete => 'Delete Forever';

  @override
  String deletedAt(String date) {
    return 'Deleted $date';
  }

  @override
  String deletedOn(String date) {
    return 'Deleted on $date';
  }

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get trashEmptyDesc => 'Notes you delete will appear here';

  @override
  String permanentlyDeleteNoteConfirm(String title) {
    return 'Permanently delete \"$title\"?';
  }

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get batchPin => 'Pin';

  @override
  String get batchUnpin => 'Unpin';

  @override
  String get batchDelete => 'Delete';

  @override
  String get batchAddTags => 'Add Tags';

  @override
  String selectedNotes(int count) {
    return '$count selected';
  }

  @override
  String deleteSelectedNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Delete $count note$_temp0?';
  }

  @override
  String get deleteSelectedNotesConfirm =>
      'Are you sure you want to delete the selected notes? They will be moved to trash.';

  @override
  String notesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 moved to trash';
  }

  @override
  String notesPinned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 pinned';
  }

  @override
  String notesUnpinned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 unpinned';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get themeHighContrastLight => 'High Contrast Light';

  @override
  String get themeHighContrastDark => 'High Contrast Dark';

  @override
  String get reduceMotion => 'Reduce Motion';

  @override
  String get reduceMotionDesc => 'Minimize animations throughout the app';

  @override
  String get reduceMotionSystem => 'Following system setting';

  @override
  String get reduceMotionOn => 'On (animations disabled)';

  @override
  String get reduceMotionOff => 'Off (animations enabled)';

  @override
  String get copyInviteCode => 'Copy Invite Code';

  @override
  String get inviteCodeCopied => 'Invite code copied!';

  @override
  String get enterInviteCode => 'Enter Invite Code';

  @override
  String joinSharedNote(String code) {
    return 'Join shared note: $code';
  }

  @override
  String get e2eSharingNotice =>
      'End-to-end encrypted: only you and your collaborators can read this note.';

  @override
  String get anyoneWithCode =>
      'Share this invite code with others to let them collaborate:';

  @override
  String get shareSecurely =>
      'Share the code securely (e.g., via encrypted messaging app) to maintain end-to-end encryption.';

  @override
  String get nooneInRoom => 'No one else is viewing';

  @override
  String get onePersonInRoom => '1 person viewing';

  @override
  String multiplePeopleInRoom(int count) {
    return '$count people viewing';
  }

  @override
  String get propertiesDashboard => 'Properties Dashboard';

  @override
  String get totalNotes => 'Total Notes';

  @override
  String get withProperties => 'With Properties';

  @override
  String get priorityDistribution => 'Priority Distribution';

  @override
  String get noPrioritiesSet => 'No priorities set';

  @override
  String get notesByStatus => 'Notes by Status';

  @override
  String get createFirstNoteHint =>
      'Create your first note to see the dashboard';

  @override
  String get dailyNotes => 'Daily Notes';

  @override
  String get dailyNote => 'Daily Note';

  @override
  String get todaysNote => 'Today\'s Note';

  @override
  String get createTodaysNote => 'Create today\'s note';

  @override
  String get noDailyNote => 'No note for this day';

  @override
  String get openDailyNote => 'Open daily note';

  @override
  String get goToToday => 'Today';

  @override
  String get hasNote => 'Has note';

  @override
  String get calendar => 'Calendar';

  @override
  String get recentDailyNotes => 'Recent Daily Notes';

  @override
  String get commandPalette => 'Command Palette';

  @override
  String get commandSearchHint => 'Type to search notes and commands...';

  @override
  String get commandRecentNotes => 'Recent';

  @override
  String get commandNotesSection => 'Notes';

  @override
  String get commandActions => 'Actions';

  @override
  String get commandCreateNewNote => 'Create New Note';

  @override
  String get commandOpenDailyNotes => 'Open Daily Notes';

  @override
  String get commandOpenGraph => 'Open Graph View';

  @override
  String get commandOpenDashboard => 'Open Dashboard';

  @override
  String get commandOpenTrash => 'Open Trash';

  @override
  String get commandOpenSettings => 'Open Settings';

  @override
  String get commandNoResultsFound => 'No results found';

  @override
  String get slashHeading1 => 'Heading 1';

  @override
  String get slashHeading2 => 'Heading 2';

  @override
  String get slashHeading3 => 'Heading 3';

  @override
  String get slashBulletList => 'Bullet List';

  @override
  String get slashNumberedList => 'Numbered List';

  @override
  String get slashTodoList => 'To-do List';

  @override
  String get slashCodeBlock => 'Code Block';

  @override
  String get slashQuote => 'Quote';

  @override
  String get slashDivider => 'Divider';

  @override
  String get slashTable => 'Table';

  @override
  String get slashImage => 'Image';

  @override
  String get slashWikilink => 'Wiki Link';

  @override
  String get slashTransclusion => 'Transclusion';

  @override
  String get slashCallout => 'Callout';

  @override
  String get slashNoResults => 'No matching commands';

  @override
  String get splitView => 'Split View';

  @override
  String get openInSplitView => 'Open in Split View';

  @override
  String get closeSplitView => 'Close Split View';

  @override
  String get selectNoteForSplit => 'Select note for split view';

  @override
  String get searchOperators => 'Search operators';

  @override
  String get searchOperatorTag => 'tag:name -- Filter by tag';

  @override
  String get searchOperatorStatus =>
      'status:todo|in-progress|done|blocked|cancelled';

  @override
  String get searchOperatorPriority => 'priority:high|medium|low';

  @override
  String get searchOperatorDate => 'date:YYYY-MM-DD -- Filter by date';

  @override
  String get searchOperatorCollection =>
      'collection:name -- Filter by collection';

  @override
  String get searchOperatorLinks => 'links:true|false -- Filter by link status';

  @override
  String get searchOperatorsExample =>
      'Example: tag:work status:todo project plan';

  @override
  String get savedSearches => 'Saved Searches';

  @override
  String get saveSearch => 'Save Search';

  @override
  String get saveSearchName => 'Search name';

  @override
  String get searchSaved => 'Search saved';

  @override
  String get deleteSavedSearch => 'Delete saved search';

  @override
  String deleteSavedSearchConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get searchHistory => 'Recent Searches';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get noSavedSearches => 'No saved searches yet';

  @override
  String get saveSearchHint =>
      'Search for something, then tap the bookmark icon to save it';

  @override
  String get noSearchHistory => 'No search history';

  @override
  String get showSearchHints => 'Show search hints';

  @override
  String get hideSearchHints => 'Hide search hints';

  @override
  String get searchNotesHint =>
      'Search with operators: tag:work status:todo ...';

  @override
  String get enterQueryOrOperators =>
      'Enter a query with operators to find notes';

  @override
  String get imageGallery => 'Image Gallery';

  @override
  String get fromGallery => 'From Gallery';

  @override
  String get fromCamera => 'From Camera';

  @override
  String get selectImageSource => 'Select Image Source';

  @override
  String get pasteImage => 'Paste Image';

  @override
  String get deleteImage => 'Delete Image';

  @override
  String get deleteImageConfirm =>
      'Are you sure you want to delete this image?';

  @override
  String get imageManagement => 'Image Management';

  @override
  String get totalStorage => 'Total Storage';

  @override
  String imageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count image$_temp0';
  }

  @override
  String get orphanedImages => 'Orphaned Images';

  @override
  String get cleanupOrphaned => 'Clean up orphaned images';

  @override
  String cleanupComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Cleaned up $count orphaned image$_temp0';
  }

  @override
  String get deleteAllImages => 'Delete all images';

  @override
  String get deleteAllImagesConfirm =>
      'This will delete all stored images. This cannot be undone.';

  @override
  String get noImagesStored => 'No images stored';

  @override
  String get imageDeleted => 'Image deleted';

  @override
  String get shareImage => 'Share Image';

  @override
  String get compareVersions => 'Compare Versions';

  @override
  String get versionDiff => 'Version Diff';

  @override
  String linesAdded(int count) {
    return '$count lines added';
  }

  @override
  String linesRemoved(int count) {
    return '$count lines removed';
  }

  @override
  String get selectTwoVersions => 'Select two versions to compare';

  @override
  String get noChanges => 'No changes';

  @override
  String versionNumber(int number) {
    return 'Version $number';
  }

  @override
  String readingTime(int minutes) {
    return '$minutes min read';
  }

  @override
  String get lessThan1Min => 'Less than 1 min read';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
      zero: '0 lines',
    );
    return '$_temp0';
  }

  @override
  String paragraphCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragraphs',
      one: '1 paragraph',
      zero: '0 paragraphs',
    );
    return '$_temp0';
  }

  @override
  String get focusMode => 'Focus Mode';

  @override
  String get typewriterScroll => 'Typewriter Scroll';

  @override
  String get writingStats => 'Writing Stats';

  @override
  String get toggleWritingStats => 'Toggle writing stats';

  @override
  String charCountNoSpaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chars (no spaces)',
      one: '1 char (no spaces)',
      zero: '0 chars (no spaces)',
    );
    return '$_temp0';
  }

  @override
  String get statistics => 'Statistics';

  @override
  String get totalWords => 'Total Words';

  @override
  String get averageWords => 'Avg Words/Note';

  @override
  String get daysActive => 'Days Active';

  @override
  String get last30Days => 'last 30 days';

  @override
  String get writingStreak => 'Writing Streak';

  @override
  String currentStreak(int count) {
    return 'Current: $count days';
  }

  @override
  String longestStreak(int count) {
    return 'Longest: $count days';
  }

  @override
  String get monthlyActivity => 'Monthly Activity';

  @override
  String get topTags => 'Top Tags';

  @override
  String get topCollections => 'Top Collections';

  @override
  String get statusDistribution => 'Status Distribution';

  @override
  String get knowledgeGraphStats => 'Knowledge Graph';

  @override
  String get totalLinks => 'Total Links';

  @override
  String orphanedNotesCount(int count) {
    return '$count orphaned notes';
  }

  @override
  String get mostConnectedNote => 'Most Connected';

  @override
  String get noStatistics => 'No statistics yet';

  @override
  String get notesWithProperties => 'Notes with properties';

  @override
  String get notesWithLinks => 'Notes with links';

  @override
  String get exportNotes => 'Export Notes';

  @override
  String get exportingNotes => 'Exporting notes...';

  @override
  String get exportComplete => 'Export complete';

  @override
  String get exportSelectedNotes => 'Export Selected';

  @override
  String get exportCurrentNote => 'Export Current Note';

  @override
  String exportSelected(int count) {
    return '$count selected notes';
  }

  @override
  String get exportWithFrontmatter => 'Export with metadata';

  @override
  String get exportAsZip => 'Export as ZIP archive';

  @override
  String get includeFrontmatter => 'Include metadata (frontmatter)';

  @override
  String get frontmatterDesc =>
      'Add YAML metadata header with tags, dates, and properties';

  @override
  String get exportOrganization => 'Organization';

  @override
  String get exportFlat => 'Flat';

  @override
  String get exportByDate => 'By Date';

  @override
  String get exportByCollection => 'By Collection';

  @override
  String get exportByTag => 'By Tag';

  @override
  String notesExported(int count) {
    return '$count notes exported';
  }

  @override
  String get importFromMarkdown => 'Import from Markdown';

  @override
  String get importFromZip => 'Import from ZIP';

  @override
  String get importFromObsidian => 'Import from Obsidian Vault';

  @override
  String get importingNotes => 'Importing notes...';

  @override
  String notesImported(int count) {
    return '$count notes imported';
  }

  @override
  String get preserveDates => 'Preserve original dates';

  @override
  String get importTags => 'Import tags';

  @override
  String get importProperties => 'Import properties';

  @override
  String get noFilesSelected => 'No files selected';

  @override
  String get importOptions => 'Import Options';

  @override
  String get quickCapture => 'Quick Capture';

  @override
  String get typeSomething => 'Type something...';

  @override
  String get autoSaved => 'Auto-saved';

  @override
  String get discardDraft => 'Discard draft?';

  @override
  String get discardDraftMessage => 'Your unsaved changes will be lost.';

  @override
  String get discard => 'Discard';

  @override
  String get newNoteShortcut => 'New Note';

  @override
  String get newChecklistShortcut => 'New Checklist';

  @override
  String get dailyNoteShortcut => 'Daily Note';

  @override
  String get sharedToAnynote => 'Shared to AnyNote';

  @override
  String get setPriority => 'Set Priority';

  @override
  String get quickCaptureDesc => 'Quickly capture a thought';

  @override
  String pendingSync(int count) {
    return '$count pending';
  }

  @override
  String syncFailedCount(int count) {
    return '$count failed';
  }

  @override
  String get syncQueue => 'Sync Queue';

  @override
  String get pendingOperations => 'Pending Operations';

  @override
  String get failedOperations => 'Failed Operations';

  @override
  String get retryAll => 'Retry All';

  @override
  String get clearCompleted => 'Clear Completed';

  @override
  String operationFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get retryingSync => 'Retrying sync...';

  @override
  String get queueCleared => 'Completed operations cleared';

  @override
  String get noPendingOperations => 'No pending operations';

  @override
  String noteSemantics(String title) {
    return 'Note: $title';
  }

  @override
  String deleteNoteSemantics(String title) {
    return 'Delete note $title';
  }

  @override
  String archiveNoteSemantics(String title) {
    return 'Archive note $title';
  }

  @override
  String pinNoteSemantics(String title) {
    return 'Pin note $title';
  }

  @override
  String unpinNoteSemantics(String title) {
    return 'Unpin note $title';
  }

  @override
  String get noteContentEditor => 'Note content editor. Double-tap to edit.';

  @override
  String graphSummary(int nodeCount, int linkCount) {
    return '$nodeCount notes with $linkCount links';
  }

  @override
  String get pinnedNote => 'Pinned';

  @override
  String settingsGroup(String section) {
    return '$section settings';
  }

  @override
  String restoreNoteSemantics(String title) {
    return 'Restore note $title';
  }

  @override
  String permanentlyDeleteNoteSemantics(String title) {
    return 'Permanently delete note $title';
  }

  @override
  String deleteCollectionSemantics(String title) {
    return 'Delete collection $title';
  }

  @override
  String calendarDaySemantics(String date, String hasNote) {
    return '$date. $hasNote';
  }

  @override
  String noteCountSemantics(int count) {
    return '$count notes';
  }

  @override
  String get reminder => 'Reminder';

  @override
  String get setReminder => 'Set Reminder';

  @override
  String get reminderAt => 'Reminder Time';

  @override
  String get removeReminder => 'Remove Reminder';

  @override
  String get laterToday => 'Later Today';

  @override
  String get tomorrowMorning => 'Tomorrow Morning';

  @override
  String get nextWeek => 'Next Week';

  @override
  String get noReminders => 'No Reminders';

  @override
  String get recurring => 'Recurring';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get reminders => 'Reminders';

  @override
  String get reminderFired => 'Reminder Fired';

  @override
  String get color => 'Color';

  @override
  String get selectColor => 'Select Color';

  @override
  String get removeColor => 'Remove Color';

  @override
  String get noteColor => 'Note Color';

  @override
  String get customColor => 'Custom Color';

  @override
  String get colorFilter => 'Color Filter';

  @override
  String get searchOperatorColor =>
      'color:#RRGGBB or color:name -- Filter by color';

  @override
  String get none => 'None';

  @override
  String get compareNotes => 'Compare';

  @override
  String get selectNotesToCompare => 'Select Notes to Compare';

  @override
  String get unifiedView => 'Unified';

  @override
  String get sideBySideView => 'Side-by-side';

  @override
  String get additions => 'Additions';

  @override
  String get deletions => 'Deletions';

  @override
  String get selectTwoNotes => 'Select exactly 2 notes to compare';

  @override
  String get noteDiff => 'Note Diff';

  @override
  String linesChanged(int added, int removed) {
    return '$added lines added, $removed lines removed';
  }

  @override
  String get mermaidDiagram => 'Mermaid Diagram';

  @override
  String get viewDiagram => 'View Diagram';

  @override
  String get copyMermaidCode => 'Copy Mermaid Code';

  @override
  String get diagramCopied => 'Diagram code copied';

  @override
  String get mermaidTemplate => 'Mermaid Template';

  @override
  String get insertDiagram => 'Insert Diagram';

  @override
  String get slashMermaid => 'Mermaid Diagram';

  @override
  String get viewSource => 'View Source';

  @override
  String get diagramError => 'Failed to render diagram';

  @override
  String get copyDiagramSource => 'Copy Diagram Source';

  @override
  String get lockNote => 'Lock Note';

  @override
  String get unlockNote => 'Unlock Note';

  @override
  String get noteLocked => 'Note Locked';

  @override
  String get lockedNoteBanner => 'This note is locked. Tap to unlock.';

  @override
  String notesColored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 colored';
  }

  @override
  String colorRemovedFromNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Color removed from $count note$_temp0';
  }

  @override
  String get batchColor => 'Color';

  @override
  String get batchLock => 'Lock';

  @override
  String get batchUnlock => 'Unlock';

  @override
  String notesLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 locked';
  }

  @override
  String notesUnlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count note$_temp0 unlocked';
  }

  @override
  String get moveToCollection => 'Move to Collection';

  @override
  String get searchCollections => 'Search collections...';

  @override
  String get noCollections => 'No collections found';

  @override
  String notesMovedToCollection(int count, String name) {
    return '$count notes moved to \"$name\"';
  }

  @override
  String noteMovedToCollection(String name) {
    return 'Note moved to \"$name\"';
  }

  @override
  String get addToCollection => 'Add to Collection';

  @override
  String get scrollToTop => 'Scroll to top';

  @override
  String get printNote => 'Print note';

  @override
  String get printPreview => 'Print preview';

  @override
  String get includeMetadata => 'Include metadata';

  @override
  String get includeImages => 'Include images';

  @override
  String get shareAsHtml => 'Share as HTML';

  @override
  String get exportedAsHtml => 'Exported as HTML';

  @override
  String get foldView => 'Fold View';

  @override
  String get foldAll => 'Fold All';

  @override
  String get unfoldAll => 'Unfold All';

  @override
  String sectionLines(int count) {
    return '$count lines';
  }

  @override
  String foldedSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count folded section$_temp0';
  }

  @override
  String get toggleFold => 'Toggle fold';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String get noHeadings => 'No headings found';

  @override
  String headingLevel(int level) {
    return 'Heading level $level';
  }

  @override
  String get readAloud => 'Read Aloud';

  @override
  String get stopReading => 'Stop Reading';

  @override
  String get pauseReading => 'Pause';

  @override
  String get resumeReading => 'Resume';

  @override
  String get readingSpeed => 'Reading Speed';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get general => 'General';

  @override
  String get editor => 'Editor';

  @override
  String get navigation => 'Navigation';

  @override
  String get shortcutBold => 'Bold';

  @override
  String get shortcutItalic => 'Italic';

  @override
  String get shortcutStrikethrough => 'Strikethrough';

  @override
  String get shortcutUndo => 'Undo';

  @override
  String get shortcutRedo => 'Redo';

  @override
  String get shortcutPrint => 'Print';

  @override
  String get shortcutLink => 'Insert Link';

  @override
  String get shortcutCode => 'Inline Code';

  @override
  String get shortcutHeading => 'Toggle Heading';

  @override
  String get shortcutCommandPalette => 'Command Palette';

  @override
  String get shortcutFocusMode => 'Focus Mode';

  @override
  String get reminderNotificationTitle => 'Reminder';

  @override
  String reminderNotificationBody(String title) {
    return 'Time to review: $title';
  }

  @override
  String get notificationChannelName => 'Note Reminders';

  @override
  String get notificationChannelDescription =>
      'Notifications for note reminders';

  @override
  String get exportPdf => 'PDF';

  @override
  String get generatePdf => 'Generate PDF';

  @override
  String get pdfGenerated => 'PDF generated';

  @override
  String get sharePdf => 'Share PDF';

  @override
  String get exportFormatPdf => 'PDF Document';

  @override
  String get snippets => 'Snippets';

  @override
  String get snippetTitle => 'Title';

  @override
  String get snippetCode => 'Code';

  @override
  String get snippetLanguage => 'Language';

  @override
  String get snippetDescription => 'Description';

  @override
  String get snippetCategory => 'Category';

  @override
  String get snippetTags => 'Tags';

  @override
  String get newSnippet => 'New Snippet';

  @override
  String get editSnippet => 'Edit Snippet';

  @override
  String get deleteSnippet => 'Delete Snippet';

  @override
  String get deleteSnippetConfirm => 'Delete this snippet?';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get insertSnippet => 'Insert Snippet';

  @override
  String get noSnippets => 'No snippets yet';

  @override
  String get searchSnippets => 'Search snippets...';

  @override
  String usageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Used $count time$_temp0';
  }

  @override
  String get allLanguages => 'All Languages';

  @override
  String get allCategories => 'All Categories';

  @override
  String get tagHierarchy => 'Tag Hierarchy';

  @override
  String get createSubTag => 'Create Sub-tag';

  @override
  String get moveToParent => 'Move to Parent';

  @override
  String get noParent => 'No Parent (Root)';

  @override
  String get selectParentTag => 'Select Parent Tag';

  @override
  String get expandAll => 'Expand All';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String userCursor(String name) {
    return '$name\'s cursor';
  }

  @override
  String get remoteUser => 'Remote user';

  @override
  String get dropImageHere => 'Drop image here';

  @override
  String get imageAdded => 'Image added';

  @override
  String get unsupportedFileType => 'Only image files are supported';

  @override
  String get quickNote => 'New Note';

  @override
  String get quickChecklist => 'New Checklist';

  @override
  String get quickDailyNote => 'Daily Note';

  @override
  String get moreOptions => 'More options';

  @override
  String get failedToLoadTrash => 'Failed to load trash';

  @override
  String failedToRestoreError(String error) {
    return 'Failed to restore: $error';
  }

  @override
  String failedToDeleteError(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get deleteProperty => 'Delete Property';

  @override
  String get removePropertyConfirm => 'Remove this property from the note?';

  @override
  String get propertiesTitle => 'Properties';

  @override
  String get noProperties => 'No properties';

  @override
  String get addCustomMetadata => 'Add custom metadata to this note';

  @override
  String get addPropertyButton => 'Add Property';

  @override
  String get editProperty => 'Edit Property';

  @override
  String get customPropertyTitle => 'Custom Property';

  @override
  String get propertyLabel => 'Property';

  @override
  String get valueLabel => 'Value';

  @override
  String get numberLabel => 'Number';

  @override
  String get enterValue => 'Enter a value';

  @override
  String get enterNumber => 'Enter a number';

  @override
  String get selectDateLabel => 'Select a date';

  @override
  String get linkManagementTitle => 'Link Management';

  @override
  String get outboundLinks => 'Outbound Links';

  @override
  String get deleteLinkTitle => 'Delete Link';

  @override
  String get removeLinkConfirm => 'Remove this connection between notes?';

  @override
  String get noLinksToDisplay =>
      'No links to display. Adjust filters to see more.';

  @override
  String get linksToThisNote => 'Links to this note';

  @override
  String get thisNoteLinksTo => 'This note links to';

  @override
  String get deleteLinkTooltip => 'Delete link';

  @override
  String get insertTable => 'Insert Table';

  @override
  String get dragToSelectTableSize => 'Drag to select table size';

  @override
  String get proPlan => 'Pro';

  @override
  String get lifetimePlan => 'Lifetime';

  @override
  String get proPrice => '\$4.99/mo';

  @override
  String get lifetimePrice => '\$49.99';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String tagsCountLabel(int count) {
    return '$count tags';
  }

  @override
  String get orphanedNotes => 'Orphaned notes';

  @override
  String get filter => 'Filter';

  @override
  String priorityLabel(String priority) {
    return 'Priority: $priority';
  }

  @override
  String get noMatchingNotes => 'No matching notes';

  @override
  String get tryChangingFilters => 'Try changing your filters';

  @override
  String get filterByProperties => 'Filter by Properties';

  @override
  String get priority => 'Priority';

  @override
  String get viewProperties => 'Properties';

  @override
  String get noteTitle => 'Note title';

  @override
  String get dateLabel => 'Date';

  @override
  String propertyOf(String name) {
    return 'Property: $name';
  }

  @override
  String get insertLabel => 'Insert';

  @override
  String failedToLoadMore(String error) {
    return 'Failed to load more: $error';
  }

  @override
  String get linkCreated => 'Link created';

  @override
  String failedToCreateLink(String error) {
    return 'Failed to create link: $error';
  }

  @override
  String get suggestedLinks => 'Suggested Links';

  @override
  String get similarContentDesc =>
      'Notes with similar titles or content. Tap to create a link.';

  @override
  String get noSuggestions => 'No Suggestions';

  @override
  String get createMoreNotes => 'Create more notes to get suggestions.';

  @override
  String get notAvailableOnWeb => 'This feature is not available on web';

  @override
  String get okButton => 'OK';

  @override
  String get failedToLoadDeferred => 'Failed to load';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get syncStatusTitle => 'Sync Status';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get connectedLabel => 'Connected';

  @override
  String get pendingOpsLabel => 'Pending operations';

  @override
  String get lastSyncedLabel => 'Last synced';

  @override
  String get failedItemsLabel => 'Failed items';

  @override
  String get offlineSyncTooltip =>
      'Offline -- changes will sync when connected';

  @override
  String get pullingLabel => 'Pulling';

  @override
  String get pushingLabel => 'Pushing';

  @override
  String get syncingLabel => 'Syncing...';

  @override
  String get allChangesSyncedLabel => 'All changes synced';

  @override
  String pendingOpTooltip(int count) {
    return '$count pending operation';
  }

  @override
  String pendingOpsTooltip(int count) {
    return '$count pending operations';
  }

  @override
  String get syncConflictBadge => 'Sync conflict';

  @override
  String get conflictLabel => 'Conflict';

  @override
  String get syncedLabel => 'Synced';

  @override
  String get pendingSyncLabel => 'Pending';

  @override
  String get pendingSyncBadge => 'Pending sync';

  @override
  String barChartSemanticLabel(String entries) {
    return 'Bar chart showing notes by month: $entries';
  }

  @override
  String donutChartSemanticLabel(String entries) {
    return 'Donut chart showing distribution: $entries';
  }

  @override
  String tagItemSemanticLabel(String name) {
    return 'Tag: $name';
  }

  @override
  String get tagItemSemanticHint => 'Long press to edit';

  @override
  String get moreActions => 'More actions';

  @override
  String get statusSaved => 'Saved';

  @override
  String get statusUnsaved => 'Unsaved';

  @override
  String get statusSaving => 'Saving...';

  @override
  String get selectItemToView => 'Select an item to view';

  @override
  String get syncConflicts => 'Sync Conflicts';

  @override
  String get noConflicts => 'No conflicts to resolve';

  @override
  String conflictItem(String itemId) {
    return 'Item: $itemId';
  }

  @override
  String serverVersion(int version) {
    return 'Server version: $version';
  }

  @override
  String get keepLocal => 'Keep Local';

  @override
  String get keepServer => 'Keep Server';

  @override
  String get keepBoth => 'Keep Both';

  @override
  String get findInNote => 'Find in note';

  @override
  String get replaceWith => 'Replace with';

  @override
  String get noMatches => 'No matches';

  @override
  String matchCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String get findPrevious => 'Previous match';

  @override
  String get findNext => 'Next match';

  @override
  String get replaceMatch => 'Replace';

  @override
  String get replaceAllMatches => 'Replace all';

  @override
  String get closeFindBar => 'Close find bar';

  @override
  String get codeBlock => 'Code block';

  @override
  String get checklist => 'Checklist';

  @override
  String get indent => 'Indent';

  @override
  String get outdent => 'Outdent';
}

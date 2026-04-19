// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'AnyNote';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get signInToVault => '暗号化された保管庫にサインイン';

  @override
  String get email => 'メールアドレス';

  @override
  String get emailRequired => 'メールアドレスを入力してください';

  @override
  String get password => 'パスワード';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get signIn => 'サインイン';

  @override
  String get noAccountRegister => 'アカウントをお持ちでない方はこちら';

  @override
  String get recoverFromBackup => 'バックアップから復元';

  @override
  String get noEncryptionKeys => '暗号鍵が見つかりません。先に登録してください。';

  @override
  String get invalidEmailOrPassword => 'メールアドレスまたはパスワードが正しくありません。';

  @override
  String get accountNotFoundRegister => 'アカウントが見つかりません。先に登録してください。';

  @override
  String get unableToReachServer => 'サーバーに接続できません。通信環境を確認してください。';

  @override
  String get createAccount => 'アカウント作成';

  @override
  String get startEncryptedJourney => '暗号化メモを始めましょう';

  @override
  String get username => 'ユーザー名';

  @override
  String get usernameRequired => 'ユーザー名を入力してください';

  @override
  String get confirmPassword => 'パスワード確認';

  @override
  String get passwordsDoNotMatch => 'パスワードが一致しません';

  @override
  String get passwordMinLength => 'パスワードは8文字以上で入力してください';

  @override
  String get encryptionNotice => 'データはこのパスワードで暗号化されます。紛失すると復元できません。';

  @override
  String get alreadyHaveAccount => 'アカウントをお持ちの方はこちら';

  @override
  String get emailOrUsernameTaken => 'そのメールアドレスまたはユーザー名は既に使用されています。';

  @override
  String get invalidInput => '入力内容に誤りがあります。確認してください。';

  @override
  String get saveRecoveryKey => 'リカバリーキーを保存';

  @override
  String get recoveryKeyInstructions =>
      'このリカバリーキーを安全な場所に保管してください。パスワードを忘れた場合、データの復元に必要です。';

  @override
  String get copyRecoveryKey => 'リカバリーキーをコピー';

  @override
  String get recoveryKeyCopied => 'リカバリーキーをクリップボードにコピーしました';

  @override
  String get iSavedIt => '保存しました';

  @override
  String get recoverAccount => 'アカウント復元';

  @override
  String get recoverAccountInstructions =>
      '12語のリカバリーキーを入力して、この端末で暗号化保管庫を復元してください。';

  @override
  String get recoveryKeyLabel => 'リカバリーキー（12語）';

  @override
  String get pasteFromClipboard => 'クリップボードから貼り付け';

  @override
  String get recoveryKeyRequired => 'リカバリーキーを入力してください';

  @override
  String get recoveryKeyWordCount => 'リカバリーキーはちょうど12語である必要があります';

  @override
  String get recoveryKeyFormatHint => '12語を正しい順序で、スペースで区切って入力してください。';

  @override
  String get invalidRecoveryKey => '無効なリカバリーキーです。入力内容を確認して再度お試しください。';

  @override
  String get invalidRecoveryKeyForAccount => 'このアカウントのリカバリーキーではありません。';

  @override
  String get accountNotFoundCheckEmail => 'アカウントが見つかりません。メールアドレスを確認してください。';

  @override
  String get backToSignIn => 'サインインに戻る';

  @override
  String get skip => 'スキップ';

  @override
  String get next => '次へ';

  @override
  String get getStarted => '始める';

  @override
  String get onboardingPrivacyTitle => 'あなたのメモ、あなたのプライバシー';

  @override
  String get onboardingPrivacyDesc =>
      'AnyNoteはすべてのメモをクラウドに送信する前に端末で暗号化します。誰にも — 開発者にも — 読まれることはありません。';

  @override
  String get onboardingMasterPasswordTitle => 'マスターパスワード';

  @override
  String get onboardingMasterPasswordDesc =>
      '暗号鍵の元になるマスターパスワードを設定します。必ず覚えておいてください — リカバリーキーがない限りパスワードの再設定はできません。';

  @override
  String get onboardingRecoveryKeyTitle => 'リカバリーキー';

  @override
  String get onboardingRecoveryKeyDesc =>
      '12語のリカバリーキーが発行されます。安全に保管してください — パスワードを忘れた場合、メモを復元する唯一の手段です。';

  @override
  String get onboardingAITitle => 'AI搭載のライティング';

  @override
  String get onboardingAIDesc =>
      'AIを使ってメモの作成、アウトライン作成、あらゆるプラットフォーム向けの変換ができます。コンテンツは一切記録されません。';

  @override
  String get searchNotes => 'メモを検索...';

  @override
  String get collections => 'コレクション';

  @override
  String get sortNotes => 'メモの並び替え';

  @override
  String get updatedNewest => '更新日（新しい順）';

  @override
  String get updatedOldest => '更新日（古い順）';

  @override
  String get createdNewest => '作成日（新しい順）';

  @override
  String get createdOldest => '作成日（古い順）';

  @override
  String get titleAZ => 'タイトル A-Z';

  @override
  String get listView => 'リスト表示';

  @override
  String get gridView => 'グリッド表示';

  @override
  String get advancedSearch => '詳細検索';

  @override
  String get closeSearch => '検索を閉じる';

  @override
  String get searchNotesTooltip => 'メモを検索';

  @override
  String get createNewNote => '新規メモを作成';

  @override
  String get noNotesYet => 'メモはまだありません';

  @override
  String get tapToCapture => '+ をタップして最初のメモを作成しましょう';

  @override
  String get newNote => '新規メモ';

  @override
  String get noResults => '結果なし';

  @override
  String get tryDifferentSearch => '別のキーワードで検索してみてください';

  @override
  String get deleteNoteQuestion => 'メモを削除しますか？';

  @override
  String deleteNoteConfirm(String title) {
    return '「$title」を削除してよろしいですか？';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get noteDeleted => 'メモを削除しました';

  @override
  String get undo => '元に戻す';

  @override
  String get unpinNote => 'ピン留めを解除';

  @override
  String get pinNote => 'ピン留め';

  @override
  String get deleteNote => 'メモを削除';

  @override
  String get blankNote => '空白のメモ';

  @override
  String get fromTemplate => 'テンプレートから作成';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int count) {
    return '$count分前';
  }

  @override
  String hoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String daysAgo(int count) {
    return '$count日前';
  }

  @override
  String get untitled => '無題';

  @override
  String get versionHistory => 'バージョン履歴';

  @override
  String get editNote => 'メモを編集';

  @override
  String get exportOrShare => 'エクスポート・共有';

  @override
  String get shareViaLink => 'リンクで共有';

  @override
  String get exportAsMarkdown => 'Markdownでエクスポート';

  @override
  String get exportAsHTML => 'HTMLでエクスポート';

  @override
  String get exportAsPlainText => 'プレーンテキストでエクスポート';

  @override
  String get failedToLoadNote => 'メモの読み込みに失敗しました';

  @override
  String get retry => '再試行';

  @override
  String get noteNotFound => 'メモが見つかりません';

  @override
  String get notSynced => '未同期';

  @override
  String get couldNotLoadForExport => 'エクスポート用のメモを読み込めませんでした';

  @override
  String get deleteNoteDialog => 'メモの削除';

  @override
  String get deleteNoteDialogMessage => 'このメモはゴミ箱に移動します。後で復元できます。';

  @override
  String get title => 'タイトル';

  @override
  String get startWriting => '入力を始める...';

  @override
  String get saveAndClose => '保存して閉じる';

  @override
  String get savingNote => 'メモを保存中';

  @override
  String get plainText => 'プレーンテキスト';

  @override
  String get richText => 'リッチテキスト';

  @override
  String get edit => '編集';

  @override
  String get preview => 'プレビュー';

  @override
  String get manageTags => 'タグを管理';

  @override
  String get addImage => '画像を追加';

  @override
  String get noteContent => 'メモの内容';

  @override
  String get tags => 'タグ';

  @override
  String get closeTagPicker => 'タグ選択を閉じる';

  @override
  String get newTagName => '新しいタグ名';

  @override
  String get add => '追加';

  @override
  String get noTagsYet => 'タグはまだありません。上で作成してください。';

  @override
  String failedToAddImage(String error) {
    return '画像の追加に失敗しました: $error';
  }

  @override
  String get restore => '復元';

  @override
  String get close => '閉じる';

  @override
  String get restoreVersion => 'バージョンを復元';

  @override
  String restoreVersionConfirm(int version) {
    return '現在のメモの内容をバージョン $version に置き換えますか？現在の内容のスナップショットが先に保存されます。';
  }

  @override
  String get versionRestored => 'バージョンを復元しました';

  @override
  String failedToRestore(String error) {
    return '復元に失敗しました: $error';
  }

  @override
  String get failedToLoadVersions => 'バージョンの読み込みに失敗しました';

  @override
  String get noVersionsYet => 'バージョン履歴はまだありません';

  @override
  String get versionsSavedAutomatically => 'メモを編集すると自動的にバージョンが保存されます。';

  @override
  String get current => '現在';

  @override
  String get settings => '設定';

  @override
  String get account => 'アカウント';

  @override
  String get plan => 'プラン';

  @override
  String get upgrade => 'アップグレード';

  @override
  String get loading => '読み込み中...';

  @override
  String get unableToLoadAccountInfo => 'アカウント情報を読み込めません';

  @override
  String get aiSection => 'AI';

  @override
  String get llmConfiguration => 'LLM設定';

  @override
  String get configureAIProviders => 'AIプロバイダーを設定';

  @override
  String get aiQuota => 'AI利用枠';

  @override
  String requestsToday(int used, int limit) {
    return '本日のリクエスト数: $used/$limit';
  }

  @override
  String get unableToLoadQuota => '利用枠を読み込めません';

  @override
  String get publishing => '公開';

  @override
  String get platformConnections => 'プラットフォーム連携';

  @override
  String get manageConnectedPlatforms => '連携中のプラットフォームを管理';

  @override
  String get securityPrivacy => 'セキュリティとプライバシー';

  @override
  String get encryptionSettings => '暗号化設定';

  @override
  String get e2eEncryptionActive => 'E2E暗号化 有効';

  @override
  String get sync => '同期';

  @override
  String get syncStatus => '同期ステータス';

  @override
  String get lastSyncedNever => '最終同期: なし';

  @override
  String lastSynced(String time) {
    return '最終同期: $time';
  }

  @override
  String get checking => '確認中...';

  @override
  String get unableToLoadSyncStatus => '同期ステータスを読み込めません';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String syncCompleteWithConflicts(int count) {
    return '同期完了（$count件の競合）';
  }

  @override
  String synced(int pulled, int pushed) {
    return '同期完了: $pulled件取得、$pushed件送信';
  }

  @override
  String get data => 'データ';

  @override
  String get exportAllNotes => 'すべてのメモをエクスポート';

  @override
  String get exportAllNotesDesc => 'すべてのメモをファイルにエクスポート';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get htmlFormat => 'HTML (.html)';

  @override
  String get plainTextFormat => 'プレーンテキスト (.txt)';

  @override
  String get noNotesToExport => 'エクスポートするメモがありません';

  @override
  String get noNotesWithContent => '内容のあるメモがありません';

  @override
  String exportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get about => 'アプリについて';

  @override
  String get version => 'バージョン';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get signOut => 'サインアウト';

  @override
  String get signOutConfirmTitle => 'サインアウト';

  @override
  String get signOutConfirmMessage =>
      'サインアウトしてよろしいですか？メモにアクセスするには再度ログインが必要になります。';

  @override
  String signOutFailed(String error) {
    return 'サインアウトに失敗しました: $error';
  }

  @override
  String get securityEncryption => 'セキュリティと暗号化';

  @override
  String get e2eEncryptionActiveStatus => 'E2E暗号化 有効';

  @override
  String get encryptionNotSetUp => '暗号化が設定されていません';

  @override
  String get encryptionAlgorithm => 'データはXChaCha20-Poly1305で暗号化されています';

  @override
  String get keyDerivation => '鍵導出: Argon2id';

  @override
  String get masterKeyUnlocked => 'マスターキー: ロック解除済み';

  @override
  String get masterKeyLocked => 'マスターキー: ロック中';

  @override
  String get encryptedItems => '暗号化済みアイテム';

  @override
  String get notes => 'メモ';

  @override
  String get tagsLabel => 'タグ';

  @override
  String get collectionsLabel => 'コレクション';

  @override
  String get aiContent => 'AIコンテンツ';

  @override
  String itemsCount(int count) {
    return '$count件';
  }

  @override
  String get recoveryKeySection => 'リカバリーキー';

  @override
  String get recoveryKeyUsage => 'パスワードを忘れた場合、このキーでデータを復元できます。';

  @override
  String get viewRecoveryKey => 'リカバリーキーを表示';

  @override
  String get noRecoveryKeyStored => 'リカバリーキーが保存されていません。';

  @override
  String get recoveryKeyWarning =>
      'リカバリーキーは登録時に生成されました。保存していない場合、パスワードなしではデータを復元できません。';

  @override
  String get copyToClipboard => 'クリップボードにコピー';

  @override
  String get hide => '非表示';

  @override
  String get failedToLoadRecoveryKey => 'リカバリーキーの読み込みに失敗しました';

  @override
  String get changePassword => 'パスワード変更';

  @override
  String get reEncryptsData => '新しい鍵ですべてのデータを再暗号化します';

  @override
  String get verifyPassword => 'パスワード確認';

  @override
  String get enterYourPassword => 'パスワードを入力してください';

  @override
  String get verify => '確認';

  @override
  String get incorrectPassword => 'パスワードが正しくありません';

  @override
  String get verificationFailed => '確認に失敗しました';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードの確認';

  @override
  String get reEncryptWarning => '警告: すべてのデータが再暗号化されます。';

  @override
  String get change => '変更';

  @override
  String get currentPasswordIncorrect => '現在のパスワードが正しくありません';

  @override
  String get passwordChangedSuccessfully => 'パスワードを変更しました';

  @override
  String failedToChangePassword(String error) {
    return 'パスワードの変更に失敗しました: $error';
  }

  @override
  String get dangerZone => '危険ゾーン';

  @override
  String get deleteAllLocalData => 'すべてのローカルデータを削除';

  @override
  String get exportEncryptedBackup => '暗号化バックアップをエクスポート';

  @override
  String get importEncryptedBackup => '暗号化バックアップをインポート';

  @override
  String get deleteAllDataQuestion => 'すべてのデータを削除しますか？';

  @override
  String get deleteAllDataMessage => 'この操作は取り消せません。すべてのメモ、タグ、設定が完全に削除されます。';

  @override
  String get deleteEverything => 'すべて削除';

  @override
  String get areYouAbsolutelySure => '本当に実行しますか？';

  @override
  String get typeDeleteToConfirm => '確認のため「DELETE」と入力してください。';

  @override
  String get typeDelete => '「DELETE」と入力';

  @override
  String get allLocalDataDeleted => 'すべてのローカルデータを削除しました';

  @override
  String failedToDeleteData(String error) {
    return 'データの削除に失敗しました: $error';
  }

  @override
  String get importBackup => 'バックアップをインポート';

  @override
  String get importBackupMessage =>
      'バックアップファイルからアイテムをインポートします。既存のアイテムは上書きされません。続行しますか？';

  @override
  String get import => 'インポート';

  @override
  String importedItemsFromBackup(int count) {
    return 'バックアップから$count件のアイテムをインポートしました';
  }

  @override
  String backupExportFailed(String error) {
    return 'バックアップのエクスポートに失敗しました: $error';
  }

  @override
  String backupImportFailed(String error) {
    return 'バックアップのインポートに失敗しました: $error';
  }

  @override
  String get llmConfigTitle => 'LLM設定';

  @override
  String get noLLMConfigs => 'LLM設定がありません';

  @override
  String get addLLMToEnableAI => 'LLMを追加してAI機能を有効にしてください';

  @override
  String get addProvider => 'プロバイダーを追加';

  @override
  String get defaultLabel => 'デフォルト';

  @override
  String get testConnection => '接続テスト';

  @override
  String get failedToLoadConfigs => '設定の読み込みに失敗しました';

  @override
  String get addLLMProvider => 'LLMプロバイダーを追加';

  @override
  String get name => '名前';

  @override
  String get provider => 'プロバイダー';

  @override
  String get baseUrl => 'ベースURL';

  @override
  String get apiKey => 'APIキー';

  @override
  String get model => 'モデル';

  @override
  String get modelHint => '例: gpt-4o';

  @override
  String get save => '保存';

  @override
  String get editLLMProvider => 'LLMプロバイダーを編集';

  @override
  String get newApiKeyHint => '新しいAPIキー（変更しない場合は空欄）';

  @override
  String get testingConnection => '接続テスト中...';

  @override
  String get connectionSuccessful => '接続に成功しました';

  @override
  String connectionFailed(String error) {
    return '接続に失敗しました: $error';
  }

  @override
  String deleteConfigQuestion(String name) {
    return '$nameを削除しますか？';
  }

  @override
  String get removeLLMConfigConfirm => 'このLLM設定を削除してよろしいですか？';

  @override
  String get noPlatformsAvailable => '利用可能なプラットフォームがありません';

  @override
  String get platformConnectionsWillAppear => 'プラットフォーム連携がここに表示されます';

  @override
  String get failedToLoadPlatforms => 'プラットフォームの読み込みに失敗しました';

  @override
  String get connect => '連携';

  @override
  String get verifyButton => '確認';

  @override
  String get disconnect => '連携解除';

  @override
  String connectedTo(String name) {
    return '$nameと連携しました';
  }

  @override
  String failedToConnect(String error) {
    return '連携に失敗しました: $error';
  }

  @override
  String get verifyingConnection => '接続を確認中...';

  @override
  String get connectionVerified => '接続が確認されました';

  @override
  String connectionInvalid(String error) {
    return '接続が無効です: $error';
  }

  @override
  String verificationFailedError(String error) {
    return '確認に失敗しました: $error';
  }

  @override
  String disconnectPlatform(String name) {
    return '$nameとの連携を解除';
  }

  @override
  String disconnectPlatformConfirm(String name) {
    return '$nameアカウントとの連携を解除してよろしいですか？';
  }

  @override
  String disconnectedFrom(String name) {
    return '$nameとの連携を解除しました';
  }

  @override
  String failedToDisconnect(String error) {
    return '連携解除に失敗しました: $error';
  }

  @override
  String get scanQRCode => 'QRコードをスキャン';

  @override
  String scanQRInstructions(String platform) {
    return '$platformアプリを開き、このQRコードをスキャンしてログインしてください';
  }

  @override
  String get done => '完了';

  @override
  String get tagsTitle => 'タグ';

  @override
  String get noTags => 'タグがありません';

  @override
  String get createTagsToOrganize => 'タグを作成してメモを整理しましょう';

  @override
  String get newTag => '新しいタグ';

  @override
  String get tagName => 'タグ名';

  @override
  String get tagNameHint => '例: アイデア、仕事、プライベート';

  @override
  String get create => '作成';

  @override
  String get encrypted => '（暗号化済み）';

  @override
  String get aiCompose => 'AI作成';

  @override
  String get aiPoweredWriting => 'AI搭載ライティング';

  @override
  String get aiComposeDesc => 'メモを選択して、AIがあらゆるプラットフォーム向けの洗練されたコンテンツを作成します。';

  @override
  String get startComposing => '作成を開始';

  @override
  String get recentCompositions => '最近の作成';

  @override
  String get noCompositionsYet => '作成履歴はまだありません';

  @override
  String get newComposition => '新規作成';

  @override
  String get topicOrTheme => 'トピックまたはテーマ';

  @override
  String get topicHint => 'コンテンツのテーマを入力してください';

  @override
  String get targetPlatform => '対象プラットフォーム';

  @override
  String get selectNotes => 'メモを選択';

  @override
  String selectedCount(int count) {
    return '$count件選択';
  }

  @override
  String get noNotesAvailableCreate => 'メモがありません。\n先にメモを作成してください。';

  @override
  String get contentPreview => 'コンテンツプレビュー';

  @override
  String get noContent => '（内容なし）';

  @override
  String get copy => 'コピー';

  @override
  String get saveAsNote => 'メモとして保存';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get savedAsNote => 'メモとして保存しました';

  @override
  String get publish => '公開';

  @override
  String get connectedPlatforms => '連携中のプラットフォーム';

  @override
  String get noPlatformsConnected => '連携中のプラットフォームがありません';

  @override
  String get connectAPlatform => 'プラットフォームと連携';

  @override
  String get publishContent => 'コンテンツを公開';

  @override
  String get content => '内容';

  @override
  String get tagsCommaSeparated => 'タグ（カンマ区切り）';

  @override
  String get tagsHint => 'タグ1, タグ2, タグ3';

  @override
  String get selectPlatformToPublish => '上のプラットフォームを選択して公開してください';

  @override
  String publishedStatus(String status) {
    return '公開完了！ステータス: $status';
  }

  @override
  String get titleAndContentRequired => 'タイトルと内容は必須です';

  @override
  String get publishRequestSubmitted => '公開リクエストを送信しました';

  @override
  String get recentPublications => '最近の公開';

  @override
  String get noPublicationsYet => '公開履歴はまだありません';

  @override
  String viewAll(int count) {
    return 'すべて表示（$count件）';
  }

  @override
  String get publishHistory => '公開履歴';

  @override
  String get filterByStatus => 'ステータスで絞り込み';

  @override
  String get all => 'すべて';

  @override
  String get published => '公開済み';

  @override
  String get failed => '失敗';

  @override
  String get publishingStatus => '公開中';

  @override
  String get pending => '保留中';

  @override
  String noPublicationsWithStatus(String status) {
    return '$statusの公開はありません';
  }

  @override
  String get clearFilter => 'フィルターをクリア';

  @override
  String get noPublications => '公開履歴がありません';

  @override
  String get publishedContentWillAppear => '公開したコンテンツがここに表示されます';

  @override
  String get failedToLoadPublishHistory => '公開履歴の読み込みに失敗しました';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get platform => 'プラットフォーム';

  @override
  String get status => 'ステータス';

  @override
  String get created => '作成日';

  @override
  String get publishedDate => '公開日';

  @override
  String get url => 'URL';

  @override
  String get error => 'エラー';

  @override
  String get contentLabel => '内容';

  @override
  String failedToLoadDetail(String error) {
    return '詳細の読み込みに失敗しました: $error';
  }

  @override
  String get collectionsTitle => 'コレクション';

  @override
  String get noCollectionsYet => 'コレクションはまだありません';

  @override
  String get groupNotesIntoCollections => 'メモをコレクションにまとめましょう';

  @override
  String get newCollection => '新しいコレクション';

  @override
  String get deleteCollectionQuestion => 'コレクションを削除しますか？';

  @override
  String deleteCollectionConfirm(String title) {
    return '「$title」を削除してよろしいですか？コレクション内のメモは削除されません。';
  }

  @override
  String get collectionDeleted => 'コレクションを削除しました';

  @override
  String get untitledCollection => '無題のコレクション';

  @override
  String noteCount(int count, String suffix) {
    return '$count件のメモ$suffix';
  }

  @override
  String get collectionTitle => 'コレクション名';

  @override
  String get collectionTitleHint => 'このコレクションの名前を入力してください';

  @override
  String get collectionNotFound => 'コレクションが見つかりません';

  @override
  String get failedToLoadCollection => 'コレクションの読み込みに失敗しました';

  @override
  String get noNotesInCollection => 'このコレクションにメモはありません';

  @override
  String get tapToAddNotes => '+ をタップしてメモを追加';

  @override
  String get addNotes => 'メモを追加';

  @override
  String get removeFromCollection => 'コレクションから削除しますか？';

  @override
  String removeNoteConfirm(String title) {
    return '「$title」をこのコレクションから削除しますか？メモ自体は削除されません。';
  }

  @override
  String get remove => '削除';

  @override
  String get renameCollection => 'コレクション名を変更';

  @override
  String get renameCollectionTooltip => 'コレクション名を変更';

  @override
  String get deleteCollectionTooltip => 'コレクションを削除';

  @override
  String get deleteCollectionDialogTitle => 'コレクションの削除';

  @override
  String get deleteCollectionDialogMessage =>
      'このコレクションとすべてのメモの関連付けが削除されます。メモ自体は削除されません。';

  @override
  String get noNotesAvailable => '追加できるメモがありません';

  @override
  String get removeFromCollectionTooltip => 'コレクションから削除';

  @override
  String get search => '検索';

  @override
  String get clearAllFilters => 'すべてのフィルターをクリア';

  @override
  String get searchYourNotes => 'メモを検索';

  @override
  String get enterQueryOrFilters => 'キーワードを入力するかフィルターを使ってメモを探してください';

  @override
  String get recentSearches => '最近の検索';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get noResultsFound => '結果が見つかりません';

  @override
  String get tryAdjustingSearch => '検索条件やフィルターを調整してみてください';

  @override
  String searchError(String error) {
    return '検索エラー: $error';
  }

  @override
  String get dateRange => '期間';

  @override
  String get tagsFilter => 'タグ';

  @override
  String get collectionsFilter => 'コレクション';

  @override
  String tagsCount(int count) {
    return '$count件のタグ';
  }

  @override
  String collectionsCount(int count) {
    return '$count件のコレクション';
  }

  @override
  String resultsCount(String count) {
    return '$count件の結果';
  }

  @override
  String get noTagsAvailable => 'タグがありません';

  @override
  String get noCollectionsAvailable => 'コレクションがありません';

  @override
  String get selectTags => 'タグを選択';

  @override
  String get apply => '適用';

  @override
  String get selectCollections => 'コレクションを選択';

  @override
  String get shareNote => 'メモを共有';

  @override
  String get passwordProtection => 'パスワード保護';

  @override
  String get requirePassword => 'パスワードを要求';

  @override
  String get requirePasswordDesc => '閲覧時にパスワードの入力が必要です';

  @override
  String get expiresAfter => '有効期限';

  @override
  String get oneHour => '1時間';

  @override
  String get twentyFourHours => '24時間';

  @override
  String get sevenDays => '7日間';

  @override
  String get never => '期限なし';

  @override
  String get passwordRequiredForShare => 'パスワード保護を有効にする場合、パスワードは必須です';

  @override
  String failedToCreateShareLink(String error) {
    return '共有リンクの作成に失敗しました: $error';
  }

  @override
  String get linkCopiedToClipboard => 'リンクをクリップボードにコピーしました';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get passwordProtectedShareInfo =>
      'このリンクはパスワードで保護されています。パスワードは別途お伝えください。';

  @override
  String get publicShareInfo => 'このリンクを知っていれば誰でもメモを閲覧できます。';

  @override
  String linkExpiresIn(String expiry) {
    return 'リンクの有効期限: $expiry';
  }

  @override
  String get encrypting => '暗号化中...';

  @override
  String get createShareLink => '共有リンクを作成';

  @override
  String get language => '言語';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get languageChangedNotice => '言語の変更はアプリの再起動後に反映されます';

  @override
  String get zenMode => '集中モード';

  @override
  String get enterZenMode => '集中モードを開始';

  @override
  String get exitZenMode => '集中モードを終了';

  @override
  String wordCount(int count) {
    return '$count語';
  }

  @override
  String charCount(int count) {
    return '$count文字';
  }

  @override
  String get importNotes => 'メモをインポート';

  @override
  String get importMarkdown => 'Markdownをインポート';

  @override
  String get importTextFiles => 'テキストファイルをインポート';

  @override
  String get importAppleNotes => 'Appleメモをインポート';

  @override
  String importComplete(int count, int skipped) {
    return 'インポート完了: $count件インポート、$skipped件スキップ';
  }

  @override
  String get markdownPreview => 'Markdownプレビュー';

  @override
  String get restoreFromBackup => 'バックアップから復元';

  @override
  String get selectBackupFile => 'バックアップファイルを選択';

  @override
  String get selectBackupFileDesc =>
      'AnyNoteの暗号化バックアップファイル（.enc）を選択してデータを復元してください。';

  @override
  String get browseFiles => 'ファイルを選択';

  @override
  String get selectedFile => '選択済みのファイル';

  @override
  String get nextStep => '次へ';

  @override
  String get back => '戻る';

  @override
  String get backupDetails => 'バックアップの詳細';

  @override
  String get backupFormat => 'フォーマット';

  @override
  String get backupVersion => 'バージョン';

  @override
  String get exportDate => 'エクスポート日';

  @override
  String get totalItems => '合計アイテム数';

  @override
  String get itemCounts => 'アイテム数';

  @override
  String get verificationErrors => '検証エラー';

  @override
  String get backupValid => 'バックアップの検証に成功';

  @override
  String get backupInvalid => 'バックアップの検証に失敗';

  @override
  String get unlockToVerify => '暗号化をロック解除してバックアップの内容を検証してください。';

  @override
  String get restorePreviewTitle => '復元プレビュー';

  @override
  String get notesToRestore => 'メモ';

  @override
  String get tagsToRestore => 'タグ';

  @override
  String get collectionsToRestore => 'コレクション';

  @override
  String get contentsToRestore => 'AIコンテンツ';

  @override
  String get earliestDate => '最古';

  @override
  String get latestDate => '最新';

  @override
  String get noConflictsDetected => '競合は検出されませんでした。すべてのアイテムが新規として追加されます。';

  @override
  String get noteTitlesPreview => 'メモタイトル';

  @override
  String andMoreItems(int count) {
    return '他$count件...';
  }

  @override
  String get conflictStrategyTitle => '競合の解決方法';

  @override
  String get conflictStrategyDesc => 'ローカルに既に存在するアイテムの処理方法を選択してください。';

  @override
  String get strategyOverwrite => '上書き';

  @override
  String get strategyOverwriteDesc => 'ローカルのアイテムをバックアップの内容で上書きします';

  @override
  String get strategySkip => 'スキップ';

  @override
  String get strategySkipDesc => 'ローカルのアイテムを保持し、バックアップの重複をスキップします';

  @override
  String get strategyKeepBoth => '両方を保持';

  @override
  String get strategyKeepBothDesc =>
      'バックアップのアイテムを既存のものと並べてインポートします（「（復元済み）」サフィックス付き）';

  @override
  String get restoreWarning => '復元されたアイテムは同期キューに追加されます。しばらく時間がかかる場合があります。';

  @override
  String get startRestore => '復元を開始';

  @override
  String get restoringBackup => 'バックアップを復元中...';

  @override
  String restoreProgress(int current, int total) {
    return '$total件中$current件を処理中';
  }

  @override
  String get restoreCompleted => '復元が完了しました';

  @override
  String get restoreCompletedWithErrors => '復元は完了しましたが、一部エラーがあります';

  @override
  String get restoreResults => '結果';

  @override
  String get itemsRestored => '復元済み';

  @override
  String get itemsSkipped => 'スキップ';

  @override
  String get conflictsFound => '競合';

  @override
  String get errorsDuringRestore => 'エラー';

  @override
  String conflictsDetected(int count) {
    return '$count件のアイテムがローカルに既に存在します';
  }

  @override
  String existingNotesCount(int count) {
    return '$count件のメモ';
  }

  @override
  String existingTagsCount(int count) {
    return '$count件のタグ';
  }

  @override
  String existingCollectionsCount(int count) {
    return '$count件のコレクション';
  }

  @override
  String existingContentsCount(int count) {
    return '$count件のAIコンテンツ';
  }

  @override
  String filePickerError(String error) {
    return 'ファイル選択を開けませんでした: $error';
  }

  @override
  String get restoreFromBackupDesc => '暗号化バックアップファイルからデータを復元';

  @override
  String get importNotesDesc => 'Markdown、Appleメモ、またはプレーンテキストからインポート';

  @override
  String get onboardingWriteTitle => '思いついたことを書き留めよう';

  @override
  String get onboardingWriteDesc => 'どの端末でもメモを作成 — コンテンツは安全に暗号化されます';

  @override
  String get japanese => '日本語';

  @override
  String get korean => '한국어';

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
}

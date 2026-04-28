// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AnyNote';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get signInToVault => '登录你的加密保险库';

  @override
  String get email => '邮箱';

  @override
  String get emailRequired => '请输入邮箱';

  @override
  String get password => '密码';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get signIn => '登录';

  @override
  String get noAccountRegister => '没有账号？注册';

  @override
  String get recoverFromBackup => '从备份恢复';

  @override
  String get noEncryptionKeys => '未找到加密密钥，请先注册。';

  @override
  String get invalidEmailOrPassword => '邮箱或密码错误。';

  @override
  String get accountNotFoundRegister => '账号不存在，请先注册。';

  @override
  String get unableToReachServer => '无法连接服务器，请检查网络。';

  @override
  String get createAccount => '创建账号';

  @override
  String get startEncryptedJourney => '开启你的加密笔记之旅';

  @override
  String get username => '用户名';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordsDoNotMatch => '两次输入的密码不一致';

  @override
  String get passwordMinLength => '密码至少需要8个字符';

  @override
  String get encryptionNotice => '你的数据将使用此密码加密。如果丢失密码，我们无法帮你恢复。';

  @override
  String get alreadyHaveAccount => '已有账号？登录';

  @override
  String get emailOrUsernameTaken => '邮箱或用户名已被注册。';

  @override
  String get invalidInput => '输入无效，请检查填写内容。';

  @override
  String get saveRecoveryKey => '保存你的恢复密钥';

  @override
  String get recoveryKeyInstructions => '请将此恢复密钥保存在安全的地方。忘记密码时需要用它来恢复数据。';

  @override
  String get copyRecoveryKey => '复制恢复密钥';

  @override
  String get recoveryKeyCopied => '恢复密钥已复制到剪贴板';

  @override
  String get iSavedIt => '我已保存';

  @override
  String get recoverAccount => '恢复账号';

  @override
  String get recoverAccountInstructions => '输入你的12词恢复密钥，在此设备上恢复你的加密保险库。';

  @override
  String get recoveryKeyLabel => '恢复密钥（12个词）';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get recoveryKeyRequired => '请输入恢复密钥';

  @override
  String get recoveryKeyWordCount => '恢复密钥必须为12个词';

  @override
  String get recoveryKeyFormatHint => '请按正确顺序输入12个词，以空格分隔。';

  @override
  String get invalidRecoveryKey => '恢复密钥无效，请检查输入。';

  @override
  String get invalidRecoveryKeyForAccount => '该恢复密钥与此账号不匹配。';

  @override
  String get accountNotFoundCheckEmail => '账号不存在，请检查邮箱地址。';

  @override
  String get backToSignIn => '返回登录';

  @override
  String get skip => '跳过';

  @override
  String get next => '下一步';

  @override
  String get getStarted => '开始使用';

  @override
  String get onboardingPrivacyTitle => '你的笔记，你的隐私';

  @override
  String get onboardingPrivacyDesc =>
      'AnyNote 在每条笔记到达云端之前都会在你的设备上进行加密。任何人——包括我们自己——都无法读取你的笔记。';

  @override
  String get onboardingMasterPasswordTitle => '主密码';

  @override
  String get onboardingMasterPasswordDesc =>
      '设置一个主密码来派生你的加密密钥。请务必记住——没有恢复密钥将无法重置密码。';

  @override
  String get onboardingRecoveryKeyTitle => '恢复密钥';

  @override
  String get onboardingRecoveryKeyDesc =>
      '你将获得一个12词恢复密钥。请妥善保存——这是忘记密码后恢复笔记的唯一方式。';

  @override
  String get onboardingAITitle => 'AI 智能写作';

  @override
  String get onboardingAIDesc => '使用 AI 来撰写、提纲和改编你的笔记，适配任何平台。你的内容绝不会被记录。';

  @override
  String get searchNotes => '搜索笔记...';

  @override
  String get collections => '合集';

  @override
  String get sortNotes => '排序';

  @override
  String get updatedNewest => '按更新时间（最新）';

  @override
  String get updatedOldest => '按更新时间（最早）';

  @override
  String get createdNewest => '按创建时间（最新）';

  @override
  String get createdOldest => '按创建时间（最早）';

  @override
  String get titleAZ => '按标题 A-Z';

  @override
  String get sortCustom => '自定义排序';

  @override
  String get reorderModeHint => '拖拽笔记以重新排序';

  @override
  String get listView => '列表视图';

  @override
  String get gridView => '网格视图';

  @override
  String get advancedSearch => '高级搜索';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get searchNotesTooltip => '搜索笔记';

  @override
  String get createNewNote => '创建新笔记';

  @override
  String get noNotesYet => '还没有笔记';

  @override
  String get tapToCapture => '点击 + 创建你的第一条笔记';

  @override
  String get newNote => '新建笔记';

  @override
  String get noResults => '没有结果';

  @override
  String get tryDifferentSearch => '试试其他搜索词';

  @override
  String get deleteNoteQuestion => '删除笔记？';

  @override
  String deleteNoteConfirm(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get noteDeleted => '笔记已删除';

  @override
  String get undo => '撤销';

  @override
  String get unpinNote => '取消置顶';

  @override
  String get pinNote => '置顶笔记';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get blankNote => '空白笔记';

  @override
  String get fromTemplate => '从模板创建';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String get untitled => '无标题';

  @override
  String get versionHistory => '版本历史';

  @override
  String get editNote => '编辑笔记';

  @override
  String get exportOrShare => '导出或分享';

  @override
  String get shareViaLink => '通过链接分享';

  @override
  String get exportAsMarkdown => '导出为 Markdown';

  @override
  String get exportAsHTML => '导出为 HTML';

  @override
  String get exportAsPlainText => '导出为纯文本';

  @override
  String get failedToLoadNote => '加载笔记失败';

  @override
  String get retry => '重试';

  @override
  String get noteNotFound => '笔记未找到';

  @override
  String get notSynced => '未同步';

  @override
  String get couldNotLoadForExport => '无法加载笔记以导出';

  @override
  String get deleteNoteDialog => '删除笔记';

  @override
  String get deleteNoteDialogMessage => '此笔记将被移至回收站，你可以稍后恢复。';

  @override
  String get title => '标题';

  @override
  String get startWriting => '开始写作...';

  @override
  String get saveAndClose => '保存并关闭';

  @override
  String get savingNote => '正在保存';

  @override
  String get plainText => '纯文本';

  @override
  String get richText => '富文本';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get manageTags => '管理标签';

  @override
  String get addImage => '添加图片';

  @override
  String get noteContent => '笔记内容';

  @override
  String get tags => '标签';

  @override
  String get closeTagPicker => '关闭标签选择器';

  @override
  String get newTagName => '新标签名称';

  @override
  String get add => '添加';

  @override
  String get noTagsYet => '还没有标签，请在上方创建。';

  @override
  String failedToAddImage(String error) {
    return '添加图片失败：$error';
  }

  @override
  String get restore => '恢复';

  @override
  String get close => '关闭';

  @override
  String get restoreVersion => '恢复此版本';

  @override
  String restoreVersionConfirm(int version) {
    return '恢复笔记到版本 $version？当前内容将保存为新版本。';
  }

  @override
  String get versionRestored => '版本已恢复';

  @override
  String failedToRestore(String error) {
    return '恢复失败：$error';
  }

  @override
  String get failedToLoadVersions => '加载版本失败';

  @override
  String get noVersionsYet => '暂无版本';

  @override
  String get versionsSavedAutomatically => '编辑笔记时会自动保存版本。';

  @override
  String get current => '当前';

  @override
  String get settings => '设置';

  @override
  String get account => '账号';

  @override
  String get plan => '套餐';

  @override
  String get upgrade => '升级';

  @override
  String get loading => '加载中...';

  @override
  String get unableToLoadAccountInfo => '无法加载账号信息';

  @override
  String get aiSection => 'AI';

  @override
  String get llmConfiguration => 'LLM 配置';

  @override
  String get configureAIProviders => '配置你的 AI 提供商';

  @override
  String get aiQuota => 'AI 配额';

  @override
  String requestsToday(int used, int limit) {
    return '今日已使用 $used/$limit 次请求';
  }

  @override
  String get unableToLoadQuota => '无法加载配额';

  @override
  String get publishing => '发布';

  @override
  String get platformConnections => '平台连接';

  @override
  String get manageConnectedPlatforms => '管理已连接的平台';

  @override
  String get securityPrivacy => '安全与隐私';

  @override
  String get encryptionSettings => '加密设置';

  @override
  String get e2eEncryptionActive => '端到端加密已启用';

  @override
  String get sync => '同步';

  @override
  String get syncStatus => '同步状态';

  @override
  String get lastSyncedNever => '上次同步：从未';

  @override
  String lastSynced(String time) {
    return '上次同步：$time';
  }

  @override
  String get checking => '检查中...';

  @override
  String get unableToLoadSyncStatus => '无法加载同步状态';

  @override
  String get syncNow => '立即同步';

  @override
  String syncCompleteWithConflicts(int count) {
    return '同步完成，$count 个冲突';
  }

  @override
  String synced(int pulled, int pushed) {
    return '已同步：拉取 $pulled 条，推送 $pushed 条';
  }

  @override
  String get data => '数据';

  @override
  String get exportAllNotes => '导出所有笔记';

  @override
  String get exportAllNotesDesc => '将所有笔记导出为文件';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get htmlFormat => 'HTML (.html)';

  @override
  String get plainTextFormat => '纯文本 (.txt)';

  @override
  String get noNotesToExport => '没有可导出的笔记';

  @override
  String get noNotesWithContent => '没有包含内容的笔记可导出';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutConfirmTitle => '退出登录';

  @override
  String get signOutConfirmMessage => '确定要退出登录吗？你将需要重新登录才能访问你的笔记。';

  @override
  String signOutFailed(String error) {
    return '退出失败：$error';
  }

  @override
  String get securityEncryption => '安全与加密';

  @override
  String get e2eEncryptionActiveStatus => '端到端加密已启用';

  @override
  String get encryptionNotSetUp => '加密尚未设置';

  @override
  String get encryptionAlgorithm => '你的数据使用 XChaCha20-Poly1305 加密';

  @override
  String get keyDerivation => '密钥派生：Argon2id';

  @override
  String get masterKeyUnlocked => '主密钥：已解锁';

  @override
  String get masterKeyLocked => '主密钥：已锁定';

  @override
  String get encryptedItems => '已加密项目';

  @override
  String get notes => '笔记';

  @override
  String get tagsLabel => '标签';

  @override
  String get collectionsLabel => '合集';

  @override
  String get aiContent => 'AI 内容';

  @override
  String itemsCount(int count) {
    return '$count 项';
  }

  @override
  String get recoveryKeySection => '恢复密钥';

  @override
  String get recoveryKeyUsage => '如果你忘记密码，可以使用此密钥恢复数据。';

  @override
  String get viewRecoveryKey => '查看恢复密钥';

  @override
  String get noRecoveryKeyStored => '未存储恢复密钥。';

  @override
  String get recoveryKeyWarning => '恢复密钥在注册时生成。如果你没有保存它，在忘记密码的情况下将无法恢复数据。';

  @override
  String get copyToClipboard => '复制到剪贴板';

  @override
  String get hide => '隐藏';

  @override
  String get failedToLoadRecoveryKey => '加载恢复密钥失败';

  @override
  String get changePassword => '修改密码';

  @override
  String get reEncryptsData => '将使用新密钥重新加密所有数据';

  @override
  String get verifyPassword => '验证密码';

  @override
  String get enterYourPassword => '输入你的密码';

  @override
  String get verify => '验证';

  @override
  String get incorrectPassword => '密码错误';

  @override
  String get verificationFailed => '验证失败';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get reEncryptWarning => '警告：这将重新加密你的所有数据。';

  @override
  String get change => '修改';

  @override
  String get currentPasswordIncorrect => '当前密码错误';

  @override
  String get passwordChangedSuccessfully => '密码修改成功';

  @override
  String failedToChangePassword(String error) {
    return '修改密码失败：$error';
  }

  @override
  String get dangerZone => '危险区域';

  @override
  String get deleteAllLocalData => '删除所有本地数据';

  @override
  String get exportEncryptedBackup => '导出加密备份';

  @override
  String get importEncryptedBackup => '导入加密备份';

  @override
  String get deleteAllDataQuestion => '删除所有数据？';

  @override
  String get deleteAllDataMessage => '此操作不可逆。你的所有笔记、标签和设置将被永久删除。';

  @override
  String get deleteEverything => '删除全部';

  @override
  String get areYouAbsolutelySure => '你确定吗？';

  @override
  String get typeDeleteToConfirm => '输入 DELETE 以确认。';

  @override
  String get typeDelete => '输入 DELETE';

  @override
  String get allLocalDataDeleted => '所有本地数据已删除';

  @override
  String failedToDeleteData(String error) {
    return '删除数据失败：$error';
  }

  @override
  String get importBackup => '导入备份';

  @override
  String get importBackupMessage => '将从备份文件中导入项目。已有项目不会被覆盖。继续？';

  @override
  String get import => '导入';

  @override
  String importedItemsFromBackup(int count) {
    return '已从备份导入 $count 项';
  }

  @override
  String backupExportFailed(String error) {
    return '备份导出失败：$error';
  }

  @override
  String backupImportFailed(String error) {
    return '备份导入失败：$error';
  }

  @override
  String get llmConfigTitle => 'LLM 配置';

  @override
  String get noLLMConfigs => '没有 LLM 配置';

  @override
  String get addLLMToEnableAI => '添加 LLM 以启用 AI 功能';

  @override
  String get addProvider => '添加提供商';

  @override
  String get defaultLabel => '默认';

  @override
  String get testConnection => '测试连接';

  @override
  String get failedToLoadConfigs => '加载配置失败';

  @override
  String get addLLMProvider => '添加 LLM 提供商';

  @override
  String get name => '名称';

  @override
  String get provider => '提供商';

  @override
  String get baseUrl => '接口地址';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get model => '模型';

  @override
  String get modelHint => '例如 gpt-4o';

  @override
  String get save => '保存';

  @override
  String get editLLMProvider => '编辑 LLM 提供商';

  @override
  String get newApiKeyHint => '新 API 密钥（留空则保持不变）';

  @override
  String get testingConnection => '正在测试连接...';

  @override
  String get connectionSuccessful => '连接成功';

  @override
  String connectionFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String deleteConfigQuestion(String name) {
    return '删除 $name？';
  }

  @override
  String get removeLLMConfigConfirm => '确定要删除此 LLM 配置吗？';

  @override
  String get noPlatformsAvailable => '暂无可用平台';

  @override
  String get platformConnectionsWillAppear => '平台连接将显示在这里';

  @override
  String get failedToLoadPlatforms => '加载平台失败';

  @override
  String get connect => '连接';

  @override
  String get verifyButton => '验证';

  @override
  String get disconnect => '断开连接';

  @override
  String connectedTo(String name) {
    return '已连接到 $name';
  }

  @override
  String failedToConnect(String error) {
    return '连接失败：$error';
  }

  @override
  String get verifyingConnection => '正在验证连接...';

  @override
  String get connectionVerified => '连接验证通过';

  @override
  String connectionInvalid(String error) {
    return '连接无效：$error';
  }

  @override
  String verificationFailedError(String error) {
    return '验证失败：$error';
  }

  @override
  String disconnectPlatform(String name) {
    return '断开 $name 的连接';
  }

  @override
  String disconnectPlatformConfirm(String name) {
    return '确定要断开你的 $name 账号连接吗？';
  }

  @override
  String disconnectedFrom(String name) {
    return '已断开与 $name 的连接';
  }

  @override
  String failedToDisconnect(String error) {
    return '断开连接失败：$error';
  }

  @override
  String get scanQRCode => '扫描二维码';

  @override
  String scanQRInstructions(String platform) {
    return '打开 $platform 应用并扫描此二维码登录';
  }

  @override
  String get done => '完成';

  @override
  String get tagsTitle => '标签';

  @override
  String get noTags => '没有标签';

  @override
  String get createTagsToOrganize => '创建标签来管理你的笔记';

  @override
  String get newTag => '新建标签';

  @override
  String get tagName => '标签名称';

  @override
  String get tagNameHint => '例如：灵感、工作、个人';

  @override
  String get create => '创建';

  @override
  String get encrypted => '（已加密）';

  @override
  String get aiCompose => 'AI 写作';

  @override
  String get aiPoweredWriting => 'AI 智能写作';

  @override
  String get aiComposeDesc => '选择你的笔记，让 AI 帮你创作适配任何平台的精炼内容。';

  @override
  String get startComposing => '开始写作';

  @override
  String get recentCompositions => '最近创作';

  @override
  String get noCompositionsYet => '还没有创作';

  @override
  String get newComposition => '新创作';

  @override
  String get topicOrTheme => '主题';

  @override
  String get topicHint => '创作的内容主题是什么？';

  @override
  String get targetPlatform => '目标平台';

  @override
  String get selectNotes => '选择笔记';

  @override
  String selectedCount(int count) {
    return '已选 $count 篇';
  }

  @override
  String get noNotesAvailableCreate => '暂无笔记。请先创建一篇笔记。';

  @override
  String get contentPreview => '内容预览';

  @override
  String get noContent => '（无内容）';

  @override
  String get copy => '复制';

  @override
  String get saveAsNote => '保存为笔记';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get savedAsNote => '已保存为笔记';

  @override
  String get publish => '发布';

  @override
  String get connectedPlatforms => '已连接平台';

  @override
  String get noPlatformsConnected => '尚未连接平台';

  @override
  String get connectAPlatform => '连接平台';

  @override
  String get publishContent => '发布内容';

  @override
  String get content => '内容';

  @override
  String get tagsCommaSeparated => '标签（逗号分隔）';

  @override
  String get tagsHint => '标签1, 标签2, 标签3';

  @override
  String get selectPlatformToPublish => '请在上方选择一个平台以发布';

  @override
  String publishedStatus(String status) {
    return '已发布！状态：$status';
  }

  @override
  String get titleAndContentRequired => '标题和内容为必填项';

  @override
  String get publishRequestSubmitted => '发布请求已提交';

  @override
  String get recentPublications => '最近发布';

  @override
  String get noPublicationsYet => '暂无发布';

  @override
  String viewAll(int count) {
    return '查看全部（$count）';
  }

  @override
  String get publishHistory => '发布历史';

  @override
  String get filterByStatus => '按状态筛选';

  @override
  String get all => '全部';

  @override
  String get published => '已发布';

  @override
  String get failed => '失败';

  @override
  String get publishingStatus => '发布中';

  @override
  String get pending => '等待中';

  @override
  String noPublicationsWithStatus(String status) {
    return '没有$status的发布';
  }

  @override
  String get clearFilter => '清除筛选';

  @override
  String get noPublications => '暂无发布';

  @override
  String get publishedContentWillAppear => '已发布的内容将显示在这里';

  @override
  String get failedToLoadPublishHistory => '加载发布历史失败';

  @override
  String get viewDetails => '查看详情';

  @override
  String get platform => '平台';

  @override
  String get status => '状态';

  @override
  String get created => '创建时间';

  @override
  String get publishedDate => '发布时间';

  @override
  String get url => '链接';

  @override
  String get error => '错误';

  @override
  String get contentLabel => '内容';

  @override
  String failedToLoadDetail(String error) {
    return '加载详情失败：$error';
  }

  @override
  String get collectionsTitle => '合集';

  @override
  String get noCollectionsYet => '还没有合集';

  @override
  String get groupNotesIntoCollections => '将笔记分组到合集中';

  @override
  String get newCollection => '新建合集';

  @override
  String get deleteCollectionQuestion => '删除合集？';

  @override
  String deleteCollectionConfirm(String title) {
    return '确定要删除「$title」吗？合集中的笔记不会被删除。';
  }

  @override
  String get collectionDeleted => '合集已删除';

  @override
  String get untitledCollection => '无标题合集';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 篇笔记',
    );
    return '$_temp0';
  }

  @override
  String get collectionTitle => '合集标题';

  @override
  String get collectionTitleHint => '输入此合集的名称';

  @override
  String get collectionNotFound => '合集未找到';

  @override
  String get failedToLoadCollection => '加载合集失败';

  @override
  String get noNotesInCollection => '此合集中没有笔记';

  @override
  String get tapToAddNotes => '点击 + 添加笔记';

  @override
  String get addNotes => '添加笔记';

  @override
  String get removeFromCollection => '从合集中移除？';

  @override
  String removeNoteConfirm(String title) {
    return '将「$title」从此合集中移除？笔记不会被删除。';
  }

  @override
  String get remove => '移除';

  @override
  String get renameCollection => '重命名合集';

  @override
  String get renameCollectionTooltip => '重命名合集';

  @override
  String get deleteCollectionTooltip => '删除合集';

  @override
  String get deleteCollectionDialogTitle => '删除合集';

  @override
  String get deleteCollectionDialogMessage => '此合集及其所有笔记关联将被移除。笔记本身不会被删除。';

  @override
  String get noNotesAvailable => '暂无可用笔记';

  @override
  String get removeFromCollectionTooltip => '从合集中移除';

  @override
  String get search => '搜索';

  @override
  String get clearAllFilters => '清除所有筛选';

  @override
  String get searchYourNotes => '搜索你的笔记';

  @override
  String get enterQueryOrFilters => '输入关键词或使用筛选条件查找笔记';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearAll => '清除全部';

  @override
  String get noResultsFound => '未找到结果';

  @override
  String get tryAdjustingSearch => '尝试调整搜索条件';

  @override
  String searchError(String error) {
    return '搜索出错：$error';
  }

  @override
  String get dateRange => '日期范围';

  @override
  String get tagsFilter => '标签';

  @override
  String get collectionsFilter => '合集';

  @override
  String tagsCount(int count) {
    return '$count 个标签';
  }

  @override
  String collectionsCount(int count) {
    return '$count 个合集';
  }

  @override
  String resultsCount(String count) {
    return '$count 条结果';
  }

  @override
  String get noTagsAvailable => '暂无可用标签';

  @override
  String get noCollectionsAvailable => '暂无可用合集';

  @override
  String get selectTags => '选择标签';

  @override
  String get apply => '应用';

  @override
  String get selectCollections => '选择合集';

  @override
  String get shareNote => '分享此笔记';

  @override
  String get passwordProtection => '密码保护';

  @override
  String get requirePassword => '需要密码';

  @override
  String get requirePasswordDesc => '接收者需要输入密码才能查看';

  @override
  String get expiresAfter => '过期时间';

  @override
  String get oneHour => '1 小时';

  @override
  String get twentyFourHours => '24 小时';

  @override
  String get sevenDays => '7 天';

  @override
  String get never => '永不过期';

  @override
  String get passwordRequiredForShare => '启用密码保护时必须设置密码';

  @override
  String failedToCreateShareLink(String error) {
    return '创建分享链接失败：$error';
  }

  @override
  String get linkCopiedToClipboard => '链接已复制到剪贴板';

  @override
  String get copyLink => '复制链接';

  @override
  String get passwordProtectedShareInfo => '此链接受密码保护，请单独分享密码。';

  @override
  String get publicShareInfo => '任何拥有此链接的人都可以查看此笔记。';

  @override
  String linkExpiresIn(String expiry) {
    return '链接将于 $expiry 后过期';
  }

  @override
  String get encrypting => '加密中...';

  @override
  String get createShareLink => '创建分享链接';

  @override
  String get language => '语言';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get languageChangedNotice => '语言更改将在重启应用后生效';

  @override
  String get zenMode => '专注模式';

  @override
  String get enterZenMode => '进入专注模式';

  @override
  String get exitZenMode => '退出专注模式';

  @override
  String wordCount(int count) {
    return '$count 个字';
  }

  @override
  String charCount(int count) {
    return '$count 个字符';
  }

  @override
  String get importNotes => '导入笔记';

  @override
  String get importMarkdown => '导入 Markdown';

  @override
  String get importTextFiles => '导入文本文件';

  @override
  String get importAppleNotes => '导入 Apple Notes';

  @override
  String importComplete(int count, int skipped) {
    return '导入完成：已导入 $count 条笔记，跳过 $skipped 条';
  }

  @override
  String get markdownPreview => 'Markdown 预览';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get selectBackupFile => '选择备份文件';

  @override
  String get selectBackupFileDesc => '选择 AnyNote 加密备份文件（.enc）来恢复你的数据。';

  @override
  String get browseFiles => '浏览文件';

  @override
  String get selectedFile => '已选文件';

  @override
  String get nextStep => '下一步';

  @override
  String get back => '返回';

  @override
  String get backupDetails => '备份详情';

  @override
  String get backupFormat => '格式';

  @override
  String get backupVersion => '版本';

  @override
  String get exportDate => '导出日期';

  @override
  String get totalItems => '总项目数';

  @override
  String get itemCounts => '项目计数';

  @override
  String get verificationErrors => '验证错误';

  @override
  String get backupValid => '备份验证通过';

  @override
  String get backupInvalid => '备份验证失败';

  @override
  String get unlockToVerify => '请解锁加密以验证备份内容。';

  @override
  String get restorePreviewTitle => '恢复预览';

  @override
  String get notesToRestore => '笔记';

  @override
  String get tagsToRestore => '标签';

  @override
  String get collectionsToRestore => '集合';

  @override
  String get contentsToRestore => 'AI 内容';

  @override
  String get earliestDate => '最早';

  @override
  String get latestDate => '最新';

  @override
  String get noConflictsDetected => '未检测到冲突，所有项目将作为新项目添加。';

  @override
  String get noteTitlesPreview => '笔记标题';

  @override
  String andMoreItems(int count) {
    return '...还有 $count 项';
  }

  @override
  String get conflictStrategyTitle => '冲突处理';

  @override
  String get conflictStrategyDesc => '选择如何处理本地已存在的项目。';

  @override
  String get strategyOverwrite => '覆盖';

  @override
  String get strategyOverwriteDesc => '用备份版本替换本地项目';

  @override
  String get strategySkip => '跳过';

  @override
  String get strategySkipDesc => '保留本地项目，跳过备份中的重复项';

  @override
  String get strategyKeepBoth => '保留两者';

  @override
  String get strategyKeepBothDesc => '导入备份项目并保留现有项目（添加\'(已恢复)\'后缀）';

  @override
  String get restoreWarning => '恢复的项目将排队等待同步，这可能需要一些时间。';

  @override
  String get startRestore => '开始恢复';

  @override
  String get restoringBackup => '正在恢复备份...';

  @override
  String restoreProgress(int current, int total) {
    return '正在处理 $current / $total';
  }

  @override
  String get restoreCompleted => '恢复成功完成';

  @override
  String get restoreCompletedWithErrors => '恢复完成，但有部分错误';

  @override
  String get restoreResults => '结果';

  @override
  String get itemsRestored => '已恢复';

  @override
  String get itemsSkipped => '已跳过';

  @override
  String get conflictsFound => '冲突';

  @override
  String get errorsDuringRestore => '错误';

  @override
  String conflictsDetected(int count) {
    return '$count 个项目已存在于本地';
  }

  @override
  String existingNotesCount(int count) {
    return '$count 条笔记';
  }

  @override
  String existingTagsCount(int count) {
    return '$count 个标签';
  }

  @override
  String existingCollectionsCount(int count) {
    return '$count 个集合';
  }

  @override
  String existingContentsCount(int count) {
    return '$count 个 AI 内容';
  }

  @override
  String filePickerError(String error) {
    return '无法打开文件选择器：$error';
  }

  @override
  String get restoreFromBackupDesc => '从加密备份文件恢复数据';

  @override
  String get importNotesDesc => '从 Markdown、Apple Notes 或纯文本导入';

  @override
  String get onboardingWriteTitle => '写下你的想法';

  @override
  String get onboardingWriteDesc => '在任何设备上创建笔记，你的内容将被安全加密';

  @override
  String get japanese => '日本語';

  @override
  String get korean => '한국어';

  @override
  String get discoverFeed => '发现';

  @override
  String get noPublicNotes => '暂无公开笔记';

  @override
  String get noPublicNotesDesc => '标记为公开的共享笔记将在此处显示。';

  @override
  String get failedToLoadDiscoverFeed => '加载发现页失败';

  @override
  String get encryptedNote => '加密笔记';

  @override
  String get reactionFailed => '操作失败';

  @override
  String monthsAgo(int count) {
    return '$count个月前';
  }

  @override
  String get menuFile => '文件';

  @override
  String get menuNewNote => '新建笔记';

  @override
  String get menuSave => '保存';

  @override
  String get menuImport => '导入...';

  @override
  String get menuExport => '导出...';

  @override
  String get menuCloseTab => '关闭标签页';

  @override
  String get menuEdit => '编辑';

  @override
  String get menuUndo => '撤销';

  @override
  String get menuRedo => '重做';

  @override
  String get menuCut => '剪切';

  @override
  String get menuCopy => '复制';

  @override
  String get menuPaste => '粘贴';

  @override
  String get menuSelectAll => '全选';

  @override
  String get menuFind => '查找...';

  @override
  String get menuView => '视图';

  @override
  String get menuToggleSidebar => '切换侧边栏';

  @override
  String get menuTogglePreview => '切换预览';

  @override
  String get menuZenMode => '专注模式';

  @override
  String get menuFullScreen => '进入全屏';

  @override
  String get menuExitFullScreen => '退出全屏';

  @override
  String get menuHelp => '帮助';

  @override
  String get menuAbout => '关于 AnyNote';

  @override
  String get menuKeyboardShortcuts => '键盘快捷键';

  @override
  String get aboutDialogTitle => '关于 AnyNote';

  @override
  String get aboutDescription => '本地优先、隐私优先的端到端加密笔记应用。';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get shortcutsDialogTitle => '键盘快捷键';

  @override
  String get shortcutNewNote => '新建笔记';

  @override
  String get shortcutSave => '保存';

  @override
  String get shortcutSearch => '搜索';

  @override
  String get shortcutToggleSidebar => '切换侧边栏';

  @override
  String get shortcutExportPdf => '导出为 PDF';

  @override
  String get shortcutSettings => '打开设置';

  @override
  String get shortcutCloseNote => '关闭笔记';

  @override
  String get shortcutNextNote => '下一条笔记';

  @override
  String get shortcutFullScreen => '切换全屏';

  @override
  String get shortcutExitZen => '退出专注模式 / 关闭对话框';

  @override
  String get notesTabLabel => '笔记';

  @override
  String get composeTabLabel => '创作';

  @override
  String get publishTabLabel => '发布';

  @override
  String get settingsTabLabel => '设置';

  @override
  String versionSemanticLabel(
      int versionNumber, String title, String date, String currentSuffix) {
    return '版本 $versionNumber，$title，$date$currentSuffix';
  }

  @override
  String get currentSuffix => '，当前';

  @override
  String noteTitleLabel(String title) {
    return '笔记标题：$title';
  }

  @override
  String updatedDate(String date) {
    return '更新于 $date';
  }

  @override
  String get confirmDeleteNoteDialog => '确认删除笔记对话框';

  @override
  String get expiryImmediately => '已过期';

  @override
  String get expiryLessThanOneHour => '不到1小时后';

  @override
  String expiryInHours(int count) {
    return '$count小时后';
  }

  @override
  String expiryInDays(int count) {
    return '$count天后';
  }

  @override
  String compositionSemanticLabel(
      String title, String time, String platformSuffix) {
    return '作品：$title。$time$platformSuffix';
  }

  @override
  String platformSuffix(String platform) {
    return '。平台：$platform';
  }

  @override
  String get platformGeneric => '通用';

  @override
  String get platformXhs => '小红书';

  @override
  String get platformTwitter => 'Twitter';

  @override
  String get platformBlog => '博客';

  @override
  String get platformLinkedin => 'LinkedIn';

  @override
  String get noteClusters => '笔记聚类';

  @override
  String get clusteringNotes => '正在聚类您的笔记...';

  @override
  String analyzingNotes(int count, String topic) {
    return 'AI正在分析$count条关于\"$topic\"的笔记';
  }

  @override
  String foundThemesSelect(int count) {
    return 'AI发现了$count个主题，请选择要包含的主题。';
  }

  @override
  String notesCount(int count) {
    return '$count条笔记';
  }

  @override
  String clustersSelected(int count) {
    return '已选择$count个聚类';
  }

  @override
  String get generateOutline => '生成大纲';

  @override
  String get editorTitle => '编辑器';

  @override
  String adaptStyleFor(String platform) {
    return '为$platform调整风格';
  }

  @override
  String get saveNoteTooltip => '保存为笔记';

  @override
  String get aiWriting => 'AI正在撰写...';

  @override
  String charsCount(int count) {
    return '$count字符';
  }

  @override
  String get compositionHint => '您的作品将显示在此处...';

  @override
  String get outlineButton => '大纲';

  @override
  String wordsCount(int count) {
    return '$count词';
  }

  @override
  String get viewAction => '查看';

  @override
  String get failedToSaveNote => '保存笔记失败';

  @override
  String get outlineTitle => '大纲';

  @override
  String get editTitleTooltip => '编辑标题';

  @override
  String get generatingOutline => '正在生成大纲...';

  @override
  String buildingStructureFromClusters(int count) {
    return '正在从$count个聚类构建结构';
  }

  @override
  String get noOutlineGenerated => '未生成大纲。';

  @override
  String sectionsDragToReorder(int count) {
    return '$count个章节 -- 拖动以重新排序';
  }

  @override
  String get keyPoints => '要点：';

  @override
  String fromCluster(int number) {
    return '来自聚类 $number';
  }

  @override
  String get expandToDraft => '展开为草稿';

  @override
  String get editTitle => '编辑标题';

  @override
  String get loginScreenLabel => 'AnyNote登录界面';

  @override
  String errorLabel(String message) {
    return '错误：$message';
  }

  @override
  String get registrationScreenLabel => 'AnyNote注册界面';

  @override
  String get keyDerivationFailed => '密钥派生失败，请重试。';

  @override
  String get demoSecretNote => '我的秘密笔记...';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get selectNoteToView => '选择一条笔记以查看';

  @override
  String get collectionFallback => '集合';

  @override
  String get unknown => '未知';

  @override
  String get freePlan => '免费';

  @override
  String get importMarkdownDesc =>
      '导入带有可选YAML前置信息的Markdown（.md）文件。支持的前置信息字段：标题、日期和标签。如果未指定，将使用文件名作为标题。';

  @override
  String get sourceHeader => '来源';

  @override
  String get selectFiles => '选择文件';

  @override
  String get selectMdFilesSubtitle => '选择一个或多个.md文件';

  @override
  String get selectFolder => '选择文件夹';

  @override
  String get importMdFolderSubtitle => '从文件夹导入所有.md文件';

  @override
  String get selectMdFilesTitle => '选择Markdown文件';

  @override
  String get noMdFilesSelected => '未选择.md文件。';

  @override
  String get notSupportedOnWeb => '此功能在网页端不支持。';

  @override
  String get selectMdFolderTitle => '选择包含Markdown文件的文件夹';

  @override
  String get appleNotesExportHeader => 'Apple备忘录导出';

  @override
  String get appleNotesImportDesc =>
      '导入从Apple备忘录应用导出的笔记。选择一个包含从Apple备忘录导出的HTML文件的文件夹（每个文件对应一条笔记）。基本格式（粗体、斜体、标题、列表）将被转换为Markdown。';

  @override
  String get selectAppleNotesFolderSubtitle => '选择包含Apple备忘录HTML文件的文件夹';

  @override
  String get selectAppleNotesFolderTitle => '选择Apple备忘录导出文件夹';

  @override
  String get plainTextFilesHeader => '纯文本文件';

  @override
  String get plainTextImportDesc =>
      '导入纯文本（.txt）文件作为笔记。每个文件的第一行将成为笔记标题（如果少于100个字符），否则使用文件名作为标题。';

  @override
  String get selectTxtFilesSubtitle => '选择一个或多个.txt文件';

  @override
  String get importTxtFolderSubtitle => '从文件夹导入所有.txt文件';

  @override
  String get selectTextFilesTitle => '选择文本文件';

  @override
  String get noTxtFilesSelected => '未选择.txt文件。';

  @override
  String get selectTextFolderTitle => '选择包含文本文件的文件夹';

  @override
  String fileCount(int count) {
    return '$count个文件';
  }

  @override
  String andMoreErrors(int count) {
    return '...以及另外$count个错误';
  }

  @override
  String get stepFile => '文件';

  @override
  String get stepVerify => '验证';

  @override
  String get stepPreview => '预览';

  @override
  String get stepStrategy => '策略';

  @override
  String get stepRestore => '恢复';

  @override
  String get decryptFailed => '无法解密共享笔记，链接可能已损坏或过期。';

  @override
  String get decryptingSharedNote => '正在解密共享笔记...';

  @override
  String get couldNotDecryptSharedNote => '无法解密共享笔记';

  @override
  String get linkCorruptedExpired => '链接可能已损坏、过期或不完整。';

  @override
  String get passwordRequiredTitle => '需要密码';

  @override
  String get enterPasswordToView => '输入密码以查看此共享笔记。';

  @override
  String get unlock => '解锁';

  @override
  String get sharedViaLink => '通过链接共享';

  @override
  String get sharedNote => '共享笔记';

  @override
  String platformSemanticLabel(
      String name, String subtitleSuffix, String selectedSuffix) {
    return '平台：$name$subtitleSuffix$selectedSuffix';
  }

  @override
  String publishedSemanticLabel(
      String title, String platform, String status, String dateSuffix) {
    return '已发布：$title。平台：$platform。状态：$status$dateSuffix';
  }

  @override
  String get openInBrowser => '在浏览器中打开已发布文章';

  @override
  String statusLabel(String status) {
    return '状态：$status';
  }

  @override
  String get selectedLabel => '已选择';

  @override
  String dateRangeFormat(String start, String end) {
    return '$start - $end';
  }

  @override
  String get builtInTab => '内置';

  @override
  String get myTemplatesTab => '我的模板';

  @override
  String get deleteTemplateConfirm => '删除模板？';

  @override
  String deleteTemplateMessage(String name) {
    return '删除\"$name\"？此操作无法撤销。';
  }

  @override
  String get templateNameLabel => '模板名称';

  @override
  String get templateDateHint => '使用 [date] 插入当前日期';

  @override
  String get templates => '模板';

  @override
  String get templatePicker => '选择模板';

  @override
  String get createFromTemplate => '从模板创建';

  @override
  String get createFromScratch => '空白创建';

  @override
  String get templateManagement => '模板管理';

  @override
  String get newTemplate => '新建模板';

  @override
  String get editTemplate => '编辑模板';

  @override
  String get deleteTemplate => '删除模板';

  @override
  String get templateName => '模板名称';

  @override
  String get templateDescription => '描述';

  @override
  String get templateContent => '内容';

  @override
  String get templateCategory => '分类';

  @override
  String get categoryWork => '工作';

  @override
  String get categoryPersonal => '个人';

  @override
  String get categoryCreative => '创意';

  @override
  String get builtInTemplates => '内置模板';

  @override
  String get userTemplates => '我的模板';

  @override
  String templateUsed(int count) {
    return '使用 $count 次';
  }

  @override
  String get duplicateTemplate => '复制';

  @override
  String get noTemplates => '暂无模板';

  @override
  String get templateSaved => '模板已保存';

  @override
  String get templateMeetingNotes => '会议笔记';

  @override
  String get templateDailyJournal => '每日日志';

  @override
  String get templateProjectPlan => '项目计划';

  @override
  String get templateReadingNotes => '阅读笔记';

  @override
  String get templateWeeklyReview => '每周回顾';

  @override
  String get templateBrainstorm => '头脑风暴';

  @override
  String get templateBlank => '空白';

  @override
  String get offlineBanner => '您当前离线 — 恢复连接后将自动同步更改';

  @override
  String get unlockRequired => '请先解锁您的保险库';

  @override
  String get selectAnItemToView => '选择一个项目以查看';

  @override
  String get comingSoon => '即将推出';

  @override
  String get comingSoonMessage => '此功能尚未上线，请关注后续更新！';

  @override
  String get dismiss => '关闭';

  @override
  String get errorConnection => '无法连接到服务器，请检查您的网络连接。';

  @override
  String get errorServer => '服务器发生错误，请稍后重试。';

  @override
  String get errorSessionExpired => '您的会话已过期，请重新登录。';

  @override
  String get errorAccessDenied => '您没有权限执行此操作。';

  @override
  String get errorNotFound => '找不到请求的项目。';

  @override
  String get errorRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String errorRateLimitedSeconds(int seconds) {
    return '请求过于频繁，请等待 $seconds 秒后重试。';
  }

  @override
  String get errorConflict => '检测到冲突，请刷新后重试。';

  @override
  String get errorCryptoLocked => '加密密钥已锁定，请先解锁。';

  @override
  String get errorKeyDerivation => '密钥派生失败，请检查您的密码。';

  @override
  String get errorCryptoOperation => '加密操作出错，请重试。';

  @override
  String errorSync(String message) {
    return '同步失败：$message';
  }

  @override
  String get errorStorage => '本地存储出错，请重启应用。';

  @override
  String get errorUnexpected => '发生意外错误，请重试。';

  @override
  String get errorTitleConnection => '连接错误';

  @override
  String get errorTitleServer => '服务器错误';

  @override
  String get errorTitleSessionExpired => '会话过期';

  @override
  String get errorTitleAccessDenied => '访问被拒绝';

  @override
  String get errorTitleNotFound => '未找到';

  @override
  String get errorTitleRateLimited => '请求过频';

  @override
  String get errorTitleInvalidInput => '输入无效';

  @override
  String get errorTitleConflict => '冲突';

  @override
  String get errorTitleCryptoLocked => '加密已锁定';

  @override
  String get errorTitleKeyError => '密钥错误';

  @override
  String get errorTitleCrypto => '加密错误';

  @override
  String get errorTitleSync => '同步错误';

  @override
  String get errorTitleStorage => '存储错误';

  @override
  String get termsOfServiceContent => '服务条款正在起草中。目前，我们的隐私政策适用于 AnyNote 服务的使用。';

  @override
  String get kdfMigrationTitle => '安全升级可用';

  @override
  String get kdfMigrationMessage =>
      '您的加密密钥使用了较旧的、较弱的参数。我们建议升级到更强的密钥派生参数以提高安全性。这需要重新派生您的密钥，请稍候。';

  @override
  String get kdfMigrationUpgrade => '立即升级';

  @override
  String get kdfMigrationSkip => '暂时跳过';

  @override
  String get kdfMigrationInProgress => '正在升级加密参数...';

  @override
  String get kdfMigrationSuccess => '加密参数已成功升级。';

  @override
  String get kdfMigrationFailed => '迁移失败。您可以继续使用，但您的密钥仍使用较旧的参数。';

  @override
  String get crossPlatformWarningTitle => '跨平台加密说明';

  @override
  String get crossPlatformWarningMessage =>
      '在移动端（Android/iOS）加密的笔记无法在网页端解密，反之亦然。这是因为移动端使用 Argon2id，而网页端使用 PBKDF2 进行密钥派生，即使使用相同密码也会产生不同的加密密钥。';

  @override
  String get aiChatAssistant => 'AI 聊天助手';

  @override
  String get aiChatWelcome => '问我任何关于笔记的问题';

  @override
  String get aiChatWelcomeDesc => '选择笔记作为上下文以获得更相关的回答。';

  @override
  String get selectContextNotes => '选择上下文笔记';

  @override
  String contextNotesCount(int count) {
    return '已选择 $count 篇笔记作为上下文';
  }

  @override
  String get newChat => '新对话';

  @override
  String get typeYourMessage => '输入您的消息...';

  @override
  String get smartSummary => '智能摘要';

  @override
  String get summaryPromptDesc => '为您的笔记内容生成简洁的 AI 摘要。';

  @override
  String get generateSummary => '生成摘要';

  @override
  String get replace => '替换';

  @override
  String get aiTagSuggestion => 'AI 标签推荐';

  @override
  String get suggestTags => '推荐';

  @override
  String get analyzingContent => '正在分析内容...';

  @override
  String get tapSuggestTagsDesc => '点击\"推荐\"让 AI 分析您的笔记并推荐标签。';

  @override
  String get selectTagsToApply => '选择要应用的标签：';

  @override
  String applyTags(int count) {
    return '应用 $count 个标签';
  }

  @override
  String get aiTranslation => 'AI 翻译';

  @override
  String get translateTo => '翻译为：';

  @override
  String get translate => '翻译';

  @override
  String get translationWillAppear => '翻译结果将显示在此处...';

  @override
  String get insertBelow => '插入到下方';

  @override
  String get french => '法语';

  @override
  String get german => '德语';

  @override
  String get spanish => '西班牙语';

  @override
  String get writingPolish => '写作润色';

  @override
  String get writingPolishDesc => '修复语法、拼写错误，并提升可读性。';

  @override
  String get checkGrammar => '检查';

  @override
  String get checkingGrammar => '正在检查语法...';

  @override
  String get original => '原文';

  @override
  String get corrected => '已修正';

  @override
  String get reject => '拒绝';

  @override
  String get acceptAll => '全部接受';

  @override
  String get aiFeatures => 'AI 功能';

  @override
  String get planTitle => '方案';

  @override
  String currentPlan(String plan) {
    return '当前方案：$plan';
  }

  @override
  String get planNotesCount => '笔记';

  @override
  String get aiUsage => 'AI 用量';

  @override
  String get storageUsed => '存储';

  @override
  String get unlimited => '无限制';

  @override
  String get comparePlans => '方案对比';

  @override
  String get maxNotes => '最大笔记数';

  @override
  String get aiDailyQuota => 'AI 每日配额';

  @override
  String get storage => '存储空间';

  @override
  String get maxDevices => '最大设备数';

  @override
  String get collaboration => '协作';

  @override
  String get no => '否';

  @override
  String get yes => '是';

  @override
  String get restorePurchase => '恢复购买';

  @override
  String get restorePurchaseComingSoon => '恢复购买功能即将推出。';

  @override
  String get lifetimeMember => '终身会员 -- 所有功能永久解锁。';

  @override
  String get selectPlan => '选择方案';

  @override
  String get proPlanDescription => '无限笔记、每日 500 次 AI 请求、5 GB 存储';

  @override
  String get lifetimePlanDescription => '所有 Pro 功能，永久有效 -- 一次性付款';

  @override
  String get unableToLoadPlan => '无法加载方案信息。';

  @override
  String get profile => '个人资料';

  @override
  String get editPublicProfile => '编辑显示名称和简介';

  @override
  String get profileTitle => '编辑资料';

  @override
  String get displayName => '显示名称';

  @override
  String get displayNameHint => '他人看到的名称';

  @override
  String get bio => '简介';

  @override
  String get bioHint => '介绍一下自己';

  @override
  String get publicProfile => '公开资料';

  @override
  String get publicProfileDesc => '允许他人查看您的资料';

  @override
  String get profileSaved => '资料已保存';

  @override
  String get profileSaveFailed => '保存资料失败';

  @override
  String get unableToLoadProfile => '无法加载个人资料。';

  @override
  String get onboardingSecureNotesTitle => '安全笔记';

  @override
  String get onboardingSecureNotesDesc =>
      '每条笔记在到达云端之前都会在您的设备上进行端到端加密。没有人——甚至我们——能读取您的笔记。';

  @override
  String get onboardingPublishTitle => '多平台发布';

  @override
  String get onboardingPublishDesc => '一键发布到您喜爱的平台，将想法分享给全世界。';

  @override
  String get onboardingCollaborateTitle => '实时协作';

  @override
  String get onboardingCollaborateDesc => '与他人实时协作编辑笔记，更改即时同步到所有设备。';

  @override
  String get noteLinks => '笔记链接';

  @override
  String get backlinks => '反向链接';

  @override
  String get noBacklinks => '暂无反向链接';

  @override
  String get knowledgeGraph => '知识图谱';

  @override
  String get graphEmpty => '暂无链接关系，请先在笔记中添加 [[链接]]';

  @override
  String get aiAgent => 'AI 助手';

  @override
  String get selectAction => '选择操作';

  @override
  String get organizeNotes => '整理笔记';

  @override
  String get summarizeNotes => '总结笔记';

  @override
  String get createNote => '创建笔记';

  @override
  String get agentFailed => '操作失败';

  @override
  String get agentComplete => '操作完成';

  @override
  String get viewBacklinks => '查看反向链接';

  @override
  String get wikiLink => 'Wiki 链接';

  @override
  String get linkToNote => '链接到笔记';

  @override
  String get relatedNotes => '相关笔记';

  @override
  String get noRelatedNotes => '暂无相关笔记';

  @override
  String get startTypingToSearch => '输入以搜索笔记';

  @override
  String get noNotesFound => '未找到笔记';

  @override
  String get backgroundSync => '后台同步';

  @override
  String get backgroundSyncDesc => '在应用关闭时定期同步笔记';

  @override
  String get on => '开';

  @override
  String get off => '关';

  @override
  String get trash => '回收站';

  @override
  String get emptyTrash => '清空回收站';

  @override
  String get emptyTrashConfirm => '确定要永久删除回收站中的所有笔记吗？此操作无法撤销。';

  @override
  String get emptyTrashDone => '回收站已清空';

  @override
  String get noDeletedNotes => '没有已删除的笔记';

  @override
  String get restoreNote => '恢复';

  @override
  String get permanentlyDelete => '永久删除';

  @override
  String deletedAt(String date) {
    return '删除于 $date';
  }

  @override
  String deletedOn(String date) {
    return '删除于 $date';
  }

  @override
  String get trashEmpty => '回收站为空';

  @override
  String get trashEmptyDesc => '您删除的笔记将显示在这里';

  @override
  String permanentlyDeleteNoteConfirm(String title) {
    return '确定要永久删除「$title」吗？';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get batchPin => '置顶';

  @override
  String get batchUnpin => '取消置顶';

  @override
  String get batchDelete => '删除';

  @override
  String get batchAddTags => '添加标签';

  @override
  String selectedNotes(int count) {
    return '已选 $count 项';
  }

  @override
  String deleteSelectedNotes(int count) {
    return '删除 $count 条笔记？';
  }

  @override
  String get deleteSelectedNotesConfirm => '确定要删除所选笔记吗？它们将被移至回收站。';

  @override
  String notesDeleted(int count) {
    return '已将 $count 条笔记移至回收站';
  }

  @override
  String notesPinned(int count) {
    return '已置顶 $count 条笔记';
  }

  @override
  String notesUnpinned(int count) {
    return '已取消置顶 $count 条笔记';
  }

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeHighContrastLight => '高对比度浅色';

  @override
  String get themeHighContrastDark => '高对比度深色';

  @override
  String get reduceMotion => '减少动画';

  @override
  String get reduceMotionDesc => '减少应用中的动画效果';

  @override
  String get reduceMotionSystem => '跟随系统设置';

  @override
  String get reduceMotionOn => '开（动画已禁用）';

  @override
  String get reduceMotionOff => '关（动画已启用）';

  @override
  String get copyInviteCode => '复制邀请码';

  @override
  String get inviteCodeCopied => '邀请码已复制！';

  @override
  String get enterInviteCode => '输入邀请码';

  @override
  String joinSharedNote(String code) {
    return '加入共享笔记：$code';
  }

  @override
  String get e2eSharingNotice => '端到端加密：只有您和您的协作者可以阅读此笔记。';

  @override
  String get anyoneWithCode => '分享此邀请码给他人以协作：';

  @override
  String get shareSecurely => '请通过加密消息应用安全地分享邀请码，以保持端到端加密。';

  @override
  String get nooneInRoom => '没有其他人正在查看';

  @override
  String get onePersonInRoom => '1人正在查看';

  @override
  String multiplePeopleInRoom(int count) {
    return '$count人正在查看';
  }

  @override
  String get propertiesDashboard => '属性仪表板';

  @override
  String get totalNotes => '总笔记数';

  @override
  String get withProperties => '有属性';

  @override
  String get priorityDistribution => '优先级分布';

  @override
  String get noPrioritiesSet => '未设置优先级';

  @override
  String get notesByStatus => '按状态分组的笔记';

  @override
  String get createFirstNoteHint => '创建您的第一条笔记以查看仪表板';

  @override
  String get dailyNotes => '日记';

  @override
  String get dailyNote => '日记';

  @override
  String get todaysNote => '今天的日记';

  @override
  String get createTodaysNote => '创建今天的日记';

  @override
  String get noDailyNote => '这天没有日记';

  @override
  String get openDailyNote => '打开日记';

  @override
  String get goToToday => '今天';

  @override
  String get hasNote => '有笔记';

  @override
  String get calendar => '日历';

  @override
  String get recentDailyNotes => '最近的日记';

  @override
  String get commandPalette => '命令面板';

  @override
  String get commandSearchHint => '输入以搜索笔记和命令...';

  @override
  String get commandRecentNotes => '最近';

  @override
  String get commandNotesSection => '笔记';

  @override
  String get commandActions => '操作';

  @override
  String get commandCreateNewNote => '创建新笔记';

  @override
  String get commandOpenDailyNotes => '打开日记';

  @override
  String get commandOpenGraph => '打开图谱视图';

  @override
  String get commandOpenDashboard => '打开仪表盘';

  @override
  String get commandOpenTrash => '打开回收站';

  @override
  String get commandOpenSettings => '打开设置';

  @override
  String get commandNoResultsFound => '没有找到结果';

  @override
  String get slashHeading1 => '标题 1';

  @override
  String get slashHeading2 => '标题 2';

  @override
  String get slashHeading3 => '标题 3';

  @override
  String get slashBulletList => '无序列表';

  @override
  String get slashNumberedList => '有序列表';

  @override
  String get slashTodoList => '待办列表';

  @override
  String get slashCodeBlock => '代码块';

  @override
  String get slashQuote => '引用';

  @override
  String get slashDivider => '分割线';

  @override
  String get slashTable => '表格';

  @override
  String get slashImage => '图片';

  @override
  String get slashWikilink => 'Wiki 链接';

  @override
  String get slashTransclusion => '内容嵌入';

  @override
  String get slashCallout => '标注';

  @override
  String get slashNoResults => '没有匹配的命令';

  @override
  String get splitView => '分屏视图';

  @override
  String get openInSplitView => '在分屏中打开';

  @override
  String get closeSplitView => '关闭分屏';

  @override
  String get selectNoteForSplit => '选择分屏笔记';

  @override
  String get searchOperators => '搜索操作符';

  @override
  String get searchOperatorTag => 'tag:名称 -- 按标签筛选';

  @override
  String get searchOperatorStatus =>
      'status:todo|in-progress|done|blocked|cancelled';

  @override
  String get searchOperatorPriority => 'priority:high|medium|low';

  @override
  String get searchOperatorDate => 'date:YYYY-MM-DD -- 按日期筛选';

  @override
  String get searchOperatorCollection => 'collection:名称 -- 按集合筛选';

  @override
  String get searchOperatorLinks => 'links:true|false -- 按链接状态筛选';

  @override
  String get searchOperatorsExample => '示例: tag:work status:todo 项目计划';

  @override
  String get savedSearches => '保存的搜索';

  @override
  String get saveSearch => '保存搜索';

  @override
  String get saveSearchName => '搜索名称';

  @override
  String get searchSaved => '搜索已保存';

  @override
  String get deleteSavedSearch => '删除保存的搜索';

  @override
  String deleteSavedSearchConfirm(String name) {
    return '删除\"$name\"？';
  }

  @override
  String get searchHistory => '最近搜索';

  @override
  String get clearSearchHistory => '清除搜索历史';

  @override
  String get noSavedSearches => '还没有保存的搜索';

  @override
  String get saveSearchHint => '搜索后点击书签图标保存';

  @override
  String get noSearchHistory => '没有搜索历史';

  @override
  String get showSearchHints => '显示搜索提示';

  @override
  String get hideSearchHints => '隐藏搜索提示';

  @override
  String get searchNotesHint => '使用操作符搜索: tag:work status:todo ...';

  @override
  String get enterQueryOrOperators => '输入带操作符的查询以查找笔记';

  @override
  String get imageGallery => '图片画廊';

  @override
  String get fromGallery => '从相册选择';

  @override
  String get fromCamera => '拍照';

  @override
  String get selectImageSource => '选择图片来源';

  @override
  String get pasteImage => '粘贴图片';

  @override
  String get deleteImage => '删除图片';

  @override
  String get deleteImageConfirm => '确定要删除此图片吗？';

  @override
  String get imageManagement => '图片管理';

  @override
  String get totalStorage => '总存储';

  @override
  String imageCount(int count) {
    return '$count 张图片';
  }

  @override
  String get orphanedImages => '孤立图片';

  @override
  String get cleanupOrphaned => '清理孤立图片';

  @override
  String cleanupComplete(int count) {
    return '已清理 $count 张孤立图片';
  }

  @override
  String get deleteAllImages => '删除所有图片';

  @override
  String get deleteAllImagesConfirm => '这将删除所有存储的图片。此操作不可撤销。';

  @override
  String get noImagesStored => '没有存储的图片';

  @override
  String get imageDeleted => '图片已删除';

  @override
  String get shareImage => '分享图片';

  @override
  String get compareVersions => '比较版本';

  @override
  String get versionDiff => '版本差异';

  @override
  String linesAdded(int count) {
    return '$count 行新增';
  }

  @override
  String linesRemoved(int count) {
    return '$count 行删除';
  }

  @override
  String get selectTwoVersions => '选择两个版本进行比较';

  @override
  String get noChanges => '无变化';

  @override
  String versionNumber(int number) {
    return '版本 $number';
  }

  @override
  String readingTime(int minutes) {
    return '$minutes 分钟阅读';
  }

  @override
  String get lessThan1Min => '不到1分钟';

  @override
  String lineCount(int count) {
    return '$count 行';
  }

  @override
  String paragraphCount(int count) {
    return '$count 段落';
  }

  @override
  String get focusMode => '专注模式';

  @override
  String get typewriterScroll => '打字机滚动';

  @override
  String get writingStats => '写作统计';

  @override
  String get toggleWritingStats => '切换写作统计';

  @override
  String charCountNoSpaces(int count) {
    return '$count 字符（不含空格）';
  }

  @override
  String get statistics => '统计';

  @override
  String get totalWords => '总字数';

  @override
  String get averageWords => '平均字数/笔记';

  @override
  String get daysActive => '活跃天数';

  @override
  String get last30Days => '近30天';

  @override
  String get writingStreak => '连续写作';

  @override
  String currentStreak(int count) {
    return '当前: $count 天';
  }

  @override
  String longestStreak(int count) {
    return '最长: $count 天';
  }

  @override
  String get monthlyActivity => '每月活动';

  @override
  String get topTags => '热门标签';

  @override
  String get topCollections => '热门集合';

  @override
  String get statusDistribution => '状态分布';

  @override
  String get knowledgeGraphStats => '知识图谱';

  @override
  String get totalLinks => '总链接';

  @override
  String orphanedNotesCount(int count) {
    return '$count 篇孤立笔记';
  }

  @override
  String get mostConnectedNote => '最连接的笔记';

  @override
  String get noStatistics => '暂无统计';

  @override
  String get notesWithProperties => '有属性的笔记';

  @override
  String get notesWithLinks => '有链接的笔记';

  @override
  String get exportNotes => '导出笔记';

  @override
  String get exportingNotes => '正在导出...';

  @override
  String get exportComplete => '导出完成';

  @override
  String get exportSelectedNotes => '导出选中';

  @override
  String get exportCurrentNote => '导出当前笔记';

  @override
  String exportSelected(int count) {
    return '$count 篇选中的笔记';
  }

  @override
  String get exportWithFrontmatter => '带元数据导出';

  @override
  String get exportAsZip => '导出为 ZIP 压缩包';

  @override
  String get includeFrontmatter => '包含元数据（前置信息）';

  @override
  String get frontmatterDesc => '添加包含标签、日期和属性的 YAML 元数据头';

  @override
  String get exportOrganization => '组织方式';

  @override
  String get exportFlat => '平铺';

  @override
  String get exportByDate => '按日期';

  @override
  String get exportByCollection => '按集合';

  @override
  String get exportByTag => '按标签';

  @override
  String notesExported(int count) {
    return '$count 篇笔记已导出';
  }

  @override
  String get importFromMarkdown => '从 Markdown 导入';

  @override
  String get importFromZip => '从 ZIP 导入';

  @override
  String get importFromObsidian => '从 Obsidian 库导入';

  @override
  String get importingNotes => '正在导入笔记...';

  @override
  String notesImported(int count) {
    return '已导入 $count 篇笔记';
  }

  @override
  String get preserveDates => '保留原始日期';

  @override
  String get importTags => '导入标签';

  @override
  String get importProperties => '导入属性';

  @override
  String get noFilesSelected => '未选择文件';

  @override
  String get importOptions => '导入选项';

  @override
  String get quickCapture => '快速记录';

  @override
  String get typeSomething => '输入内容...';

  @override
  String get autoSaved => '已自动保存';

  @override
  String get discardDraft => '丢弃草稿？';

  @override
  String get discardDraftMessage => '未保存的更改将丢失。';

  @override
  String get discard => '丢弃';

  @override
  String get newNoteShortcut => '新建笔记';

  @override
  String get newChecklistShortcut => '新建清单';

  @override
  String get dailyNoteShortcut => '每日笔记';

  @override
  String get sharedToAnynote => '已分享到 AnyNote';

  @override
  String get setPriority => '设置优先级';

  @override
  String get quickCaptureDesc => '快速记录想法';

  @override
  String pendingSync(int count) {
    return '$count 待同步';
  }

  @override
  String syncFailedCount(int count) {
    return '$count 失败';
  }

  @override
  String get syncQueue => '同步队列';

  @override
  String get pendingOperations => '待处理操作';

  @override
  String get failedOperations => '失败操作';

  @override
  String get retryAll => '全部重试';

  @override
  String get clearCompleted => '清除已完成';

  @override
  String operationFailed(String error) {
    return '失败: $error';
  }

  @override
  String get retryingSync => '正在重试同步...';

  @override
  String get queueCleared => '已完成操作已清除';

  @override
  String get noPendingOperations => '没有待处理操作';

  @override
  String noteSemantics(String title) {
    return '笔记：$title';
  }

  @override
  String deleteNoteSemantics(String title) {
    return '删除笔记 $title';
  }

  @override
  String archiveNoteSemantics(String title) {
    return '归档笔记 $title';
  }

  @override
  String pinNoteSemantics(String title) {
    return '置顶笔记 $title';
  }

  @override
  String unpinNoteSemantics(String title) {
    return '取消置顶笔记 $title';
  }

  @override
  String get noteContentEditor => '笔记内容编辑器。双击以编辑。';

  @override
  String graphSummary(int nodeCount, int linkCount) {
    return '$nodeCount 个笔记，$linkCount 个链接';
  }

  @override
  String get pinnedNote => '已置顶';

  @override
  String settingsGroup(String section) {
    return '$section 设置';
  }

  @override
  String restoreNoteSemantics(String title) {
    return '恢复笔记 $title';
  }

  @override
  String permanentlyDeleteNoteSemantics(String title) {
    return '永久删除笔记 $title';
  }

  @override
  String deleteCollectionSemantics(String title) {
    return '删除集合 $title';
  }

  @override
  String calendarDaySemantics(String date, String hasNote) {
    return '$date。$hasNote';
  }

  @override
  String noteCountSemantics(int count) {
    return '$count 条笔记';
  }

  @override
  String get reminder => '提醒';

  @override
  String get setReminder => '设置提醒';

  @override
  String get reminderAt => '提醒时间';

  @override
  String get removeReminder => '取消提醒';

  @override
  String get laterToday => '今天稍后';

  @override
  String get tomorrowMorning => '明天早上';

  @override
  String get nextWeek => '下周';

  @override
  String get noReminders => '暂无提醒';

  @override
  String get recurring => '重复';

  @override
  String get daily => '每天';

  @override
  String get weekly => '每周';

  @override
  String get monthly => '每月';

  @override
  String get reminders => '提醒列表';

  @override
  String get reminderFired => '提醒已触发';

  @override
  String get color => '颜色';

  @override
  String get selectColor => '选择颜色';

  @override
  String get removeColor => '移除颜色';

  @override
  String get noteColor => '笔记颜色';

  @override
  String get customColor => '自定义颜色';

  @override
  String get colorFilter => '按颜色筛选';

  @override
  String get searchOperatorColor => 'color:#RRGGBB 或 color:颜色名 -- 按颜色筛选';

  @override
  String get none => '无';

  @override
  String get compareNotes => '比较笔记';

  @override
  String get selectNotesToCompare => '选择要比较的笔记';

  @override
  String get unifiedView => '统一视图';

  @override
  String get sideBySideView => '并排视图';

  @override
  String get additions => '新增';

  @override
  String get deletions => '删除';

  @override
  String get selectTwoNotes => '请选择两个笔记进行比较';

  @override
  String get noteDiff => '笔记差异';

  @override
  String linesChanged(int added, int removed) {
    return '$added 行新增，$removed 行删除';
  }

  @override
  String get mermaidDiagram => 'Mermaid 图表';

  @override
  String get viewDiagram => '查看图表';

  @override
  String get copyMermaidCode => '复制 Mermaid 代码';

  @override
  String get diagramCopied => '图表代码已复制';

  @override
  String get mermaidTemplate => 'Mermaid 模板';

  @override
  String get insertDiagram => '插入图表';

  @override
  String get slashMermaid => 'Mermaid 图表';

  @override
  String get viewSource => '查看源码';

  @override
  String get diagramError => '图表渲染失败';

  @override
  String get copyDiagramSource => '复制图表源码';

  @override
  String get lockNote => '锁定笔记';

  @override
  String get unlockNote => '解锁笔记';

  @override
  String get noteLocked => '笔记已锁定';

  @override
  String get lockedNoteBanner => '此笔记已锁定，点击解锁';

  @override
  String notesColored(int count) {
    return '$count 个笔记已着色';
  }

  @override
  String colorRemovedFromNotes(int count) {
    return '$count 个笔记已移除颜色';
  }

  @override
  String get batchColor => '批量着色';

  @override
  String get batchLock => '批量锁定';

  @override
  String get batchUnlock => '批量解锁';

  @override
  String notesLocked(int count) {
    return '$count 个笔记已锁定';
  }

  @override
  String notesUnlocked(int count) {
    return '$count 个笔记已解锁';
  }

  @override
  String get moveToCollection => '移至笔记本';

  @override
  String get searchCollections => '搜索笔记本...';

  @override
  String get noCollections => '未找到笔记本';

  @override
  String notesMovedToCollection(int count, String name) {
    return '$count 个笔记已移至「$name」';
  }

  @override
  String noteMovedToCollection(String name) {
    return '笔记已移至「$name」';
  }

  @override
  String get addToCollection => '添加到笔记本';

  @override
  String get scrollToTop => '回到顶部';

  @override
  String get printNote => '打印笔记';

  @override
  String get printPreview => '打印预览';

  @override
  String get includeMetadata => '包含元数据';

  @override
  String get includeImages => '包含图片';

  @override
  String get shareAsHtml => '分享为 HTML';

  @override
  String get exportedAsHtml => '已导出为 HTML';

  @override
  String get foldView => '折叠视图';

  @override
  String get foldAll => '全部折叠';

  @override
  String get unfoldAll => '全部展开';

  @override
  String sectionLines(int count) {
    return '$count 行';
  }

  @override
  String foldedSections(int count) {
    return '$count 个折叠段落';
  }

  @override
  String get toggleFold => '切换折叠';

  @override
  String get tableOfContents => '目录';

  @override
  String get noHeadings => '暂无标题';

  @override
  String headingLevel(int level) {
    return '标题级别 $level';
  }

  @override
  String get readAloud => '朗读';

  @override
  String get stopReading => '停止朗读';

  @override
  String get pauseReading => '暂停';

  @override
  String get resumeReading => '继续';

  @override
  String get readingSpeed => '朗读速度';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get general => '通用';

  @override
  String get editor => '编辑器';

  @override
  String get navigation => '导航';

  @override
  String get shortcutBold => '加粗';

  @override
  String get shortcutItalic => '斜体';

  @override
  String get shortcutStrikethrough => '删除线';

  @override
  String get shortcutUndo => '撤销';

  @override
  String get shortcutRedo => '重做';

  @override
  String get shortcutPrint => '打印';

  @override
  String get shortcutLink => '插入链接';

  @override
  String get shortcutCode => '行内代码';

  @override
  String get shortcutHeading => '切换标题';

  @override
  String get shortcutCommandPalette => '命令面板';

  @override
  String get shortcutFocusMode => '专注模式';

  @override
  String get reminderNotificationTitle => '提醒';

  @override
  String reminderNotificationBody(String title) {
    return '该复习了：$title';
  }

  @override
  String get notificationChannelName => '笔记提醒';

  @override
  String get notificationChannelDescription => '笔记提醒的通知渠道';

  @override
  String get exportPdf => 'PDF';

  @override
  String get generatePdf => '生成 PDF';

  @override
  String get pdfGenerated => 'PDF 已生成';

  @override
  String get sharePdf => '分享 PDF';

  @override
  String get exportFormatPdf => 'PDF 文档';

  @override
  String get snippets => '代码片段';

  @override
  String get snippetTitle => '标题';

  @override
  String get snippetCode => '代码';

  @override
  String get snippetLanguage => '语言';

  @override
  String get snippetDescription => '描述';

  @override
  String get snippetCategory => '分类';

  @override
  String get snippetTags => '标签';

  @override
  String get newSnippet => '新建片段';

  @override
  String get editSnippet => '编辑片段';

  @override
  String get deleteSnippet => '删除片段';

  @override
  String get deleteSnippetConfirm => '确定删除此片段？';

  @override
  String get copyCode => '复制代码';

  @override
  String get codeCopied => '已复制';

  @override
  String get insertSnippet => '插入代码片段';

  @override
  String get noSnippets => '暂无代码片段';

  @override
  String get searchSnippets => '搜索代码片段...';

  @override
  String usageCount(int count) {
    return '已使用 $count 次';
  }

  @override
  String get allLanguages => '所有语言';

  @override
  String get allCategories => '所有分类';

  @override
  String get tagHierarchy => '标签层级';

  @override
  String get createSubTag => '创建子标签';

  @override
  String get moveToParent => '移动到父标签';

  @override
  String get noParent => '无父标签（根级）';

  @override
  String get selectParentTag => '选择父标签';

  @override
  String get expandAll => '全部展开';

  @override
  String get collapseAll => '全部折叠';

  @override
  String userCursor(String name) {
    return '$name 的光标';
  }

  @override
  String get remoteUser => '远程用户';

  @override
  String get dropImageHere => '拖放图片到此处';

  @override
  String get imageAdded => '图片已添加';

  @override
  String get unsupportedFileType => '仅支持图片文件';

  @override
  String get quickNote => '新建笔记';

  @override
  String get quickChecklist => '新建清单';

  @override
  String get quickDailyNote => '每日笔记';

  @override
  String get moreOptions => '更多选项';

  @override
  String get failedToLoadTrash => '加载回收站失败';

  @override
  String failedToRestoreError(String error) {
    return '恢复失败：$error';
  }

  @override
  String failedToDeleteError(String error) {
    return '删除失败：$error';
  }

  @override
  String get deleteProperty => '删除属性';

  @override
  String get removePropertyConfirm => '确定要从此笔记中移除此属性吗？';

  @override
  String get propertiesTitle => '属性';

  @override
  String get noProperties => '暂无属性';

  @override
  String get addCustomMetadata => '为此笔记添加自定义元数据';

  @override
  String get addPropertyButton => '添加属性';

  @override
  String get editProperty => '编辑属性';

  @override
  String get customPropertyTitle => '自定义属性';

  @override
  String get propertyLabel => '属性';

  @override
  String get valueLabel => '值';

  @override
  String get numberLabel => '数字';

  @override
  String get enterValue => '请输入一个值';

  @override
  String get enterNumber => '请输入一个数字';

  @override
  String get selectDateLabel => '选择日期';

  @override
  String get linkManagementTitle => '链接管理';

  @override
  String get outboundLinks => '出站链接';

  @override
  String get deleteLinkTitle => '删除链接';

  @override
  String get removeLinkConfirm => '确定要移除此笔记间的连接吗？';

  @override
  String get noLinksToDisplay => '没有链接可显示。调整筛选条件以查看更多。';

  @override
  String get linksToThisNote => '链接到此笔记';

  @override
  String get thisNoteLinksTo => '此笔记链接到';

  @override
  String get deleteLinkTooltip => '删除链接';

  @override
  String get insertTable => '插入表格';

  @override
  String get dragToSelectTableSize => '拖动以选择表格大小';

  @override
  String get proPlan => '专业版';

  @override
  String get lifetimePlan => '终身版';

  @override
  String get proPrice => '\$4.99/月';

  @override
  String get lifetimePrice => '\$49.99';

  @override
  String get priorityHigh => '高';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityLow => '低';

  @override
  String tagsCountLabel(int count) {
    return '$count 个标签';
  }

  @override
  String get orphanedNotes => '孤立笔记';

  @override
  String get filter => '筛选';

  @override
  String priorityLabel(String priority) {
    return '优先级：$priority';
  }

  @override
  String get noMatchingNotes => '没有匹配的笔记';

  @override
  String get tryChangingFilters => '尝试更改筛选条件';

  @override
  String get filterByProperties => '按属性筛选';

  @override
  String get priority => '优先级';

  @override
  String get viewProperties => '属性';

  @override
  String get noteTitle => '笔记标题';

  @override
  String get dateLabel => '日期';

  @override
  String propertyOf(String name) {
    return '属性：$name';
  }

  @override
  String get insertLabel => '插入';

  @override
  String failedToLoadMore(String error) {
    return '加载更多失败：$error';
  }

  @override
  String get linkCreated => '链接已创建';

  @override
  String failedToCreateLink(String error) {
    return '创建链接失败：$error';
  }

  @override
  String get suggestedLinks => '推荐链接';

  @override
  String get similarContentDesc => '标题或内容相似的笔记。点击创建链接。';

  @override
  String get noSuggestions => '暂无推荐';

  @override
  String get createMoreNotes => '创建更多笔记以获取推荐。';

  @override
  String get notAvailableOnWeb => '此功能在网页端不可用';

  @override
  String get okButton => '确定';

  @override
  String get failedToLoadDeferred => '加载失败';

  @override
  String get somethingWentWrong => '出了点问题';

  @override
  String get syncStatusTitle => '同步状态';

  @override
  String get offlineLabel => '离线';

  @override
  String get connectedLabel => '已连接';

  @override
  String get pendingOpsLabel => '待处理操作';

  @override
  String get lastSyncedLabel => '上次同步';

  @override
  String get failedItemsLabel => '失败项目';

  @override
  String get offlineSyncTooltip => '离线 -- 恢复连接后将自动同步';

  @override
  String get pullingLabel => '拉取中';

  @override
  String get pushingLabel => '推送中';

  @override
  String get syncingLabel => '同步中...';

  @override
  String get allChangesSyncedLabel => '所有更改已同步';

  @override
  String pendingOpTooltip(int count) {
    return '$count 个待处理操作';
  }

  @override
  String pendingOpsTooltip(int count) {
    return '$count 个待处理操作';
  }

  @override
  String get syncConflictBadge => '同步冲突';

  @override
  String get conflictLabel => '冲突';

  @override
  String get syncedLabel => '已同步';

  @override
  String get pendingSyncLabel => '待同步';

  @override
  String get pendingSyncBadge => '待同步';

  @override
  String barChartSemanticLabel(String entries) {
    return '条形图，按月显示笔记数量：$entries';
  }

  @override
  String donutChartSemanticLabel(String entries) {
    return '环形图，显示分布情况：$entries';
  }

  @override
  String tagItemSemanticLabel(String name) {
    return '标签：$name';
  }

  @override
  String get tagItemSemanticHint => '长按以编辑';

  @override
  String get moreActions => '更多操作';

  @override
  String get statusSaved => '已保存';

  @override
  String get statusUnsaved => '未保存';

  @override
  String get statusSaving => '保存中...';

  @override
  String get selectItemToView => '选择一个项目以查看';

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

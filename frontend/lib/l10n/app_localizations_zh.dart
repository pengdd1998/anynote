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
  String get restoreVersion => '恢复版本';

  @override
  String restoreVersionConfirm(int version) {
    return '用版本 $version 替换当前笔记内容？当前内容将先保存一个快照。';
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
  String get noNotesAvailableCreate => '暂无笔记。\n请先创建一些笔记。';

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
  String noteCount(int count, String suffix) {
    return '$count 篇笔记$suffix';
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
  String get shareNote => '分享笔记';

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
  String get offlineBanner => '您当前离线 — 恢复连接后将自动同步更改';

  @override
  String get unlockRequired => '请先解锁您的保险库';
}

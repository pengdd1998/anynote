// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'AnyNote';

  @override
  String get welcomeBack => '다시 오셨군요';

  @override
  String get signInToVault => '암호화 금고에 로그인';

  @override
  String get email => '이메일';

  @override
  String get emailRequired => '이메일을 입력해 주세요';

  @override
  String get password => '비밀번호';

  @override
  String get passwordRequired => '비밀번호를 입력해 주세요';

  @override
  String get signIn => '로그인';

  @override
  String get noAccountRegister => '계정이 없으신가요? 회원가입';

  @override
  String get recoverFromBackup => '백업에서 복원';

  @override
  String get noEncryptionKeys => '암호화 키를 찾을 수 없습니다. 먼저 회원가입해 주세요.';

  @override
  String get invalidEmailOrPassword => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get accountNotFoundRegister => '계정을 찾을 수 없습니다. 먼저 회원가입해 주세요.';

  @override
  String get unableToReachServer => '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get startEncryptedJourney => '암호화 메모를 시작해 보세요';

  @override
  String get username => '사용자 이름';

  @override
  String get usernameRequired => '사용자 이름을 입력해 주세요';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get passwordsDoNotMatch => '비밀번호가 일치하지 않습니다';

  @override
  String get passwordMinLength => '비밀번호는 8자 이상이어야 합니다';

  @override
  String get encryptionNotice => '데이터가 이 비밀번호로 암호화됩니다. 분실 시 복구할 수 없습니다.';

  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요? 로그인';

  @override
  String get emailOrUsernameTaken => '이미 사용 중인 이메일 또는 사용자 이름입니다.';

  @override
  String get invalidInput => '입력 내용에 오류가 있습니다. 확인해 주세요.';

  @override
  String get saveRecoveryKey => '복구 키 저장';

  @override
  String get recoveryKeyInstructions =>
      '이 복구 키를 안전한 곳에 보관하세요. 비밀번호를 잊어버렸을 때 데이터를 복구하는 데 필요합니다.';

  @override
  String get copyRecoveryKey => '복구 키 복사';

  @override
  String get recoveryKeyCopied => '복구 키가 클립보드에 복사되었습니다';

  @override
  String get iSavedIt => '저장했습니다';

  @override
  String get recoverAccount => '계정 복구';

  @override
  String get recoverAccountInstructions =>
      '12단어 복구 키를 입력하여 이 기기에서 암호화 금고를 복원하세요.';

  @override
  String get recoveryKeyLabel => '복구 키 (12단어)';

  @override
  String get pasteFromClipboard => '클립보드에서 붙여넣기';

  @override
  String get recoveryKeyRequired => '복구 키를 입력해 주세요';

  @override
  String get recoveryKeyWordCount => '복구 키는 정확히 12단어여야 합니다';

  @override
  String get recoveryKeyFormatHint => '12단어를 올바른 순서로, 공백으로 구분하여 입력하세요.';

  @override
  String get invalidRecoveryKey => '유효하지 않은 복구 키입니다. 단어를 확인하고 다시 시도해 주세요.';

  @override
  String get invalidRecoveryKeyForAccount => '이 계정에 해당하는 복구 키가 아닙니다.';

  @override
  String get accountNotFoundCheckEmail => '계정을 찾을 수 없습니다. 이메일을 확인해 주세요.';

  @override
  String get backToSignIn => '로그인으로 돌아가기';

  @override
  String get skip => '건너뛰기';

  @override
  String get next => '다음';

  @override
  String get getStarted => '시작하기';

  @override
  String get onboardingPrivacyTitle => '나의 메모, 나의 프라이버시';

  @override
  String get onboardingPrivacyDesc =>
      'AnyNote는 모든 메모를 클라우드로 전송하기 전에 기기에서 암호화합니다. 누구도 — 저희조차 — 회원님의 메모를 읽을 수 없습니다.';

  @override
  String get onboardingMasterPasswordTitle => '마스터 비밀번호';

  @override
  String get onboardingMasterPasswordDesc =>
      '암호화 키를 도출하는 마스터 비밀번호를 설정합니다. 반드시 기억해 주세요 — 복구 키 없이는 비밀번호를 재설정할 수 없습니다.';

  @override
  String get onboardingRecoveryKeyTitle => '복구 키';

  @override
  String get onboardingRecoveryKeyDesc =>
      '12단어 복구 키가 발급됩니다. 안전하게 보관하세요 — 비밀번호를 잊었을 때 메모를 복구할 유일한 방법입니다.';

  @override
  String get onboardingAITitle => 'AI 기반 작성';

  @override
  String get onboardingAIDesc =>
      'AI를 사용하여 메모 작성, 개요 작성, 모든 플랫폼에 맞게 변환할 수 있습니다. 콘텐츠는 절대 기록되지 않습니다.';

  @override
  String get searchNotes => '메모 검색...';

  @override
  String get collections => '컬렉션';

  @override
  String get sortNotes => '메모 정렬';

  @override
  String get updatedNewest => '수정일 (최신순)';

  @override
  String get updatedOldest => '수정일 (오래된순)';

  @override
  String get createdNewest => '작성일 (최신순)';

  @override
  String get createdOldest => '작성일 (오래된순)';

  @override
  String get titleAZ => '제목 A-Z';

  @override
  String get listView => '목록 보기';

  @override
  String get gridView => '그리드 보기';

  @override
  String get advancedSearch => '상세 검색';

  @override
  String get closeSearch => '검색 닫기';

  @override
  String get searchNotesTooltip => '메모 검색';

  @override
  String get createNewNote => '새 메모 만들기';

  @override
  String get noNotesYet => '메모가 없습니다';

  @override
  String get tapToCapture => '+ 를 눌러 첫 번째 메모를 작성하세요';

  @override
  String get newNote => '새 메모';

  @override
  String get noResults => '결과 없음';

  @override
  String get tryDifferentSearch => '다른 검색어로 시도해 보세요';

  @override
  String get deleteNoteQuestion => '메모를 삭제하시겠습니까?';

  @override
  String deleteNoteConfirm(String title) {
    return '\"$title\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get noteDeleted => '메모가 삭제되었습니다';

  @override
  String get undo => '실행 취소';

  @override
  String get unpinNote => '고정 해제';

  @override
  String get pinNote => '고정';

  @override
  String get deleteNote => '메모 삭제';

  @override
  String get blankNote => '빈 메모';

  @override
  String get fromTemplate => '템플릿에서 만들기';

  @override
  String get justNow => '방금';

  @override
  String minutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String hoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String daysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get untitled => '제목 없음';

  @override
  String get versionHistory => '버전 기록';

  @override
  String get editNote => '메모 편집';

  @override
  String get exportOrShare => '내보내기 및 공유';

  @override
  String get shareViaLink => '링크로 공유';

  @override
  String get exportAsMarkdown => 'Markdown으로 내보내기';

  @override
  String get exportAsHTML => 'HTML로 내보내기';

  @override
  String get exportAsPlainText => '일반 텍스트로 내보내기';

  @override
  String get failedToLoadNote => '메모를 불러오지 못했습니다';

  @override
  String get retry => '다시 시도';

  @override
  String get noteNotFound => '메모를 찾을 수 없습니다';

  @override
  String get notSynced => '동기화 안 됨';

  @override
  String get couldNotLoadForExport => '내보낼 메모를 불러올 수 없습니다';

  @override
  String get deleteNoteDialog => '메모 삭제';

  @override
  String get deleteNoteDialogMessage => '이 메모는 휴지통으로 이동합니다. 나중에 복원할 수 있습니다.';

  @override
  String get title => '제목';

  @override
  String get startWriting => '입력을 시작하세요...';

  @override
  String get saveAndClose => '저장하고 닫기';

  @override
  String get savingNote => '메모 저장 중';

  @override
  String get plainText => '일반 텍스트';

  @override
  String get richText => '서식 있는 텍스트';

  @override
  String get edit => '편집';

  @override
  String get preview => '미리보기';

  @override
  String get manageTags => '태그 관리';

  @override
  String get addImage => '이미지 추가';

  @override
  String get noteContent => '메모 내용';

  @override
  String get tags => '태그';

  @override
  String get closeTagPicker => '태그 선택 닫기';

  @override
  String get newTagName => '새 태그 이름';

  @override
  String get add => '추가';

  @override
  String get noTagsYet => '태그가 없습니다. 위에서 만들어 보세요.';

  @override
  String failedToAddImage(String error) {
    return '이미지 추가에 실패했습니다: $error';
  }

  @override
  String get restore => '복원';

  @override
  String get close => '닫기';

  @override
  String get restoreVersion => '버전 복원';

  @override
  String restoreVersionConfirm(int version) {
    return '현재 메모 내용을 버전 $version(으)로 교체하시겠습니까? 현재 내용의 스냅샷이 먼저 저장됩니다.';
  }

  @override
  String get versionRestored => '버전이 복원되었습니다';

  @override
  String failedToRestore(String error) {
    return '복원에 실패했습니다: $error';
  }

  @override
  String get failedToLoadVersions => '버전을 불러오지 못했습니다';

  @override
  String get noVersionsYet => '버전 기록이 없습니다';

  @override
  String get versionsSavedAutomatically => '메모를 편집하면 자동으로 버전이 저장됩니다.';

  @override
  String get current => '현재';

  @override
  String get settings => '설정';

  @override
  String get account => '계정';

  @override
  String get plan => '플랜';

  @override
  String get upgrade => '업그레이드';

  @override
  String get loading => '불러오는 중...';

  @override
  String get unableToLoadAccountInfo => '계정 정보를 불러올 수 없습니다';

  @override
  String get aiSection => 'AI';

  @override
  String get llmConfiguration => 'LLM 설정';

  @override
  String get configureAIProviders => 'AI 제공자 설정';

  @override
  String get aiQuota => 'AI 사용량';

  @override
  String requestsToday(int used, int limit) {
    return '오늘 요청: $used/$limit';
  }

  @override
  String get unableToLoadQuota => '사용량을 불러올 수 없습니다';

  @override
  String get publishing => '게시';

  @override
  String get platformConnections => '플랫폼 연결';

  @override
  String get manageConnectedPlatforms => '연결된 플랫폼 관리';

  @override
  String get securityPrivacy => '보안 및 개인정보';

  @override
  String get encryptionSettings => '암호화 설정';

  @override
  String get e2eEncryptionActive => '종단간 암호화 활성화';

  @override
  String get sync => '동기화';

  @override
  String get syncStatus => '동기화 상태';

  @override
  String get lastSyncedNever => '마지막 동기화: 없음';

  @override
  String lastSynced(String time) {
    return '마지막 동기화: $time';
  }

  @override
  String get checking => '확인 중...';

  @override
  String get unableToLoadSyncStatus => '동기화 상태를 불러올 수 없습니다';

  @override
  String get syncNow => '지금 동기화';

  @override
  String syncCompleteWithConflicts(int count) {
    return '동기화 완료 ($count개 충돌)';
  }

  @override
  String synced(int pulled, int pushed) {
    return '동기화 완료: $pulled개 가져옴, $pushed개 보냄';
  }

  @override
  String get data => '데이터';

  @override
  String get exportAllNotes => '모든 메모 내보내기';

  @override
  String get exportAllNotesDesc => '모든 메모를 파일로 내보내기';

  @override
  String get markdownFormat => 'Markdown (.md)';

  @override
  String get htmlFormat => 'HTML (.html)';

  @override
  String get plainTextFormat => '일반 텍스트 (.txt)';

  @override
  String get noNotesToExport => '내보낼 메모가 없습니다';

  @override
  String get noNotesWithContent => '내용이 있는 메모가 없습니다';

  @override
  String exportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get about => '정보';

  @override
  String get version => '버전';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfService => '이용약관';

  @override
  String get signOut => '로그아웃';

  @override
  String get signOutConfirmTitle => '로그아웃';

  @override
  String get signOutConfirmMessage => '로그아웃하시겠습니까? 메모에 접근하려면 다시 로그인해야 합니다.';

  @override
  String signOutFailed(String error) {
    return '로그아웃에 실패했습니다: $error';
  }

  @override
  String get securityEncryption => '보안 및 암호화';

  @override
  String get e2eEncryptionActiveStatus => '종단간 암호화 활성화';

  @override
  String get encryptionNotSetUp => '암호화가 설정되지 않았습니다';

  @override
  String get encryptionAlgorithm => '데이터가 XChaCha20-Poly1305로 암호화되어 있습니다';

  @override
  String get keyDerivation => '키 파생: Argon2id';

  @override
  String get masterKeyUnlocked => '마스터 키: 잠금 해제됨';

  @override
  String get masterKeyLocked => '마스터 키: 잠김';

  @override
  String get encryptedItems => '암호화된 항목';

  @override
  String get notes => '메모';

  @override
  String get tagsLabel => '태그';

  @override
  String get collectionsLabel => '컬렉션';

  @override
  String get aiContent => 'AI 콘텐츠';

  @override
  String itemsCount(int count) {
    return '$count개';
  }

  @override
  String get recoveryKeySection => '복구 키';

  @override
  String get recoveryKeyUsage => '비밀번호를 잊었을 때 이 키로 데이터를 복구할 수 있습니다.';

  @override
  String get viewRecoveryKey => '복구 키 보기';

  @override
  String get noRecoveryKeyStored => '저장된 복구 키가 없습니다.';

  @override
  String get recoveryKeyWarning =>
      '복구 키는 가입 시 생성되었습니다. 저장하지 않았다면 비밀번호 없이는 데이터를 복구할 수 없습니다.';

  @override
  String get copyToClipboard => '클립보드에 복사';

  @override
  String get hide => '숨기기';

  @override
  String get failedToLoadRecoveryKey => '복구 키를 불러오지 못했습니다';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get reEncryptsData => '새 키로 모든 데이터를 재암호화합니다';

  @override
  String get verifyPassword => '비밀번호 확인';

  @override
  String get enterYourPassword => '비밀번호를 입력하세요';

  @override
  String get verify => '확인';

  @override
  String get incorrectPassword => '비밀번호가 올바르지 않습니다';

  @override
  String get verificationFailed => '확인에 실패했습니다';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get confirmNewPassword => '새 비밀번호 확인';

  @override
  String get reEncryptWarning => '경고: 모든 데이터가 재암호화됩니다.';

  @override
  String get change => '변경';

  @override
  String get currentPasswordIncorrect => '현재 비밀번호가 올바르지 않습니다';

  @override
  String get passwordChangedSuccessfully => '비밀번호가 변경되었습니다';

  @override
  String failedToChangePassword(String error) {
    return '비밀번호 변경에 실패했습니다: $error';
  }

  @override
  String get dangerZone => '위험 구역';

  @override
  String get deleteAllLocalData => '모든 로컬 데이터 삭제';

  @override
  String get exportEncryptedBackup => '암호화 백업 내보내기';

  @override
  String get importEncryptedBackup => '암호화 백업 가져오기';

  @override
  String get deleteAllDataQuestion => '모든 데이터를 삭제하시겠습니까?';

  @override
  String get deleteAllDataMessage =>
      '이 작업은 되돌릴 수 없습니다. 모든 메모, 태그, 설정이 영구적으로 삭제됩니다.';

  @override
  String get deleteEverything => '모두 삭제';

  @override
  String get areYouAbsolutelySure => '정말 확실한가요?';

  @override
  String get typeDeleteToConfirm => '확인하려면 DELETE를 입력하세요.';

  @override
  String get typeDelete => 'DELETE 입력';

  @override
  String get allLocalDataDeleted => '모든 로컬 데이터가 삭제되었습니다';

  @override
  String failedToDeleteData(String error) {
    return '데이터 삭제에 실패했습니다: $error';
  }

  @override
  String get importBackup => '백업 가져오기';

  @override
  String get importBackupMessage =>
      '백업 파일에서 항목을 가져옵니다. 기존 항목은 덮어쓰지 않습니다. 계속하시겠습니까?';

  @override
  String get import => '가져오기';

  @override
  String importedItemsFromBackup(int count) {
    return '백업에서 $count개 항목을 가져왔습니다';
  }

  @override
  String backupExportFailed(String error) {
    return '백업 내보내기에 실패했습니다: $error';
  }

  @override
  String backupImportFailed(String error) {
    return '백업 가져오기에 실패했습니다: $error';
  }

  @override
  String get llmConfigTitle => 'LLM 설정';

  @override
  String get noLLMConfigs => 'LLM 설정이 없습니다';

  @override
  String get addLLMToEnableAI => 'LLM을 추가하여 AI 기능을 활성화하세요';

  @override
  String get addProvider => '제공자 추가';

  @override
  String get defaultLabel => '기본';

  @override
  String get testConnection => '연결 테스트';

  @override
  String get failedToLoadConfigs => '설정을 불러오지 못했습니다';

  @override
  String get addLLMProvider => 'LLM 제공자 추가';

  @override
  String get name => '이름';

  @override
  String get provider => '제공자';

  @override
  String get baseUrl => '기본 URL';

  @override
  String get apiKey => 'API 키';

  @override
  String get model => '모델';

  @override
  String get modelHint => '예: gpt-4o';

  @override
  String get save => '저장';

  @override
  String get editLLMProvider => 'LLM 제공자 편집';

  @override
  String get newApiKeyHint => '새 API 키 (유지하려면 비워두세요)';

  @override
  String get testingConnection => '연결 테스트 중...';

  @override
  String get connectionSuccessful => '연결에 성공했습니다';

  @override
  String connectionFailed(String error) {
    return '연결에 실패했습니다: $error';
  }

  @override
  String deleteConfigQuestion(String name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String get removeLLMConfigConfirm => '이 LLM 설정을 삭제하시겠습니까?';

  @override
  String get noPlatformsAvailable => '사용 가능한 플랫폼이 없습니다';

  @override
  String get platformConnectionsWillAppear => '플랫폼 연결이 여기에 표시됩니다';

  @override
  String get failedToLoadPlatforms => '플랫폼을 불러오지 못했습니다';

  @override
  String get connect => '연결';

  @override
  String get verifyButton => '확인';

  @override
  String get disconnect => '연결 해제';

  @override
  String connectedTo(String name) {
    return '$name에 연결되었습니다';
  }

  @override
  String failedToConnect(String error) {
    return '연결에 실패했습니다: $error';
  }

  @override
  String get verifyingConnection => '연결 확인 중...';

  @override
  String get connectionVerified => '연결이 확인되었습니다';

  @override
  String connectionInvalid(String error) {
    return '연결이 유효하지 않습니다: $error';
  }

  @override
  String verificationFailedError(String error) {
    return '확인에 실패했습니다: $error';
  }

  @override
  String disconnectPlatform(String name) {
    return '$name 연결 해제';
  }

  @override
  String disconnectPlatformConfirm(String name) {
    return '$name 계정과의 연결을 해제하시겠습니까?';
  }

  @override
  String disconnectedFrom(String name) {
    return '$name 연결이 해제되었습니다';
  }

  @override
  String failedToDisconnect(String error) {
    return '연결 해제에 실패했습니다: $error';
  }

  @override
  String get scanQRCode => 'QR 코드 스캔';

  @override
  String scanQRInstructions(String platform) {
    return '$platform 앱을 열고 이 QR 코드를 스캔하여 로그인하세요';
  }

  @override
  String get done => '완료';

  @override
  String get tagsTitle => '태그';

  @override
  String get noTags => '태그가 없습니다';

  @override
  String get createTagsToOrganize => '태그를 만들어 메모를 정리해 보세요';

  @override
  String get newTag => '새 태그';

  @override
  String get tagName => '태그 이름';

  @override
  String get tagNameHint => '예: 아이디어, 업무, 개인';

  @override
  String get create => '만들기';

  @override
  String get encrypted => '(암호화됨)';

  @override
  String get aiCompose => 'AI 작성';

  @override
  String get aiPoweredWriting => 'AI 기반 작성';

  @override
  String get aiComposeDesc => '메모를 선택하고 AI가 모든 플랫폼에 맞는 세련된 콘텐츠를 만들어 드립니다.';

  @override
  String get startComposing => '작성 시작';

  @override
  String get recentCompositions => '최근 작성';

  @override
  String get noCompositionsYet => '작성 기록이 없습니다';

  @override
  String get newComposition => '새로 작성';

  @override
  String get topicOrTheme => '주제 또는 테마';

  @override
  String get topicHint => '콘텐츠의 주제를 입력하세요';

  @override
  String get targetPlatform => '대상 플랫폼';

  @override
  String get selectNotes => '메모 선택';

  @override
  String selectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get noNotesAvailableCreate => '메모가 없습니다.\n먼저 메모를 만들어 주세요.';

  @override
  String get contentPreview => '콘텐츠 미리보기';

  @override
  String get noContent => '(내용 없음)';

  @override
  String get copy => '복사';

  @override
  String get saveAsNote => '메모로 저장';

  @override
  String get copiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get savedAsNote => '메모로 저장되었습니다';

  @override
  String get publish => '게시';

  @override
  String get connectedPlatforms => '연결된 플랫폼';

  @override
  String get noPlatformsConnected => '연결된 플랫폼이 없습니다';

  @override
  String get connectAPlatform => '플랫폼 연결';

  @override
  String get publishContent => '콘텐츠 게시';

  @override
  String get content => '내용';

  @override
  String get tagsCommaSeparated => '태그 (쉼표로 구분)';

  @override
  String get tagsHint => '태그1, 태그2, 태그3';

  @override
  String get selectPlatformToPublish => '위에서 플랫폼을 선택하여 게시하세요';

  @override
  String publishedStatus(String status) {
    return '게시 완료! 상태: $status';
  }

  @override
  String get titleAndContentRequired => '제목과 내용은 필수입니다';

  @override
  String get publishRequestSubmitted => '게시 요청이 제출되었습니다';

  @override
  String get recentPublications => '최근 게시';

  @override
  String get noPublicationsYet => '게시 기록이 없습니다';

  @override
  String viewAll(int count) {
    return '전체 보기 ($count개)';
  }

  @override
  String get publishHistory => '게시 기록';

  @override
  String get filterByStatus => '상태별 필터';

  @override
  String get all => '전체';

  @override
  String get published => '게시됨';

  @override
  String get failed => '실패';

  @override
  String get publishingStatus => '게시 중';

  @override
  String get pending => '대기 중';

  @override
  String noPublicationsWithStatus(String status) {
    return '$status 게시물이 없습니다';
  }

  @override
  String get clearFilter => '필터 초기화';

  @override
  String get noPublications => '게시물이 없습니다';

  @override
  String get publishedContentWillAppear => '게시한 콘텐츠가 여기에 표시됩니다';

  @override
  String get failedToLoadPublishHistory => '게시 기록을 불러오지 못했습니다';

  @override
  String get viewDetails => '상세 보기';

  @override
  String get platform => '플랫폼';

  @override
  String get status => '상태';

  @override
  String get created => '작성일';

  @override
  String get publishedDate => '게시일';

  @override
  String get url => 'URL';

  @override
  String get error => '오류';

  @override
  String get contentLabel => '내용';

  @override
  String failedToLoadDetail(String error) {
    return '상세 정보를 불러오지 못했습니다: $error';
  }

  @override
  String get collectionsTitle => '컬렉션';

  @override
  String get noCollectionsYet => '컬렉션이 없습니다';

  @override
  String get groupNotesIntoCollections => '메모를 컬렉션으로 묶어 보세요';

  @override
  String get newCollection => '새 컬렉션';

  @override
  String get deleteCollectionQuestion => '컬렉션을 삭제하시겠습니까?';

  @override
  String deleteCollectionConfirm(String title) {
    return '\"$title\"을(를) 삭제하시겠습니까? 이 컬렉션의 메모는 삭제되지 않습니다.';
  }

  @override
  String get collectionDeleted => '컬렉션이 삭제되었습니다';

  @override
  String get untitledCollection => '제목 없는 컬렉션';

  @override
  String noteCount(int count, String suffix) {
    return '메모 $count개$suffix';
  }

  @override
  String get collectionTitle => '컬렉션 제목';

  @override
  String get collectionTitleHint => '이 컬렉션의 이름을 입력하세요';

  @override
  String get collectionNotFound => '컬렉션을 찾을 수 없습니다';

  @override
  String get failedToLoadCollection => '컬렉션을 불러오지 못했습니다';

  @override
  String get noNotesInCollection => '이 컬렉션에 메모가 없습니다';

  @override
  String get tapToAddNotes => '+ 를 눌러 메모를 추가하세요';

  @override
  String get addNotes => '메모 추가';

  @override
  String get removeFromCollection => '컬렉션에서 제거하시겠습니까?';

  @override
  String removeNoteConfirm(String title) {
    return '\"$title\"을(를) 이 컬렉션에서 제거하시겠습니까? 메모 자체는 삭제되지 않습니다.';
  }

  @override
  String get remove => '제거';

  @override
  String get renameCollection => '컬렉션 이름 변경';

  @override
  String get renameCollectionTooltip => '컬렉션 이름 변경';

  @override
  String get deleteCollectionTooltip => '컬렉션 삭제';

  @override
  String get deleteCollectionDialogTitle => '컬렉션 삭제';

  @override
  String get deleteCollectionDialogMessage =>
      '이 컬렉션과 모든 메모 연결이 제거됩니다. 메모 자체는 삭제되지 않습니다.';

  @override
  String get noNotesAvailable => '사용 가능한 메모가 없습니다';

  @override
  String get removeFromCollectionTooltip => '컬렉션에서 제거';

  @override
  String get search => '검색';

  @override
  String get clearAllFilters => '모든 필터 초기화';

  @override
  String get searchYourNotes => '메모 검색';

  @override
  String get enterQueryOrFilters => '검색어를 입력하거나 필터를 사용하여 메모를 찾으세요';

  @override
  String get recentSearches => '최근 검색';

  @override
  String get clearAll => '전체 삭제';

  @override
  String get noResultsFound => '결과를 찾을 수 없습니다';

  @override
  String get tryAdjustingSearch => '검색어나 필터를 조정해 보세요';

  @override
  String searchError(String error) {
    return '검색 오류: $error';
  }

  @override
  String get dateRange => '기간';

  @override
  String get tagsFilter => '태그';

  @override
  String get collectionsFilter => '컬렉션';

  @override
  String tagsCount(int count) {
    return '태그 $count개';
  }

  @override
  String collectionsCount(int count) {
    return '컬렉션 $count개';
  }

  @override
  String resultsCount(String count) {
    return '결과 $count개';
  }

  @override
  String get noTagsAvailable => '사용 가능한 태그가 없습니다';

  @override
  String get noCollectionsAvailable => '사용 가능한 컬렉션이 없습니다';

  @override
  String get selectTags => '태그 선택';

  @override
  String get apply => '적용';

  @override
  String get selectCollections => '컬렉션 선택';

  @override
  String get shareNote => '메모 공유';

  @override
  String get passwordProtection => '비밀번호 보호';

  @override
  String get requirePassword => '비밀번호 요구';

  @override
  String get requirePasswordDesc => '수신자가 보려면 비밀번호를 입력해야 합니다';

  @override
  String get expiresAfter => '만료 기간';

  @override
  String get oneHour => '1시간';

  @override
  String get twentyFourHours => '24시간';

  @override
  String get sevenDays => '7일';

  @override
  String get never => '만료 없음';

  @override
  String get passwordRequiredForShare => '비밀번호 보호를 활성화하면 비밀번호는 필수입니다';

  @override
  String failedToCreateShareLink(String error) {
    return '공유 링크 생성에 실패했습니다: $error';
  }

  @override
  String get linkCopiedToClipboard => '링크가 클립보드에 복사되었습니다';

  @override
  String get copyLink => '링크 복사';

  @override
  String get passwordProtectedShareInfo =>
      '이 링크는 비밀번호로 보호되어 있습니다. 비밀번호는 별도로 공유하세요.';

  @override
  String get publicShareInfo => '이 링크를 아는 사람은 누구나 메모를 볼 수 있습니다.';

  @override
  String linkExpiresIn(String expiry) {
    return '링크 만료: $expiry';
  }

  @override
  String get encrypting => '암호화 중...';

  @override
  String get createShareLink => '공유 링크 만들기';

  @override
  String get language => '언어';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get languageChangedNotice => '언어 변경은 앱 재시작 후 적용됩니다';

  @override
  String get zenMode => '집중 모드';

  @override
  String get enterZenMode => '집중 모드 시작';

  @override
  String get exitZenMode => '집중 모드 종료';

  @override
  String wordCount(int count) {
    return '$count단어';
  }

  @override
  String charCount(int count) {
    return '$count자';
  }

  @override
  String get importNotes => '메모 가져오기';

  @override
  String get importMarkdown => 'Markdown 가져오기';

  @override
  String get importTextFiles => '텍스트 파일 가져오기';

  @override
  String get importAppleNotes => 'Apple 메모 가져오기';

  @override
  String importComplete(int count, int skipped) {
    return '가져오기 완료: $count개 가져옴, $skipped개 건너뜀';
  }

  @override
  String get markdownPreview => 'Markdown 미리보기';

  @override
  String get restoreFromBackup => '백업에서 복원';

  @override
  String get selectBackupFile => '백업 파일 선택';

  @override
  String get selectBackupFileDesc =>
      'AnyNote 암호화 백업 파일(.enc)을 선택하여 데이터를 복원하세요.';

  @override
  String get browseFiles => '파일 찾아보기';

  @override
  String get selectedFile => '선택된 파일';

  @override
  String get nextStep => '다음';

  @override
  String get back => '뒤로';

  @override
  String get backupDetails => '백업 상세 정보';

  @override
  String get backupFormat => '형식';

  @override
  String get backupVersion => '버전';

  @override
  String get exportDate => '내보낸 날짜';

  @override
  String get totalItems => '전체 항목 수';

  @override
  String get itemCounts => '항목 수';

  @override
  String get verificationErrors => '검증 오류';

  @override
  String get backupValid => '백업 검증 성공';

  @override
  String get backupInvalid => '백업 검증 실패';

  @override
  String get unlockToVerify => '암호화 잠금을 해제하여 백업 내용을 검증하세요.';

  @override
  String get restorePreviewTitle => '복원 미리보기';

  @override
  String get notesToRestore => '메모';

  @override
  String get tagsToRestore => '태그';

  @override
  String get collectionsToRestore => '컬렉션';

  @override
  String get contentsToRestore => 'AI 콘텐츠';

  @override
  String get earliestDate => '가장 오래된';

  @override
  String get latestDate => '가장 최근';

  @override
  String get noConflictsDetected => '충돌이 감지되지 않았습니다. 모든 항목이 새로 추가됩니다.';

  @override
  String get noteTitlesPreview => '메모 제목';

  @override
  String andMoreItems(int count) {
    return '...외 $count개';
  }

  @override
  String get conflictStrategyTitle => '충돌 해결';

  @override
  String get conflictStrategyDesc => '로컬에 이미 존재하는 항목의 처리 방법을 선택하세요.';

  @override
  String get strategyOverwrite => '덮어쓰기';

  @override
  String get strategyOverwriteDesc => '로컬 항목을 백업 버전으로 교체합니다';

  @override
  String get strategySkip => '건너뛰기';

  @override
  String get strategySkipDesc => '로컬 항목을 유지하고 백업 중복을 건너뜁니다';

  @override
  String get strategyKeepBoth => '둘 다 유지';

  @override
  String get strategyKeepBothDesc =>
      '백업 항목을 기존 항목과 함께 가져옵니다 (\'(복원됨)\' 접미사 추가)';

  @override
  String get restoreWarning => '복원된 항목은 동기화 큐에 추가됩니다. 시간이 조금 걸릴 수 있습니다.';

  @override
  String get startRestore => '복원 시작';

  @override
  String get restoringBackup => '백업 복원 중...';

  @override
  String restoreProgress(int current, int total) {
    return '$total개 중 $current개 처리 중';
  }

  @override
  String get restoreCompleted => '복원이 완료되었습니다';

  @override
  String get restoreCompletedWithErrors => '복원이 완료되었으나 일부 오류가 있습니다';

  @override
  String get restoreResults => '결과';

  @override
  String get itemsRestored => '복원됨';

  @override
  String get itemsSkipped => '건너뜀';

  @override
  String get conflictsFound => '충돌';

  @override
  String get errorsDuringRestore => '오류';

  @override
  String conflictsDetected(int count) {
    return '$count개의 항목이 로컬에 이미 존재합니다';
  }

  @override
  String existingNotesCount(int count) {
    return '메모 $count개';
  }

  @override
  String existingTagsCount(int count) {
    return '태그 $count개';
  }

  @override
  String existingCollectionsCount(int count) {
    return '컬렉션 $count개';
  }

  @override
  String existingContentsCount(int count) {
    return 'AI 콘텐츠 $count개';
  }

  @override
  String filePickerError(String error) {
    return '파일 선택기를 열지 못했습니다: $error';
  }

  @override
  String get restoreFromBackupDesc => '암호화 백업 파일에서 데이터 복원';

  @override
  String get importNotesDesc => 'Markdown, Apple 메모 또는 일반 텍스트에서 가져오기';

  @override
  String get onboardingWriteTitle => '생각을 적어보세요';

  @override
  String get onboardingWriteDesc => '어떤 기기에서든 메모를 작성하세요 — 콘텐츠는 안전하게 암호화됩니다';

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

  @override
  String get menuFile => '파일';

  @override
  String get menuNewNote => '새 메모';

  @override
  String get menuSave => '저장';

  @override
  String get menuImport => '가져오기...';

  @override
  String get menuExport => '내보내기...';

  @override
  String get menuCloseTab => '탭 닫기';

  @override
  String get menuEdit => '편집';

  @override
  String get menuUndo => '실행 취소';

  @override
  String get menuRedo => '다시 실행';

  @override
  String get menuCut => '잘라내기';

  @override
  String get menuCopy => '복사';

  @override
  String get menuPaste => '붙여넣기';

  @override
  String get menuSelectAll => '모두 선택';

  @override
  String get menuFind => '찾기...';

  @override
  String get menuView => '보기';

  @override
  String get menuToggleSidebar => '사이드바 전환';

  @override
  String get menuTogglePreview => '미리보기 전환';

  @override
  String get menuZenMode => '집중 모드';

  @override
  String get menuFullScreen => '전체 화면';

  @override
  String get menuExitFullScreen => '전체 화면 종료';

  @override
  String get menuHelp => '도움말';

  @override
  String get menuAbout => 'AnyNote 정보';

  @override
  String get menuKeyboardShortcuts => '키보드 단축키';

  @override
  String get aboutDialogTitle => 'AnyNote 정보';

  @override
  String get aboutDescription => '로컬 우선, 개인정보 우선의 종단간 암호화 메모 앱.';

  @override
  String aboutVersion(String version) {
    return '버전 $version';
  }

  @override
  String get shortcutsDialogTitle => '키보드 단축키';

  @override
  String get shortcutNewNote => '새 메모';

  @override
  String get shortcutSave => '저장';

  @override
  String get shortcutSearch => '검색';

  @override
  String get shortcutToggleSidebar => '사이드바 전환';

  @override
  String get shortcutExportPdf => 'PDF로 내보내기';

  @override
  String get shortcutSettings => '설정 열기';

  @override
  String get shortcutCloseNote => '메모 닫기';

  @override
  String get shortcutNextNote => '다음 메모';

  @override
  String get shortcutFullScreen => '전체 화면 전환';

  @override
  String get shortcutExitZen => '집중 모드 종료 / 대화상자 닫기';

  @override
  String get notesTabLabel => '메모';

  @override
  String get composeTabLabel => '작성';

  @override
  String get publishTabLabel => '게시';

  @override
  String get settingsTabLabel => '설정';

  @override
  String versionSemanticLabel(
    int versionNumber,
    String title,
    String date,
    String currentSuffix,
  ) {
    return '버전 $versionNumber, $title, $date$currentSuffix';
  }

  @override
  String get currentSuffix => ', 현재';

  @override
  String noteTitleLabel(String title) {
    return '메모 제목: $title';
  }

  @override
  String updatedDate(String date) {
    return '$date에 업데이트됨';
  }

  @override
  String get confirmDeleteNoteDialog => '메모 삭제 확인 대화상자';

  @override
  String get expiryImmediately => '즉시';

  @override
  String get expiryLessThanOneHour => '1시간 이내';

  @override
  String expiryInHours(int count) {
    return '$count시간 후';
  }

  @override
  String expiryInDays(int count) {
    return '$count일 후';
  }

  @override
  String compositionSemanticLabel(
    String title,
    String time,
    String platformSuffix,
  ) {
    return '작성물: $title. $time$platformSuffix';
  }

  @override
  String platformSuffix(String platform) {
    return '. 플랫폼: $platform';
  }

  @override
  String get platformGeneric => '일반';

  @override
  String get platformXhs => '샤오홍슈';

  @override
  String get platformTwitter => 'Twitter';

  @override
  String get platformBlog => '블로그';

  @override
  String get platformLinkedin => 'LinkedIn';

  @override
  String get noteClusters => '메모 클러스터';

  @override
  String get clusteringNotes => '메모를 클러스터링하는 중...';

  @override
  String analyzingNotes(int count, String topic) {
    return 'AI가 \"$topic\"에 대한 $count개의 메모를 분석 중이에요';
  }

  @override
  String foundThemesSelect(int count) {
    return 'AI가 $count개의 테마를 찾았어요. 포함할 테마를 선택해주세요.';
  }

  @override
  String notesCount(int count) {
    return '$count개 메모';
  }

  @override
  String clustersSelected(int count) {
    return '$count개 클러스터 선택됨';
  }

  @override
  String get generateOutline => '개요 생성';

  @override
  String get editorTitle => '편집기';

  @override
  String adaptStyleFor(String platform) {
    return '$platform에 맞게 스타일 조정';
  }

  @override
  String get saveNoteTooltip => '메모로 저장';

  @override
  String get aiWriting => 'AI가 작성 중...';

  @override
  String charsCount(int count) {
    return '$count자';
  }

  @override
  String get compositionHint => '작성물이 여기에 표시됩니다...';

  @override
  String get outlineButton => '개요';

  @override
  String wordsCount(int count) {
    return '$count단어';
  }

  @override
  String get viewAction => '보기';

  @override
  String get failedToSaveNote => '메모 저장 실패';

  @override
  String get outlineTitle => '개요';

  @override
  String get editTitleTooltip => '제목 편집';

  @override
  String get generatingOutline => '개요 생성 중...';

  @override
  String buildingStructureFromClusters(int count) {
    return '$count개 클러스터에서 구조를 구축하는 중';
  }

  @override
  String get noOutlineGenerated => '개요가 생성되지 않았어요.';

  @override
  String sectionsDragToReorder(int count) {
    return '$count개 섹션 -- 드래그하여 재정렬';
  }

  @override
  String get keyPoints => '핵심 포인트:';

  @override
  String fromCluster(int number) {
    return '클러스터 $number에서';
  }

  @override
  String get expandToDraft => '초안으로 확장';

  @override
  String get editTitle => '제목 편집';

  @override
  String get loginScreenLabel => 'AnyNote 로그인 화면';

  @override
  String errorLabel(String message) {
    return '오류: $message';
  }

  @override
  String get registrationScreenLabel => 'AnyNote 가입 화면';

  @override
  String get keyDerivationFailed => '키 파생에 실패했어요. 다시 시도해주세요.';

  @override
  String get demoSecretNote => '나의 비밀 메모...';

  @override
  String importFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get selectNoteToView => '메모를 선택하여 보기';

  @override
  String get collectionFallback => '컬렉션';

  @override
  String get unknown => '알 수 없음';

  @override
  String get freePlan => '무료';

  @override
  String get importMarkdownDesc =>
      '선택적 YAML 프론트매터가 포함된 Markdown(.md) 파일을 가져옵니다. 지원되는 프론트매터 필드: 제목, 날짜, 태그입니다. 지정하지 않으면 파일 이름이 제목으로 사용됩니다.';

  @override
  String get sourceHeader => '소스';

  @override
  String get selectFiles => '파일 선택';

  @override
  String get selectMdFilesSubtitle => '.md 파일을 하나 이상 선택';

  @override
  String get selectFolder => '폴더 선택';

  @override
  String get importMdFolderSubtitle => '폴더의 모든 .md 파일 가져오기';

  @override
  String get selectMdFilesTitle => 'Markdown 파일 선택';

  @override
  String get noMdFilesSelected => '선택된 .md 파일이 없어요.';

  @override
  String get selectMdFolderTitle => 'Markdown 파일이 있는 폴더 선택';

  @override
  String get appleNotesExportHeader => 'Apple 메모 내보내기';

  @override
  String get appleNotesImportDesc =>
      'Apple 메모 앱에서 내보낸 메모를 가져옵니다. Apple 메모에서 내보낸 HTML 파일(메모당 하나)이 포함된 폴더를 선택하세요. 기본 서식(굵게, 기울임, 제목, 목록)이 Markdown으로 변환됩니다.';

  @override
  String get selectAppleNotesFolderSubtitle => 'Apple 메모 HTML 파일이 있는 폴더 선택';

  @override
  String get selectAppleNotesFolderTitle => 'Apple 메모 내보내기 폴더 선택';

  @override
  String get plainTextFilesHeader => '일반 텍스트 파일';

  @override
  String get plainTextImportDesc =>
      '일반 텍스트(.txt) 파일을 메모로 가져옵니다. 각 파일의 첫 번째 줄이 메모 제목이 됩니다(100자 미만인 경우). 그렇지 않으면 파일 이름이 제목으로 사용됩니다.';

  @override
  String get selectTxtFilesSubtitle => '.txt 파일을 하나 이상 선택';

  @override
  String get importTxtFolderSubtitle => '폴더의 모든 .txt 파일 가져오기';

  @override
  String get selectTextFilesTitle => '텍스트 파일 선택';

  @override
  String get noTxtFilesSelected => '선택된 .txt 파일이 없어요.';

  @override
  String get selectTextFolderTitle => '텍스트 파일이 있는 폴더 선택';

  @override
  String fileCount(int count) {
    return '$count개 파일';
  }

  @override
  String andMoreErrors(int count) {
    return '...외 $count개 오류';
  }

  @override
  String get stepFile => '파일';

  @override
  String get stepVerify => '확인';

  @override
  String get stepPreview => '미리보기';

  @override
  String get stepStrategy => '방식';

  @override
  String get stepRestore => '복원';

  @override
  String get decryptFailed => '공유 메모 복호화에 실패했어요. 링크가 손상되었거나 만료되었을 수 있어요.';

  @override
  String get decryptingSharedNote => '공유 메모 복호화 중...';

  @override
  String get couldNotDecryptSharedNote => '공유 메모를 복호화할 수 없어요';

  @override
  String get linkCorruptedExpired => '링크가 손상되었거나, 만료되었거나, 불완전할 수 있어요.';

  @override
  String get passwordRequiredTitle => '비밀번호 필요';

  @override
  String get enterPasswordToView => '이 공유 메모를 보려면 비밀번호를 입력하세요.';

  @override
  String get unlock => '잠금 해제';

  @override
  String get sharedViaLink => '링크로 공유됨';

  @override
  String get sharedNote => '공유 메모';

  @override
  String platformSemanticLabel(
    String name,
    String subtitleSuffix,
    String selectedSuffix,
  ) {
    return '플랫폼: $name$subtitleSuffix$selectedSuffix';
  }

  @override
  String publishedSemanticLabel(
    String title,
    String platform,
    String status,
    String dateSuffix,
  ) {
    return '게시됨: $title. 플랫폼: $platform. 상태: $status$dateSuffix';
  }

  @override
  String get openInBrowser => '브라우저에서 게시된 글 열기';

  @override
  String statusLabel(String status) {
    return '상태: $status';
  }

  @override
  String get selectedLabel => '선택됨';

  @override
  String dateRangeFormat(String start, String end) {
    return '$start - $end';
  }

  @override
  String get builtInTab => '기본 제공';

  @override
  String get myTemplatesTab => '내 템플릿';

  @override
  String get deleteTemplateConfirm => '템플릿을 삭제할까요?';

  @override
  String deleteTemplateMessage(String name) {
    return '\"$name\"을(를) 삭제할까요? 이 작업은 되돌릴 수 없어요.';
  }

  @override
  String get templateNameLabel => '템플릿 이름';

  @override
  String get templateDateHint => '[date]를 사용하여 현재 날짜 삽입';
}

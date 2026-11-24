import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Every icon the app draws, by name.
///
/// One family — Phosphor line (the `Regular` cut). Nothing else draws icons:
/// `Icons.*` from Material is not used, because it mixed three styles and
/// some of its code points render as colour emoji on Samsung phones.
/// `test/design/icon_system_test.dart` keeps it that way.
///
/// Rules:
/// - A name is what the icon means (`delete`), not what it looks like
///   (`trash`).
/// - `Regular` everywhere. `…Filled` is the *on* state of a toggle only
///   (star / pin / bookmark / mic…) and always sits next to its `Regular`
///   pair; it is never used on its own for decoration.
/// - `Bold` appears twice, for the high-contrast theme choices, where the
///   heavier stroke *is* the meaning.
/// - To add an icon: check the list below first, then add one line here and
///   use it everywhere.
///
/// Usage: `Icon(AppIcons.notes)`, `find.byIcon(AppIcons.notes)`.
class AppIcons {
  AppIcons._();

  // ── Navigation (regular / fill pairs) ────────────────────────────────

  static const notes = PhosphorIconsRegular.house;
  static const notesFilled = PhosphorIconsFill.house;
  static const compose = PhosphorIconsRegular.pen;
  static const composeFilled = PhosphorIconsFill.pen;
  static const ai = PhosphorIconsRegular.chatCircle;
  static const aiFilled = PhosphorIconsFill.chatCircle;
  static const settings = PhosphorIconsRegular.gear;
  static const settingsFilled = PhosphorIconsFill.gear;

  // ── Common actions ───────────────────────────────────────────────────

  static const close = PhosphorIconsRegular.x;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const add = PhosphorIconsRegular.plus;
  static const chevronRight = PhosphorIconsRegular.caretRight;
  static const arrowBack = PhosphorIconsRegular.arrowLeft;
  static const share = PhosphorIconsRegular.shareNetwork;
  static const copy = PhosphorIconsRegular.copy;
  static const delete = PhosphorIconsRegular.trash;
  static const edit = PhosphorIconsRegular.pencilSimple;
  static const check = PhosphorIconsRegular.check;
  static const checkCircle = PhosphorIconsRegular.checkCircle;
  static const checkCircleFilled = PhosphorIconsFill.checkCircle;
  static const link = PhosphorIconsRegular.link;

  // ── Settings ─────────────────────────────────────────────────────────

  static const aiRobot = PhosphorIconsRegular.robot;
  static const dataUsage = PhosphorIconsRegular.chartBar;
  static const shield = PhosphorIconsRegular.shieldChevron;
  static const tag = PhosphorIconsRegular.tag;
  static const cloud = PhosphorIconsRegular.cloud;
  static const cloudDone = PhosphorIconsRegular.cloudCheck;
  static const cloudOff = PhosphorIconsRegular.cloudSlash;
  static const cloudUpload = PhosphorIconsRegular.cloudArrowUp;
  static const notification = PhosphorIconsRegular.bell;
  static const fileUpload = PhosphorIconsRegular.uploadSimple;
  static const fileDownload = PhosphorIconsRegular.downloadSimple;
  static const restore = PhosphorIconsRegular.clockCounterClockwise;
  static const photoLibrary = PhosphorIconsRegular.images;
  static const description = PhosphorIconsRegular.fileText;
  static const keyboard = PhosphorIconsRegular.keyboard;
  static const palette = PhosphorIconsRegular.paintBrush;
  static const language = PhosphorIconsRegular.translate;
  static const lock = PhosphorIconsRegular.lock;
  static const sync = PhosphorIconsRegular.arrowsClockwise;
  static const animation = PhosphorIconsRegular.palette;
  static const sort = PhosphorIconsRegular.sortAscending;

  // ── Editor / Formatting ──────────────────────────────────────────────

  static const bold = PhosphorIconsRegular.textB;
  static const italic = PhosphorIconsRegular.textItalic;
  static const underline = PhosphorIconsRegular.textUnderline;
  static const strikethrough = PhosphorIconsRegular.textStrikethrough;
  static const title = PhosphorIconsRegular.textH;
  static const bulletList = PhosphorIconsRegular.listBullets;
  static const numberedList = PhosphorIconsRegular.listNumbers;
  static const quote = PhosphorIconsRegular.quotes;
  static const code = PhosphorIconsRegular.code;
  static const checklist = PhosphorIconsRegular.checks;
  static const indentIncrease = PhosphorIconsRegular.textIndent;
  static const indentDecrease = PhosphorIconsRegular.textOutdent;
  static const imageIcon = PhosphorIconsRegular.image;
  static const undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const redo = PhosphorIconsRegular.arrowClockwise;

  // ── Status / Feedback ────────────────────────────────────────────────

  static const error = PhosphorIconsRegular.warningCircle;
  static const info = PhosphorIconsRegular.info;
  static const help = PhosphorIconsRegular.question;
  static const success = PhosphorIconsRegular.checkCircle;
  static const history = PhosphorIconsRegular.clockCounterClockwise;
  static const visibility = PhosphorIconsRegular.eye;
  static const pin = PhosphorIconsRegular.pushPin;

  // ── Misc ─────────────────────────────────────────────────────────────

  static const folder = PhosphorIconsRegular.folder;
  static const folderOpen = PhosphorIconsRegular.folderOpen;
  static const person = PhosphorIconsRegular.user;
  static const personOutline = PhosphorIconsRegular.user;
  static const schedule = PhosphorIconsRegular.clock;
  static const noteAdd = PhosphorIconsRegular.notePencil;
  static const print = PhosphorIconsRegular.printer;
  static const article = PhosphorIconsRegular.article;
  static const accountTree = PhosphorIconsRegular.treeStructure;
  static const summarize = PhosphorIconsRegular.articleMedium;
  static const sparkles = PhosphorIconsRegular.sparkle;
  static const noteBlank = PhosphorIconsRegular.noteBlank;
  static const lightbulb = PhosphorIconsRegular.lightbulb;

  // ── Settings sub-screens ────────────────────────────────────────────

  static const infoOutline = PhosphorIconsRegular.info;
  static const privacyTip = PhosphorIconsRegular.shieldCheck;
  static const badge = PhosphorIconsRegular.identificationBadge;
  static const logout = PhosphorIconsRegular.signOut;
  static const key = PhosphorIconsRegular.key;
  static const verifiedUser = PhosphorIconsRegular.shieldCheck;
  static const warning = PhosphorIconsRegular.warning;
  static const deleteForever = PhosphorIconsRegular.trashSimple;
  static const download = PhosphorIconsRegular.downloadSimple;
  static const uploadIcon = PhosphorIconsRegular.uploadSimple;
  static const visibilityOff = PhosphorIconsRegular.eyeSlash;
  static const camera = PhosphorIconsRegular.camera;
  static const chat = PhosphorIconsRegular.chatCircle;
  static const questionAnswer = PhosphorIconsRegular.chatTeardropText;
  static const qrCode = PhosphorIconsRegular.qrCode;
  static const workspacePremium = PhosphorIconsRegular.medal;
  static const verified = PhosphorIconsRegular.sealCheck;
  static const verifiedFilled = PhosphorIconsFill.sealCheck;
  static const alarm = PhosphorIconsRegular.alarm;
  static const syncProblem = PhosphorIconsRegular.warningOctagon;
  static const personAdd = PhosphorIconsRegular.userPlus;
  static const notificationsActive = PhosphorIconsRegular.bellRinging;
  static const fileOpen = PhosphorIconsRegular.file;
  static const numbers = PhosphorIconsRegular.hash;
  static const calendarToday = PhosphorIconsRegular.calendarBlank;
  static const event = PhosphorIconsRegular.calendarCheck;
  static const inventory = PhosphorIconsRegular.archive;
  static const errorOutline = PhosphorIconsRegular.warningCircle;
  static const checkCircleOutline = PhosphorIconsRegular.checkCircle;
  static const skipNext = PhosphorIconsRegular.skipForward;
  static const contentCopy = PhosphorIconsRegular.copy;
  static const mergeType = PhosphorIconsRegular.gitMerge;
  static const previewIcon = PhosphorIconsRegular.eye;
  static const apple = PhosphorIconsRegular.appleLogo;
  static const textSnippet = PhosphorIconsRegular.textAlignLeft;
  static const insertDriveFile = PhosphorIconsRegular.file;
  static const cleaningServices = PhosphorIconsRegular.broom;
  static const deleteForeverOutline = PhosphorIconsRegular.trash;
  static const wifi = PhosphorIconsRegular.wifiHigh;
  static const deleteOutline = PhosphorIconsRegular.trash;
  static const star = PhosphorIconsRegular.star;
  static const starFilled = PhosphorIconsFill.star;

  // ── Arrows & navigation ──────────────────────────────────────────────

  static const arrowForward = PhosphorIconsRegular.arrowRight;
  static const arrowUp = PhosphorIconsRegular.arrowUp;
  static const arrowDown = PhosphorIconsRegular.arrowDown;
  static const chevronDown = PhosphorIconsRegular.caretDown;
  static const chevronUp = PhosphorIconsRegular.caretUp;
  static const chevronLeft = PhosphorIconsRegular.caretLeft;
  static const chevronDoubleDown = PhosphorIconsRegular.caretDoubleDown;
  static const chevronDoubleUp = PhosphorIconsRegular.caretDoubleUp;
  static const chevronDoubleRight = PhosphorIconsRegular.caretDoubleRight;
  static const arrowElbowDownRight = PhosphorIconsRegular.arrowElbowDownRight;
  static const arrowUpRight = PhosphorIconsRegular.arrowUpRight;
  static const arrowDownLeft = PhosphorIconsRegular.arrowDownLeft;
  static const openInNew = PhosphorIconsRegular.arrowSquareOut;
  static const export = PhosphorIconsRegular.export;
  static const fullscreen = PhosphorIconsRegular.cornersOut;
  static const fullscreenExit = PhosphorIconsRegular.cornersIn;

  // ── Actions ──────────────────────────────────────────────

  static const addCircle = PhosphorIconsRegular.plusCircle;
  static const cancel = PhosphorIconsRegular.xCircle;
  static const checkBox = PhosphorIconsRegular.checkSquare;
  static const contentPaste = PhosphorIconsRegular.clipboard;
  static const editNote = PhosphorIconsRegular.pencilSimpleLine;
  static const searchOff = PhosphorIconsRegular.fileMagnifyingGlass;
  static const save = PhosphorIconsRegular.floppyDisk;
  static const moreHorizontal = PhosphorIconsRegular.dotsThree;
  static const moreVertical = PhosphorIconsRegular.dotsThreeVertical;
  static const dragHandle = PhosphorIconsRegular.dotsSixVertical;
  static const refresh = PhosphorIconsRegular.arrowClockwise;
  static const send = PhosphorIconsRegular.paperPlaneTilt;
  static const publish = PhosphorIconsRegular.paperPlaneRight;

  // ── Media ──────────────────────────────────────────────

  static const micFilled = PhosphorIconsFill.microphone;
  static const mic = PhosphorIconsRegular.microphone;
  static const playCircle = PhosphorIconsRegular.playCircle;
  static const pauseCircle = PhosphorIconsRegular.pauseCircle;
  static const stop = PhosphorIconsRegular.stop;
  static const stopCircle = PhosphorIconsRegular.stopCircle;
  static const volumeUpFilled = PhosphorIconsFill.speakerHigh;
  static const volumeUp = PhosphorIconsRegular.speakerHigh;
  static const brokenImage = PhosphorIconsRegular.imageBroken;
  static const phoneAndroid = PhosphorIconsRegular.deviceMobile;

  // ── Marks (regular = off, filled = on) ──────────────────────────────────────────────

  static const pinFilled = PhosphorIconsFill.pushPin;
  static const bookmarkFilled = PhosphorIconsFill.bookmarkSimple;
  static const bookmark = PhosphorIconsRegular.bookmarkSimple;
  static const bookmarkAdd = PhosphorIconsRegular.bookmarks;
  static const favoriteFilled = PhosphorIconsFill.heart;
  static const favorite = PhosphorIconsRegular.heart;
  static const highlightFilled = PhosphorIconsFill.highlighter;
  static const highlight = PhosphorIconsRegular.highlighter;
  static const chartBarFilled = PhosphorIconsFill.chartBar;
  static const chartBar = PhosphorIconsRegular.chartBar;
  static const psychologyFilled = PhosphorIconsFill.brain;
  static const psychology = PhosphorIconsRegular.brain;
  static const lockOpen = PhosphorIconsRegular.lockSimpleOpen;
  static const circle = PhosphorIconsRegular.circle;
  static const circleFilled = PhosphorIconsFill.circle;

  // ── Links ──────────────────────────────────────────────

  static const linkOff = PhosphorIconsRegular.linkBreak;
  static const insertLink = PhosphorIconsRegular.linkSimple;
  static const addLink = PhosphorIconsRegular.linkSimpleHorizontal;

  // ── Notes, files & folders ──────────────────────────────────────────────

  static const filePdf = PhosphorIconsRegular.filePdf;
  static const folderPlus = PhosphorIconsRegular.folderPlus;
  static const folderZip = PhosphorIconsRegular.fileZip;
  static const moveTo = PhosphorIconsRegular.arrowsDownUp;
  static const storage = PhosphorIconsRegular.database;
  static const dataObject = PhosphorIconsRegular.bracketsCurly;
  static const cardMembership = PhosphorIconsRegular.identificationCard;

  // ── Time ──────────────────────────────────────────────

  static const pending = PhosphorIconsRegular.clockClockwise;
  static const today = PhosphorIconsRegular.calendarDot;
  static const calendarMonth = PhosphorIconsRegular.calendar;
  static const repeat = PhosphorIconsRegular.repeat;

  // ── Status & feedback ──────────────────────────────────────────────

  static const priorityHigh = PhosphorIconsRegular.exclamationMark;
  static const wifiOff = PhosphorIconsRegular.wifiSlash;
  static const block = PhosphorIconsRegular.prohibit;

  // ── Data & views ──────────────────────────────────────────────

  static const insights = PhosphorIconsRegular.chartLineUp;
  static const analytics = PhosphorIconsRegular.chartLine;
  static const scatterPlot = PhosphorIconsRegular.chartScatter;
  static const tableChart = PhosphorIconsRegular.table;
  static const dashboard = PhosphorIconsRegular.squaresFour;
  static const gridView = PhosphorIconsRegular.gridFour;
  static const viewList = PhosphorIconsRegular.list;
  static const listAlt = PhosphorIconsRegular.listDashes;
  static const viewHeadline = PhosphorIconsRegular.rows;
  static const verticalSplit = PhosphorIconsRegular.columns;
  static const verticalAlignCenter = PhosphorIconsRegular.alignCenterVertical;
  static const verticalAlignTop = PhosphorIconsRegular.alignTop;
  static const filterList = PhosphorIconsRegular.funnel;
  static const filterListOff = PhosphorIconsRegular.funnelX;
  static const compare = PhosphorIconsRegular.gitDiff;
  static const replace = PhosphorIconsRegular.swap;
  static const replaceAll = PhosphorIconsRegular.listChecks;
  static const speed = PhosphorIconsRegular.gauge;
  static const fire = PhosphorIconsRegular.fire;
  static const diamond = PhosphorIconsRegular.diamond;
  static const explore = PhosphorIconsRegular.compass;
  static const flag = PhosphorIconsRegular.flag;
  static const inbox = PhosphorIconsRegular.tray;

  // ── Settings & appearance ──────────────────────────────────────────────

  static const themeSystem = PhosphorIconsRegular.circleHalf;
  static const tune = PhosphorIconsRegular.slidersHorizontal;
  static const highContrastLight = PhosphorIconsBold.sun;
  static const highContrastDark = PhosphorIconsBold.moon;
  static const lightMode = PhosphorIconsRegular.sun;
  static const darkMode = PhosphorIconsRegular.moon;

  // ── Editor & formatting ──────────────────────────────────────────────

  static const textT = PhosphorIconsRegular.textT;
  static const spellcheck = PhosphorIconsRegular.textAa;
  static const writingStyle = PhosphorIconsRegular.feather;
  static const clearAll = PhosphorIconsRegular.eraser;
  static const remove = PhosphorIconsRegular.minus;
  static const removeCircle = PhosphorIconsRegular.minusCircle;
  static const magicWand = PhosphorIconsRegular.magicWand;

  // ── People & communication ──────────────────────────────────────────────

  static const people = PhosphorIconsRegular.users;
  static const alternateEmail = PhosphorIconsRegular.at;
  static const email = PhosphorIconsRegular.envelopeSimple;
  static const globe = PhosphorIconsRegular.globeSimple;
  static const comment = PhosphorIconsRegular.chatText;

  // ── Chips & marks ─────────────────────────────────────────────────────

  static const briefcase = PhosphorIconsRegular.briefcase;
  static const plant = PhosphorIconsRegular.plant;
  static const bookOpen = PhosphorIconsRegular.bookOpen;
  static const airplane = PhosphorIconsRegular.airplane;
  static const target = PhosphorIconsRegular.target;
  static const checkBoxEmpty = PhosphorIconsRegular.square;
}

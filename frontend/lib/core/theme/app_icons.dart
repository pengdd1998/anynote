import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Centralized icon mapping using Phosphor Icons.
///
/// Provides a single point of reference for all app icons. Navigation items
/// use [regular] for unselected and [fill] for selected states.
///
/// Usage: `Icon(AppIcons.notes)` instead of `Icon(Icons.note_outlined)`.
class AppIcons {
  AppIcons._();

  // ── Navigation (regular / fill pairs) ────────────────────────────────

  static const notes = PhosphorIconsRegular.note;
  static const notesFilled = PhosphorIconsFill.note;
  static const compose = PhosphorIconsRegular.sparkle;
  static const composeFilled = PhosphorIconsFill.sparkle;
  static const publish = PhosphorIconsRegular.uploadSimple;
  static const publishFilled = PhosphorIconsFill.uploadSimple;
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

  static const ai = PhosphorIconsRegular.robot;
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
  static const quote = PhosphorIconsRegular.textAa;
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

  // ── Navigation / Selection ───────────────────────────────────────────

  static const radioChecked = PhosphorIconsFill.circle;
  static const radioUnchecked = PhosphorIconsRegular.circle;

  // ── Misc ─────────────────────────────────────────────────────────────

  static const folder = PhosphorIconsRegular.folder;
  static const folderOpen = PhosphorIconsRegular.folderOpen;
  static const person = PhosphorIconsRegular.user;
  static const personOutline = PhosphorIconsRegular.user;
  static const schedule = PhosphorIconsRegular.calendarBlank;
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
  static const deleteForever = PhosphorIconsRegular.trash;
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
  static const notificationsActive = PhosphorIconsFill.bell;
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
  static const wifiTethering = PhosphorIconsRegular.wifiHigh;
  static const deleteOutline = PhosphorIconsRegular.trash;
}

import 'package:flutter/widgets.dart';
import 'package:flutter_mingcute/flutter_mingcute.dart';

/// 우열 아이콘 — MingCute(둥글고 통통한 선/채움 아이콘).
///
/// 화면은 `Icons.*` 대신 이 이름을 쓴다. 아이콘 묶음을 바꿀 때는 이 파일만 고친다.
/// 탭바처럼 선택 상태가 있는 곳은 `…Fill` 짝을 함께 쓴다.
abstract final class AppIcons {
  // 탭 (선 / 채움 짝)
  static const IconData home = MingCuteIcons.home4Line;
  static const IconData homeFill = MingCuteIcons.home4Fill;
  static const IconData training = MingCuteIcons.pencil2Line;
  static const IconData trainingFill = MingCuteIcons.pencil2Fill;
  static const IconData growth = MingCuteIcons.leafLine;
  static const IconData growthFill = MingCuteIcons.leafFill;
  static const IconData settings = MingCuteIcons.settings3Line;
  static const IconData settingsFill = MingCuteIcons.settings3Fill;
  static const IconData book = MingCuteIcons.book2Line;
  static const IconData bookFill = MingCuteIcons.book2Fill;
  static const IconData week = MingCuteIcons.checkCircleLine;
  static const IconData weekFill = MingCuteIcons.checkCircleFill;
  static const IconData route = MingCuteIcons.routeLine;
  static const IconData routeFill = MingCuteIcons.routeFill;
  static const IconData person = MingCuteIcons.user3Line;
  static const IconData personFill = MingCuteIcons.user3Fill;
  static const IconData group = MingCuteIcons.group2Line;
  static const IconData groupFill = MingCuteIcons.group2Fill;

  // 찍기·사진
  static const IconData camera = MingCuteIcons.cameraLine;
  static const IconData cameraFill = MingCuteIcons.cameraFill;
  static const IconData image = MingCuteIcons.picLine;
  static const IconData album = MingCuteIcons.photoAlbumLine;
  static const IconData imageSearch = MingCuteIcons.searchLine;
  static const IconData pdf = MingCuteIcons.pdfLine;
  static const IconData download = MingCuteIcons.downloadLine;
  static const IconData folderOpen = MingCuteIcons.folderOpenLine;

  // 학습
  static const IconData pencil = MingCuteIcons.pencil2Line;
  static const IconData edit = MingCuteIcons.edit2Line;
  static const IconData bookOpen = MingCuteIcons.book6Line;
  static const IconData school = MingCuteIcons.schoolLine;
  static const IconData question = MingCuteIcons.questionLine;
  static const IconData sparkles = MingCuteIcons.sparklesLine;
  static const IconData fireFill = MingCuteIcons.fireFill;
  static const IconData flag = MingCuteIcons.flag2Line;
  static const IconData flagFill = MingCuteIcons.flag2Fill;
  static const IconData target = MingCuteIcons.targetLine;
  static const IconData chart = MingCuteIcons.chartLineLine;
  static const IconData barChart = MingCuteIcons.chartBarLine;
  static const IconData trendingUp = MingCuteIcons.trendingUpLine;
  static const IconData replay = MingCuteIcons.refreshAnticlockwise1Line;
  static const IconData tour = MingCuteIcons.compassLine;

  // 재생·상태
  static const IconData play = MingCuteIcons.playFill;
  static const IconData playCircleFill = MingCuteIcons.playCircleFill;
  static const IconData check = MingCuteIcons.checkLine;
  static const IconData checkCircle = MingCuteIcons.checkCircleLine;
  static const IconData checkCircleFill = MingCuteIcons.checkCircleFill;
  static const IconData closeCircleFill = MingCuteIcons.closeCircleFill;
  static const IconData radioOff = MingCuteIcons.radioboxLine;
  static const IconData radioOn = MingCuteIcons.radioboxFill;
  static const IconData dot = MingCuteIcons.roundFill;
  static const IconData info = MingCuteIcons.informationLine;
  static const IconData warning = MingCuteIcons.warningLine;
  static const IconData error = MingCuteIcons.alertLine;
  static const IconData eye = MingCuteIcons.eye2Line;
  static const IconData lock = MingCuteIcons.lockLine;

  // 사람·계정
  static const IconData personAdd = MingCuteIcons.userAddLine;
  static const IconData account = MingCuteIcons.user4Line;
  static const IconData mail = MingCuteIcons.mailLine;
  static const IconData logout = MingCuteIcons.exitLine;
  static const IconData chat = MingCuteIcons.chat3Fill;
  static const IconData apple = MingCuteIcons.appleFill;
  static const IconData google = MingCuteIcons.googleFill;

  // 이동·편집
  static const IconData back = MingCuteIcons.leftLine;
  static const IconData arrowRight = MingCuteIcons.arrowRightLine;
  static const IconData chevronRight = MingCuteIcons.rightLine;
  static const IconData chevronDown = MingCuteIcons.downLine;
  static const IconData close = MingCuteIcons.closeLine;
  static const IconData more = MingCuteIcons.more2Line;
  static const IconData refresh = MingCuteIcons.refresh1Line;
  static const IconData copy = MingCuteIcons.copy2Line;
  static const IconData paste = MingCuteIcons.clipboardLine;
  static const IconData link = MingCuteIcons.link2Line;
  static const IconData deleteSweep = MingCuteIcons.delete2Line;
  static const IconData deleteForever = MingCuteIcons.delete3Line;
  static const IconData tool = MingCuteIcons.toolLine;
  static const IconData code = MingCuteIcons.codeLine;
}

/// 建置旗標以值傳遞而非編譯期常數，這樣單一建置下就能測試兩側行為。
/// 若用 kReleaseMode，release 專屬的分支在測試裡永遠跑不到。
class BuildFlags {
  const BuildFlags({required this.isRelease});

  const BuildFlags.debug() : isRelease = false;
  const BuildFlags.release() : isRelease = true;

  final bool isRelease;
}

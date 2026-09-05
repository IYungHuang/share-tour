library;

/// 圖資契約已上移至 domain 層，此處僅轉出，讓既有的 game 層 import 路徑繼續有效。
///
/// 契約本身不得含 Flutter 或 dart:ui 型別，否則 domain 的邏輯就無法在
/// 不啟動框架的條件下測試。
export '../../domain/location/projection/map_manifest.dart';

/// 單局旅行策展流程階段 (驅動 UI Overlays 宣告式切換)
enum CuratorRunPhase {
  philosophizing(label: '哲學選定'),
  fieldTrip(label: '巷弄踩線'),
  nightEditing(label: '夜間編輯'),
  clientReview(label: '客戶審查'),
  settled(label: '結算完畢');

  const CuratorRunPhase({required this.label});
  final String label;
}

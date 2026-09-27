/// 书架筛选面板里"文件夹"的最小契约：收藏与下载两套 view 形状相同，
/// 用接口承接可以让面板摆脱 dynamic（原先靠 `folder.key as String` 兜住）。
abstract interface class FolderView {
  String get key;

  String get name;

  bool get isAll;
}

/// 壁紙を自動更新する間隔のデフォルト値
const DEFAULT_AUTO_CHANGE_WALLPAPER_DURATION = "5m";

/// 壁紙を自動更新する間隔の一覧
const AUTO_CHANGE_WALLPAPER_DURATION_LIST = <String>["10s", "5m", "1h", "3h", "6h", "1d"];

/// 写真の自動同期の間隔のデフォルト値
const DEFAULT_AUTO_SYNC_PHOTOS_DURATION = "1h";

/// 写真の自動同期の間隔の一覧
const AUTO_SYNC_PHOTOS_DURATION_LIST = <String>["1h", "3h", "6h", "1d"];

/// 最後に壁紙を更新した時刻
const SP_LAST_WALLPAPER_CHANGED_AT = "last_wallpaper_changed_at";

/// 壁紙を自動更新するかどうか
const SP_AUTO_CHANGE_WALLPAPER = "auto_change_wallpaper";

/// 壁紙を自動更新する間隔
const SP_AUTO_CHANGE_WALLPAPER_DURATION = "auto_change_wallpaper_duration";

/// フィルタリング：横幅
const SP_FILTER_WIDTH = "filter_width";

/// フィルタリング：ファイル名（正規表現）
const SP_FILTER_FILENAME_REGEX = "filter_filename_regex";

/// フィルタリング：横向きのみ
const SP_FILTER_ONLY_LANDSCAPE = "filter_only_landscape";

/// 写真の自動同期するかどうか
const SP_AUTO_SYNC_PHOTOS = "auto_sync_photos";

/// 写真の自動同期の間隔
const SP_AUTO_SYNC_PHOTOS_DURATION = "auto_sync_photos_duration";

/// 最後に写真を自動同期した時刻
const SP_LAST_PHOTOS_SYNCED_AT = "last_photos_synced_at";

/// 1度に同期する写真の枚数
const SP_SYNC_PHOTOS_PER_TIME = "sync_photos_per_time";

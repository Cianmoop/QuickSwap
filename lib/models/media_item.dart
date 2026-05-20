/// 单条媒体的传输元数据。
///
/// 与发送端 HTTP `GET /list` 返回的 JSON 字段一一对应；
/// 接收端据此展示列表、做增量比对，并用 [id] 请求 `GET /file/{id}`。
class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
    this.fingerprint,
  });

  /// photo_manager 中 AssetEntity 的唯一标识，也作为下载 URL 路径参数。
  final String id;

  /// 展示用文件名；可能与系统相册中的 title 一致。
  final String name;

  /// 文件字节大小，用于列表展示与增量指纹。
  final int size;

  /// 媒体类型：`image` 或 `video`。
  final String type;

  /// 增量传输指纹，格式为 `name_size`；远端与本地比对时优先使用此字段。
  final String? fingerprint;

  bool get isVideo => type == 'video';

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'unknown',
      size: (json['size'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'image',
      fingerprint: json['fingerprint'] as String?,
    );
  }

  /// 序列化为 JSON，供发送端 `/list` 接口返回。
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'type': type,
        if (fingerprint != null) 'fingerprint': fingerprint,
      };

  /// 生成本地/远端共用的「是否已存在」指纹。
  ///
  /// 未使用 MD5 是为了避免对大文件做全量哈希；换机场景下「文件名+大小」通常足够。
  static String buildFingerprint(String name, int size) => '${name}_$size';
}

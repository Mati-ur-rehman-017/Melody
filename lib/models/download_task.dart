enum DownloadStatus { pending, downloading, completed, failed }

class DownloadTask {
  final String videoId;
  String title;
  String author;
  String? thumbnailUrl;
  DownloadStatus status;
  double progress;
  String? errorMessage;
  String? userFacingMessage;
  DateTime startedAt;
  DateTime? completedAt;
  int retryCount;

  DownloadTask({
    required this.videoId,
    required this.title,
    required this.author,
    this.thumbnailUrl,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.userFacingMessage,
    DateTime? startedAt,
    this.completedAt,
    this.retryCount = 0,
  }) : startedAt = startedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'video_id': videoId,
      'title': title,
      'author': author,
      'thumbnail_url': thumbnailUrl,
      'status': status.index,
      'progress': progress,
      'error_message': errorMessage,
      'user_facing_message': userFacingMessage,
      'started_at': startedAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'retry_count': retryCount,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      videoId: map['video_id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      status: DownloadStatus.values[map['status'] as int],
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['error_message'] as String?,
      userFacingMessage: map['user_facing_message'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }
}

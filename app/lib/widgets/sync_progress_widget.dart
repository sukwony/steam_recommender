import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';

class SyncProgressWidget extends StatelessWidget {
  final SyncProgress progress;
  final VoidCallback? onCancel;

  const SyncProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (progress.status == SyncStatus.idle) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (progress.message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        progress.message!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (progress.status == SyncStatus.completed)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                )
              else if (progress.status == SyncStatus.error)
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 24,
                ),
            ],
          ),
          if (_showProgressBar()) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: AppTheme.cardColor,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.current} / ${progress.total}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (progress.status == SyncStatus.error && progress.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                progress.error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = _getStatusColor();
    
    if (progress.status == SyncStatus.completed) {
      return Icon(Icons.cloud_done, color: color, size: 28);
    } else if (progress.status == SyncStatus.error) {
      return Icon(Icons.cloud_off, color: color, size: 28);
    } else {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
  }

  String _getStatusTitle() {
    switch (progress.status) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.fetchingLibrary:
        return 'Fetching Steam Library';
      case SyncStatus.enrichingSteam:
        return 'Loading Game Details';
      case SyncStatus.enrichingHltb:
        return 'Fetching HowLongToBeat Data';
      case SyncStatus.saving:
        return 'Saving Games';
      case SyncStatus.completed:
        return 'Sync Complete!';
      case SyncStatus.error:
        return 'Sync Failed';
    }
  }

  Color _getStatusColor() {
    switch (progress.status) {
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }

  bool _showProgressBar() {
    return progress.total > 0 &&
        progress.status != SyncStatus.completed &&
        progress.status != SyncStatus.error;
  }
}

# Synchronized Lyrics Specification & Client Protocol

## 1. Data Contract
Synchronized lyrics in Hums are modeled as an ordered list of `LyricLine` objects:
- `sequence`: Zero-based integer defining line order.
- `start_ms`: Playback timestamp in milliseconds when vocalization starts.
- `end_ms`: (Optional) Playback timestamp in milliseconds when vocalization concludes.
- `text`: Displayable string representing the line.

## 2. Active Line Resolution via Binary Search
Audio players emit playback positions continuously. Rather than scanning arrays linearly ($O(N)$), the client computes the active line using binary search ($O(\log N)$):

```dart
int findLineIndexForPosition(int positionMs) {
  if (lines.isEmpty || positionMs < lines.first.startMs) return -1;
  int low = 0, high = lines.length - 1, result = -1;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (lines[mid].startMs <= positionMs) {
      result = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  if (result != -1 && lines[result].endMs != null) {
    if (positionMs - lines[result].endMs! > 3000) return -1;
  }
  return result;
}
```

## 3. UI Synchronization Flow
1. **Highlighting**:
   - The active line receives highlighted foreground styling (`AppColors.textPrimary`), prominent font weight (`FontWeight.w700`), larger font size (`22px`), and a subtle accent container tint.
   - Non-active lines are dimmed (`AppColors.textTertiary`) at `17px`.
2. **Auto-Scroll**:
   - When active line index changes and the user is not actively scrolling, `ScrollController.animateTo` gently shifts the target line toward the upper third of the viewport.
3. **Manual Scroll Override & Recovery**:
   - If the user gestures or drags the list, auto-scrolling is immediately paused (`isUserScrolling = true`).
   - A floating "Jump to current line" button appears at the bottom.
   - Tapping the button or allowing 5 seconds of idle inactivity restores automatic tracking.
4. **Tap-to-Seek**:
   - Tapping any lyric tile immediately invokes `ref.read(audioPlayerNotifierProvider.notifier).seek(Duration(milliseconds: line.startMs))`.
   - Audio position jumps immediately, triggering normal stream updates and instant active line recalculation.

# Lyrics Limitations & Boundary Conditions

## 1. Instrumental and Non-Vocal Tracks
- For instrumental, ambient, or beat tracks without vocals, lyrics status is marked `UNAVAILABLE`.
- In the mobile client, non-vocal tracks clearly display "No lyrics available for this track" rather than empty blank views or arbitrary text fragments.

## 2. Low-Confidence or Noisy Audio
- When Gemini cannot transcribe with high vocal confidence, timestamps are omitted and plain lyrics are returned.
- If no reliable lyrics can be retrieved, status remains `UNAVAILABLE` and the user is provided with a "Generate with AI" or manual upload capability.

## 3. Network and Offline Scenarios
- When a track is downloaded offline, lyrics are cached at `downloads/{userId}/{trackId}/lyrics.json`.
- If the track was never downloaded and device is offline, a polite offline/retry message is shown.

## 4. Large Transcripts
- For long podcasts or extended speech, line lookup continues to operate in $O(\log N)$ via binary search.
- Auto-scroll smoothly clamps between `0` and `maxScrollExtent` without layout overflow.

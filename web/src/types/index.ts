// Core User & Auth Types
export type UserRole = "listener" | "creator" | "moderator" | "admin";

export interface User {
  id: string;
  email: string;
  username?: string | null;
  full_name?: string | null;
  role: UserRole;
  is_active: boolean;
  is_verified: boolean;
  suspension_reason?: string | null;
  created_at: string;
  last_login_at?: string | null;
  tracks_count?: number;
  has_creator_profile?: boolean;
  subscription_tier?: string;
  bio?: string | null;
  avatar_url?: string | null;
  creator_id?: string | null;
  creator_name?: string | null;
}

export interface AuthSession {
  user: User | null;
  isAuthenticated: boolean;
  role: UserRole;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  } | null;
}

export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  size: number;
  total_pages: number;
}

// Admin Dashboard & Management Types
export interface AdminDashboardStats {
  total_users: number;
  active_users_30d: number;
  total_creators: number;
  published_tracks: number;
  failed_uploads: number;
  pending_applications: number;
  pending_reports: number;
  subscriptions_summary: Record<string, number>;
  recent_activity: AdminAuditLog[];
}

export interface AdminCreatorItem {
  id: string;
  user_id?: string | null;
  user_email?: string | null;
  name: string;
  username?: string | null;
  bio?: string | null;
  avatar_url?: string | null;
  cover_image_url?: string | null;
  is_verified: boolean;
  followers_count: number;
  tracks_count: number;
  created_at: string;
}

export interface CreatorApplication {
  id: string;
  user_id: string;
  user_email?: string | null;
  user_name?: string | null;
  artist_name: string;
  bio?: string | null;
  genres?: string | null;
  portfolio_url?: string | null;
  status: "PENDING" | "APPROVED" | "REJECTED";
  reviewer_id?: string | null;
  review_notes?: string | null;
  created_at: string;
  reviewed_at?: string | null;
}

export interface AdminTrackItem {
  id: string;
  title: string;
  artist_name?: string | null;
  album_name?: string | null;
  genre?: string | null;
  duration_seconds?: number | null;
  status: "UPLOADED" | "PROCESSING" | "READY" | "FAILED" | "MODERATED";
  is_published: boolean;
  cover_image_key?: string | null;
  owner_id: string;
  owner_email?: string | null;
  created_at: string;
  likes_count: number;
  play_count: number;
  waveform_key?: string | null;
}

export interface ContentReport {
  id: string;
  reporter_id: string;
  reporter_email?: string | null;
  entity_type: "track" | "creator" | "user";
  entity_id: string;
  entity_name?: string | null;
  reason: "COPYRIGHT" | "INAPPROPRIATE" | "SPAM" | "HARASSMENT" | "OTHER" | string;
  description?: string | null;
  status: "PENDING" | "INVESTIGATING" | "RESOLVED" | "DISMISSED";
  moderator_id?: string | null;
  resolution_notes?: string | null;
  action_taken?: string | null;
  created_at: string;
  resolved_at?: string | null;
}

export interface AdminAuditLog {
  id: string;
  actor_id: string;
  actor_email: string;
  action: string;
  target_type: string;
  target_id: string;
  details?: Record<string, unknown> | null;
  reason?: string | null;
  ip_address?: string | null;
  created_at: string;
}

export interface SystemHealthStatus {
  database: boolean;
  redis: boolean;
  celery_broker: boolean;
  storage: boolean;
  environment: string;
  timestamp: string;
}

export interface AudioFileInfo {
  id: string;
  filename: string;
  file_size_bytes: number;
  mime_type: string;
  storage_key: string;
  created_at: string;
}

export interface AudioRenditionInfo {
  id: string;
  format: string;
  codec: string;
  bitrate_kbps: number;
  sample_rate?: number | null;
  channels?: number | null;
  duration_seconds?: number | null;
  file_size_bytes: number;
  storage_key: string;
}

export interface ProcessingJobInfo {
  id: string;
  job_type: string;
  status: "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED";
  attempts: number;
  error_message?: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProcessingJobItem {
  id: string;
  track_id: string;
  track_title?: string | null;
  job_type: string;
  status: "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED";
  attempts: number;
  error_message?: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreatorTrackDetail {
  id: string;
  title: string;
  artist_name?: string | null;
  album_name?: string | null;
  genre?: string | null;
  description?: string | null;
  duration_seconds?: number | null;
  status: "UPLOADED" | "PROCESSING" | "READY" | "FAILED" | "MODERATED";
  is_published: boolean;
  cover_image_key?: string | null;
  waveform_key?: string | null;
  likes_count: number;
  play_count: number;
  created_at: string;
  audio_files: AudioFileInfo[];
  renditions: AudioRenditionInfo[];
  processing_jobs: ProcessingJobInfo[];
}

export interface AdminTrackDetail {
  id: string;
  title: string;
  artist_name?: string | null;
  album_name?: string | null;
  genre?: string | null;
  description?: string | null;
  duration_seconds?: number | null;
  status: "UPLOADED" | "PROCESSING" | "READY" | "FAILED" | "MODERATED";
  is_published: boolean;
  cover_image_key?: string | null;
  waveform_key?: string | null;
  likes_count: number;
  play_count: number;
  created_at: string;
  owner?: {
    id: string;
    email: string;
    name?: string | null;
    role: string;
    is_active: boolean;
  } | null;
  creator?: {
    id: string;
    name: string;
    is_verified: boolean;
  } | null;
  renditions: AudioRenditionInfo[];
  processing_jobs: ProcessingJobInfo[];
  audit_logs: AdminAuditLog[];
}

// Bulk Actions
export interface BulkItemResult {
  track_id: string;
  title?: string | null;
  status: "success" | "failed";
  message?: string | null;
  error?: string | null;
}

export interface BulkTrackActionResult {
  action: string;
  total: number;
  succeeded: number;
  failed: number;
  results: BulkItemResult[];
}

export interface CreatorBulkTrackActionRequest {
  track_ids: string[];
  action: "publish" | "unpublish" | "retry" | "update_metadata";
  genre?: string;
  title?: string;
  artist_name?: string;
  album_name?: string;
  description?: string;
  data?: Record<string, unknown>;
}

export interface AdminBulkTrackActionRequest {
  track_ids: string[];
  action: "moderate" | "retry" | "publish" | "unpublish" | "update_metadata";
  reason: string;
  target_status?: "READY" | "MODERATED" | "FAILED";
  status?: "READY" | "MODERATED" | "FAILED";
  data?: Record<string, unknown>;
  metadata_updates?: Record<string, unknown>;
}

export interface TrackArtworkUploadResponse {
  track_id: string;
  cover_image_key: string;
  cover_image_url?: string | null;
}

// Creator Studio Types
export interface CreatorDashboardStats {
  published_tracks: number;
  processing_tracks: number;
  failed_uploads: number;
  total_plays: number;
  follower_count: number;
  total_likes: number;
  top_tracks: CreatorTrackItem[];
  recent_uploads: CreatorTrackItem[];
}

export interface CreatorTrackItem {
  id: string;
  title: string;
  artist_name?: string | null;
  album_name?: string | null;
  genre?: string | null;
  duration_seconds?: number | null;
  status: "UPLOADED" | "PROCESSING" | "READY" | "FAILED" | "MODERATED";
  is_published: boolean;
  cover_image_key?: string | null;
  likes_count: number;
  play_count: number;
  created_at: string;
  waveform_key?: string | null;
}

export interface CreatorAnalytics {
  period: string;
  total_plays: number;
  unique_listeners: number;
  plays_timeline: Array<{ date: string; plays: number }>;
  top_tracks: Array<{ track_id: string; title: string; plays: number }>;
  sources_breakdown: Record<string, number>;
}

export interface CreatorStudioProfile {
  id: string;
  user_id?: string | null;
  name: string;
  username?: string | null;
  bio?: string | null;
  avatar_url?: string | null;
  cover_image_url?: string | null;
  is_verified: boolean;
  followers_count: number;
  created_at: string;
}

// Notification & Activity Center Types
export type NotificationType =
  | "NEW_RELEASE"
  | "PLAYLIST_UPDATE"
  | "UPLOAD_COMPLETE"
  | "TRANSCRIPTION_COMPLETE"
  | "RECOMMENDATION_READY"
  | "SYSTEM"
  | "TRACK_MODERATED"
  | "TRACK_PUBLISHED"
  | "TRACK_PROCESSING_FAILED"
  | "CREATOR_APPLICATION";

export interface NotificationItem {
  id: string;
  type: NotificationType | string;
  title: string;
  body: string;
  data?: Record<string, unknown> | null;
  is_read: boolean;
  read_at?: string | null;
  created_at: string;
}

export interface NotificationListResponse {
  items: NotificationItem[];
  total: number;
  skip: number;
  limit: number;
}

export interface UnreadCountResponse {
  unread_count: number;
}

export interface NotificationPreferences {
  push_enabled: boolean;
  new_releases_enabled: boolean;
  playlist_updates_enabled: boolean;
  recommendations_enabled: boolean;
  processing_updates_enabled: boolean;
}

export interface NotificationPreferencesUpdate {
  push_enabled?: boolean;
  new_releases_enabled?: boolean;
  playlist_updates_enabled?: boolean;
  recommendations_enabled?: boolean;
  processing_updates_enabled?: boolean;
}


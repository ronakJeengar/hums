import {
  AdminAuditLog,
  AdminCreatorItem,
  AdminDashboardStats,
  AdminTrackItem,
  ContentReport,
  CreatorAnalytics,
  CreatorApplication,
  CreatorDashboardStats,
  CreatorStudioProfile,
  CreatorTrackItem,
  PaginatedResult,
  ProcessingJobItem,
  SystemHealthStatus,
  User,
  UserRole,
} from "@/types";

export class ApiError extends Error {
  code?: string;
  status: number;
  details?: unknown;

  constructor(message: string, status: number = 500, code?: string, details?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const isServer = typeof window === "undefined";
  const baseUrl = isServer
    ? (process.env.INTERNAL_API_URL || "http://127.0.0.1:8001") + "/api/v1"
    : "/api/proxy";


  const cleanPath = path.startsWith("/") ? path.slice(1) : path;
  const url = `${baseUrl}/${cleanPath}`;

  const headers: Record<string, string> = {
    ...(options.headers as Record<string, string>),
  };

  if (!(options.body instanceof FormData) && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }

  const res = await fetch(url, {
    ...options,
    headers,
    credentials: isServer ? undefined : "same-origin",
  });

  const contentType = res.headers.get("content-type");
  const isJson = contentType && contentType.includes("application/json");
  const data = isJson ? await res.json() : null;

  if (!res.ok) {
    const errorMsg =
      data?.error?.message ||
      data?.detail ||
      res.statusText ||
      `Request failed with status ${res.status}`;
    throw new ApiError(errorMsg, res.status, data?.error?.code, data?.error?.details);
  }

  // If response wrapped in ApiResponse { success, data }
  if (data && typeof data === "object" && "success" in data && "data" in data) {
    return data.data as T;
  }

  return (data as T) ?? ({} as T);
}

export const api = {
  // Auth (Direct to BFF Auth routes)
  auth: {
    async login(email: string, password: string): Promise<{ user: User }> {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new ApiError(data?.error?.message || "Login failed", res.status);
      }
      return data.data;
    },

    async logout(): Promise<void> {
      await fetch("/api/auth/logout", { method: "POST" });
    },

    async getMe(): Promise<User> {
      const res = await fetch("/api/auth/me");
      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new ApiError("Session expired", res.status);
      }
      return data.data.user;
    },
  },

  // Admin APIs
  admin: {
    async getDashboard(): Promise<AdminDashboardStats> {
      return request<AdminDashboardStats>("admin/dashboard");
    },

    async getUsers(params: {
      page?: number;
      size?: number;
      search?: string;
      role?: string;
      status?: string;
    } = {}): Promise<PaginatedResult<User>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.search) query.set("search", params.search);
      if (params.role) query.set("role", params.role);
      if (params.status) query.set("status", params.status);
      return request<PaginatedResult<User>>(`admin/users?${query.toString()}`);
    },

    async getUserDetail(id: string): Promise<User> {
      return request<User>(`admin/users/${id}`);
    },

    async updateUserStatus(id: string, is_active: boolean, reason?: string): Promise<User> {
      return request<User>(`admin/users/${id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ is_active, reason }),
      });
    },

    async updateUserRole(id: string, role: UserRole, reason?: string): Promise<User> {
      return request<User>(`admin/users/${id}/role`, {
        method: "PATCH",
        body: JSON.stringify({ role, reason }),
      });
    },

    async getCreators(params: {
      page?: number;
      size?: number;
      search?: string;
    } = {}): Promise<PaginatedResult<AdminCreatorItem>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.search) query.set("search", params.search);
      return request<PaginatedResult<AdminCreatorItem>>(`admin/creators?${query.toString()}`);
    },

    async verifyCreator(id: string, is_verified: boolean, reason?: string): Promise<AdminCreatorItem> {
      return request<AdminCreatorItem>(`admin/creators/${id}/verify`, {
        method: "PATCH",
        body: JSON.stringify({ is_verified, reason }),
      });
    },

    async getApplications(params: {
      page?: number;
      size?: number;
      status?: string;
    } = {}): Promise<PaginatedResult<CreatorApplication>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.status) query.set("status", params.status);
      return request<PaginatedResult<CreatorApplication>>(
        `admin/creator-applications?${query.toString()}`
      );
    },

    async reviewApplication(
      id: string,
      status: "APPROVED" | "REJECTED",
      review_notes?: string
    ): Promise<CreatorApplication> {
      return request<CreatorApplication>(`admin/creator-applications/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status, review_notes }),
      });
    },

    async getTracks(params: {
      page?: number;
      size?: number;
      search?: string;
      status?: string;
      genre?: string;
    } = {}): Promise<PaginatedResult<AdminTrackItem>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.search) query.set("search", params.search);
      if (params.status) query.set("status", params.status);
      if (params.genre) query.set("genre", params.genre);
      return request<PaginatedResult<AdminTrackItem>>(`admin/tracks?${query.toString()}`);
    },

    async getTrackDetail(id: string): Promise<AdminTrackItem> {
      return request<AdminTrackItem>(`admin/tracks/${id}`);
    },

    async moderateTrack(
      id: string,
      status: "READY" | "MODERATED" | "FAILED",
      reason: string
    ): Promise<AdminTrackItem> {
      return request<AdminTrackItem>(`admin/tracks/${id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ status, reason }),
      });
    },

    async retryTrack(id: string): Promise<{ message: string }> {
      return request<{ message: string }>(`admin/tracks/${id}/retry`, {
        method: "POST",
      });
    },

    async getReports(params: {
      page?: number;
      size?: number;
      status?: string;
      reason?: string;
      entity_type?: string;
    } = {}): Promise<PaginatedResult<ContentReport>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.status) query.set("status", params.status);
      if (params.reason) query.set("reason", params.reason);
      if (params.entity_type) query.set("entity_type", params.entity_type);
      return request<PaginatedResult<ContentReport>>(`admin/reports?${query.toString()}`);
    },

    async resolveReport(
      id: string,
      status: "RESOLVED" | "DISMISSED" | "INVESTIGATING",
      action_taken?: string,
      resolution_notes?: string
    ): Promise<ContentReport> {
      return request<ContentReport>(`admin/reports/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status, action_taken, resolution_notes }),
      });
    },

    async getOperationsHealth(): Promise<SystemHealthStatus> {
      return request<SystemHealthStatus>("admin/operations/health");
    },

    async getProcessingJobs(params: {
      page?: number;
      size?: number;
      status?: string;
    } = {}): Promise<PaginatedResult<ProcessingJobItem>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.status) query.set("status", params.status);
      return request<PaginatedResult<ProcessingJobItem>>(
        `admin/operations/jobs?${query.toString()}`
      );
    },

    async getAuditLogs(params: {
      page?: number;
      size?: number;
      action?: string;
      target_type?: string;
      search?: string;
    } = {}): Promise<PaginatedResult<AdminAuditLog>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.action) query.set("action", params.action);
      if (params.target_type) query.set("target_type", params.target_type);
      if (params.search) query.set("search", params.search);
      return request<PaginatedResult<AdminAuditLog>>(`admin/audit-logs?${query.toString()}`);
    },
  },

  // Creator Studio APIs
  studio: {
    async getDashboard(): Promise<CreatorDashboardStats> {
      return request<CreatorDashboardStats>("creator-studio/dashboard");
    },

    async getTracks(params: {
      page?: number;
      size?: number;
      status?: string;
      search?: string;
    } = {}): Promise<PaginatedResult<CreatorTrackItem>> {
      const query = new URLSearchParams();
      if (params.page) query.set("page", params.page.toString());
      if (params.size) query.set("size", params.size.toString());
      if (params.status) query.set("status", params.status);
      if (params.search) query.set("search", params.search);
      return request<PaginatedResult<CreatorTrackItem>>(
        `creator-studio/tracks?${query.toString()}`
      );
    },

    async updateTrack(
      id: string,
      data: {
        title?: string;
        artist_name?: string;
        album_name?: string;
        genre?: string;
        description?: string;
      }
    ): Promise<CreatorTrackItem> {
      return request<CreatorTrackItem>(`creator-studio/tracks/${id}`, {
        method: "PATCH",
        body: JSON.stringify(data),
      });
    },

    async retryTrack(id: string): Promise<{ message: string }> {
      return request<{ message: string }>(`creator-studio/tracks/${id}/retry`, {
        method: "POST",
      });
    },

    async getAnalytics(period: "7d" | "30d" | "90d" = "30d"): Promise<CreatorAnalytics> {
      return request<CreatorAnalytics>(`creator-studio/analytics?period=${period}`);
    },

    async getProfile(): Promise<CreatorStudioProfile> {
      return request<CreatorStudioProfile>("creator-studio/profile");
    },

    async updateProfile(data: {
      name?: string;
      bio?: string;
      avatar_url?: string;
      cover_image_url?: string;
    }): Promise<CreatorStudioProfile> {
      return request<CreatorStudioProfile>("creator-studio/profile", {
        method: "PATCH",
        body: JSON.stringify(data),
      });
    },
  },

  // Listener / Common APIs
  listener: {
    async submitApplication(data: {
      artist_name: string;
      bio?: string;
      genres?: string;
      portfolio_url?: string;
    }): Promise<CreatorApplication> {
      return request<CreatorApplication>("creator-applications", {
        method: "POST",
        body: JSON.stringify(data),
      });
    },

    async getMyApplication(): Promise<CreatorApplication | null> {
      return request<CreatorApplication | null>("creator-applications/me");
    },

    async submitReport(data: {
      entity_type: "track" | "creator" | "user";
      entity_id: string;
      reason: string;
      description?: string;
    }): Promise<ContentReport> {
      return request<ContentReport>("reports", {
        method: "POST",
        body: JSON.stringify(data),
      });
    },
  },
};

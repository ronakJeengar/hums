import React from "react";
import "@testing-library/jest-dom/vitest";
import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { NotificationBell } from "@/components/shared/notification-bell";
import { ActivityCenterView } from "@/components/shared/activity-center-view";
import { api } from "@/lib/api/client";
import { User } from "@/types";

vi.mock("next/navigation", () => ({
  useRouter: () => ({
    push: vi.fn(),
    refresh: vi.fn(),
  }),
  usePathname: () => "/admin/dashboard",
}));

vi.mock("@/lib/api/client", () => ({
  api: {
    notifications: {
      getUnreadCount: vi.fn(),
      list: vi.fn(),
      markAsRead: vi.fn(),
      markAllAsRead: vi.fn(),
      getPreferences: vi.fn(),
      updatePreferences: vi.fn(),
    },
  },
}));

const mockUser: User = {
  id: "usr-123",
  email: "creator@hums.app",
  full_name: "Test Creator",
  role: "creator",
  is_active: true,
  is_verified: true,
  created_at: new Date().toISOString(),
};

function renderWithQueryClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });
  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>);
}

describe("Notifications & Activity Center Components", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders NotificationBell and displays unread count badge", async () => {
    vi.mocked(api.notifications.getUnreadCount).mockResolvedValue({ unread_count: 5 });
    vi.mocked(api.notifications.list).mockResolvedValue({
      items: [
        {
          id: "notif-1",
          type: "TRACK_PUBLISHED",
          title: "Track Published!",
          body: "Your track 'Midnight Groove' is now live.",
          is_read: false,
          created_at: new Date().toISOString(),
        },
      ],
      total: 1,
      skip: 0,
      limit: 6,
    });

    renderWithQueryClient(<NotificationBell user={mockUser} />);

    // Unread badge should appear with count 5
    const badge = await screen.findByText("5");
    expect(badge).toBeInTheDocument();

    // Clicking bell opens dropdown popover
    const bellBtn = screen.getByRole("button", { name: /view notifications/i });
    fireEvent.click(bellBtn);

    expect(await screen.findByText("Midnight Groove", { exact: false })).toBeInTheDocument();
    expect(screen.getByText("Open Activity Center")).toBeInTheDocument();
  });

  it("renders ActivityCenterView with tabs and notification items", async () => {
    vi.mocked(api.notifications.getUnreadCount).mockResolvedValue({ unread_count: 2 });
    vi.mocked(api.notifications.list).mockResolvedValue({
      items: [
        {
          id: "notif-10",
          type: "UPLOAD_COMPLETE",
          title: "Track Ready",
          body: "Your audio track has finished transcoding.",
          is_read: false,
          created_at: new Date().toISOString(),
        },
        {
          id: "notif-11",
          type: "TRACK_MODERATED",
          title: "Track Moderation",
          body: "Your track was approved by administrator.",
          is_read: true,
          created_at: new Date().toISOString(),
        },
      ],
      total: 2,
      skip: 0,
      limit: 15,
    });
    vi.mocked(api.notifications.getPreferences).mockResolvedValue({
      push_enabled: true,
      new_releases_enabled: true,
      playlist_updates_enabled: true,
      recommendations_enabled: true,
      processing_updates_enabled: true,
    });

    renderWithQueryClient(<ActivityCenterView experience="studio" />);

    // Verify header and tabs
    expect(screen.getByText("Activity Center")).toBeInTheDocument();
    expect(screen.getByText("All Notifications")).toBeInTheDocument();
    expect(screen.getByText("Unread Only")).toBeInTheDocument();
    expect(screen.getByText("Notification Settings")).toBeInTheDocument();

    // Verify items loaded
    expect(await screen.findByText("Track Ready")).toBeInTheDocument();
    expect(screen.getByText("Track Moderation")).toBeInTheDocument();

    // Switch to settings tab
    const settingsTab = screen.getByText("Notification Settings");
    fireEvent.click(settingsTab);

    // Verify preferences toggles
    expect(await screen.findByText("Delivery & Channel Preferences")).toBeInTheDocument();
    expect(screen.getByText("Audio Processing & Transcoding")).toBeInTheDocument();
    expect(screen.getByText("Personalized Recommendations")).toBeInTheDocument();
  });
});

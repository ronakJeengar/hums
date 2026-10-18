import { describe, expect, it } from "vitest";
import {
  canAccessAdmin,
  canAccessStudio,
  canManageUsers,
  canModerateContent,
  getDefaultDashboardRoute,
  hasMinimumRole,
} from "@/lib/permissions/roles";

describe("Role Permissions & Routing", () => {
  it("enforces correct role hierarchy", () => {
    expect(hasMinimumRole("admin", "moderator")).toBe(true);
    expect(hasMinimumRole("moderator", "creator")).toBe(true);
    expect(hasMinimumRole("creator", "listener")).toBe(true);
    expect(hasMinimumRole("listener", "admin")).toBe(false);
    expect(hasMinimumRole("creator", "moderator")).toBe(false);
  });

  it("permits only admin and moderator to access admin panel", () => {
    expect(canAccessAdmin("admin")).toBe(true);
    expect(canAccessAdmin("moderator")).toBe(true);
    expect(canAccessAdmin("creator")).toBe(false);
    expect(canAccessAdmin("listener")).toBe(false);
    expect(canAccessAdmin(null)).toBe(false);
  });

  it("permits only creator and admin to access creator studio", () => {
    expect(canAccessStudio("creator")).toBe(true);
    expect(canAccessStudio("admin")).toBe(true);
    expect(canAccessStudio("moderator")).toBe(false);
    expect(canAccessStudio("listener")).toBe(false);
  });

  it("restricts user role and suspension operations to admin", () => {
    expect(canManageUsers("admin")).toBe(true);
    expect(canManageUsers("moderator")).toBe(false);
    expect(canManageUsers("creator")).toBe(false);
  });

  it("permits both moderator and admin to moderate content", () => {
    expect(canModerateContent("admin")).toBe(true);
    expect(canModerateContent("moderator")).toBe(true);
    expect(canModerateContent("creator")).toBe(false);
  });

  it("routes users to appropriate workspace default based on role", () => {
    expect(getDefaultDashboardRoute("admin")).toBe("/admin/dashboard");
    expect(getDefaultDashboardRoute("moderator")).toBe("/admin/dashboard");
    expect(getDefaultDashboardRoute("creator")).toBe("/studio/dashboard");
    expect(getDefaultDashboardRoute("listener")).toBe("/apply-creator");
  });
});

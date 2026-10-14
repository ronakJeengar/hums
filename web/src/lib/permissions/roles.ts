import { UserRole } from "@/types";

export const ROLE_HIERARCHY: Record<UserRole, number> = {
  admin: 40,
  moderator: 30,
  creator: 20,
  listener: 10,
};

export function hasMinimumRole(userRole: UserRole, requiredRole: UserRole): boolean {
  return (ROLE_HIERARCHY[userRole] ?? 0) >= (ROLE_HIERARCHY[requiredRole] ?? 0);
}

export function canAccessAdmin(role?: UserRole | null): boolean {
  if (!role) return false;
  return role === "admin" || role === "moderator";
}

export function canAccessStudio(role?: UserRole | null): boolean {
  if (!role) return false;
  return role === "creator" || role === "admin";
}

export function canManageUsers(role?: UserRole | null): boolean {
  return role === "admin";
}

export function canViewAuditLogs(role?: UserRole | null): boolean {
  return role === "admin";
}

export function canCheckOperationsHealth(role?: UserRole | null): boolean {
  return role === "admin";
}

export function canModerateContent(role?: UserRole | null): boolean {
  return role === "admin" || role === "moderator";
}

export function getDefaultDashboardRoute(role?: UserRole | null): string {
  if (role === "admin" || role === "moderator") {
    return "/admin/dashboard";
  }
  if (role === "creator") {
    return "/studio/dashboard";
  }
  return "/apply-creator";
}

"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import {
  Ban,
  CheckCircle,
  Eye,
  MoreHorizontal,
  Search,
  Shield,
  UserCheck,
  UserX,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate } from "@/lib/utils";
import { User, UserRole } from "@/types";

export default function AdminUsersPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");
  const [roleFilter, setRoleFilter] = React.useState<string>("");
  const [statusFilter, setStatusFilter] = React.useState<string>("");

  // Modals state
  const [selectedUser, setSelectedUser] = React.useState<User | null>(null);
  const [isDetailOpen, setIsDetailOpen] = React.useState(false);
  const [isRoleModalOpen, setIsRoleModalOpen] = React.useState(false);
  const [isStatusModalOpen, setIsStatusModalOpen] = React.useState(false);

  // Form states for modals
  const [targetRole, setTargetRole] = React.useState<UserRole>("listener");
  const [actionReason, setActionReason] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users", page, search, roleFilter, statusFilter],
    queryFn: () =>
      api.admin.getUsers({
        page,
        size: 20,
        search: search || undefined,
        role: roleFilter || undefined,
        status: statusFilter || undefined,
      }),
  });

  // Role update mutation
  const roleMutation = useMutation({
    mutationFn: ({ userId, role, reason }: { userId: string; role: UserRole; reason: string }) =>
      api.admin.updateUserRole(userId, role, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      setIsRoleModalOpen(false);
      setActionReason("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to update role");
    },
  });

  // Status update mutation (suspend/reactivate)
  const statusMutation = useMutation({
    mutationFn: ({ userId, isActive, reason }: { userId: string; isActive: boolean; reason: string }) =>
      api.admin.updateUserStatus(userId, isActive, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      setIsStatusModalOpen(false);
      setActionReason("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to update status");
    },
  });

  const columns: ColumnDef<User>[] = [
    {
      accessorKey: "email",
      header: "User",
      cell: ({ row }) => {
        const u = row.original;
        return (
          <div>
            <div className="font-medium text-slate-100 flex items-center gap-1.5">
              <span>{u.full_name || u.email.split("@")[0]}</span>
              {u.is_verified && (
                <CheckCircle className="h-3.5 w-3.5 text-purple-400 shrink-0" />
              )}
            </div>
            <div className="text-xs text-slate-400">{u.email}</div>
          </div>
        );
      },
    },
    {
      accessorKey: "role",
      header: "Platform Role",
      cell: ({ row }) => {
        const role = row.original.role;
        return (
          <Badge
            variant={
              role === "admin"
                ? "purple"
                : role === "moderator"
                ? "info"
                : role === "creator"
                ? "success"
                : "default"
            }
          >
            {role}
          </Badge>
        );
      },
    },
    {
      accessorKey: "is_active",
      header: "Status",
      cell: ({ row }) => {
        const isActive = row.original.is_active;
        return (
          <StatusBadge status={isActive ? "ACTIVE" : "SUSPENDED"} />
        );
      },
    },
    {
      accessorKey: "tracks_count",
      header: "Tracks",
      cell: ({ row }) => row.original.tracks_count ?? 0,
    },
    {
      accessorKey: "subscription_tier",
      header: "Plan Tier",
      cell: ({ row }) => (
        <span className="text-xs font-medium text-slate-300">
          {row.original.subscription_tier || "FREE"}
        </span>
      ),
    },
    {
      accessorKey: "created_at",
      header: "Joined",
      cell: ({ row }) => formatDate(row.original.created_at),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const u = row.original;
        return (
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setSelectedUser(u);
                setIsDetailOpen(true);
              }}
              title="View Details"
            >
              <Eye className="h-3.5 w-3.5 text-slate-400" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setSelectedUser(u);
                setTargetRole(u.role);
                setModalError(null);
                setIsRoleModalOpen(true);
              }}
              title="Change Role"
            >
              <Shield className="h-3.5 w-3.5 text-purple-400" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setSelectedUser(u);
                setModalError(null);
                setIsStatusModalOpen(true);
              }}
              className={u.is_active ? "hover:text-rose-400" : "hover:text-emerald-400"}
              title={u.is_active ? "Suspend User" : "Reactivate User"}
            >
              {u.is_active ? (
                <UserX className="h-3.5 w-3.5 text-rose-400" />
              ) : (
                <UserCheck className="h-3.5 w-3.5 text-emerald-400" />
              )}
            </Button>
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          User Management
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Search, inspect, elevate privileges, and enforce account suspensions
        </p>
      </div>

      {/* Filter Controls */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full sm:w-64">
          <Input
            placeholder="Search email or username..."
            icon={<Search className="h-4 w-4" />}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </div>

        <select
          value={roleFilter}
          onChange={(e) => {
            setRoleFilter(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Roles</option>
          <option value="listener">Listener</option>
          <option value="creator">Creator</option>
          <option value="moderator">Moderator</option>
          <option value="admin">Administrator</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Statuses</option>
          <option value="active">Active Only</option>
          <option value="suspended">Suspended Only</option>
        </select>
      </div>

      {/* User Table */}
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        page={page}
        totalPages={data?.total_pages ?? 1}
        total={data?.total}
        onPageChange={(newPage) => setPage(newPage)}
      />

      {/* View User Detail Modal */}
      <Dialog
        open={isDetailOpen}
        onOpenChange={setIsDetailOpen}
        title="User Account Details"
        description={selectedUser?.id}
        footer={
          <Button variant="secondary" size="sm" onClick={() => setIsDetailOpen(false)}>
            Close
          </Button>
        }
      >
        {selectedUser && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4 text-xs">
              <div>
                <span className="text-slate-500 block">Email Address</span>
                <span className="font-medium text-slate-200">{selectedUser.email}</span>
              </div>
              <div>
                <span className="text-slate-500 block">Username</span>
                <span className="font-medium text-slate-200">
                  {selectedUser.username || "—"}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">Platform Role</span>
                <Badge variant="purple" className="mt-1">
                  {selectedUser.role}
                </Badge>
              </div>
              <div>
                <span className="text-slate-500 block">Account Status</span>
                <div className="mt-1">
                  <StatusBadge status={selectedUser.is_active ? "ACTIVE" : "SUSPENDED"} />
                </div>
              </div>
              <div>
                <span className="text-slate-500 block">Subscription Tier</span>
                <span className="font-medium text-slate-200">
                  {selectedUser.subscription_tier || "FREE"}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block">Has Creator Profile</span>
                <span className="font-medium text-slate-200">
                  {selectedUser.has_creator_profile ? "Yes" : "No"}
                </span>
              </div>
            </div>

            {selectedUser.suspension_reason && (
              <div className="p-3 rounded-lg border border-rose-900/40 bg-rose-950/20 text-xs">
                <span className="font-semibold text-rose-400 block mb-1">
                  Suspension Reason:
                </span>
                <p className="text-rose-200">{selectedUser.suspension_reason}</p>
              </div>
            )}
          </div>
        )}
      </Dialog>

      {/* Change Role Modal */}
      <Dialog
        open={isRoleModalOpen}
        onOpenChange={setIsRoleModalOpen}
        title="Update Platform Role"
        description={`Modify permissions and access privileges for ${selectedUser?.email}`}
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsRoleModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              isLoading={roleMutation.isPending}
              onClick={() => {
                if (!selectedUser) return;
                roleMutation.mutate({
                  userId: selectedUser.id,
                  role: targetRole,
                  reason: actionReason,
                });
              }}
            >
              Save Role
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {modalError && (
            <div className="p-2.5 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
              {modalError}
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Select New Role
            </label>
            <select
              value={targetRole}
              onChange={(e) => setTargetRole(e.target.value as UserRole)}
              className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="listener">Listener (Standard Streaming)</option>
              <option value="creator">Creator (Studio & Analytics)</option>
              <option value="moderator">Moderator (Reports & Takedowns)</option>
              <option value="admin">Administrator (Full Platform Control)</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Audit Reason (Required for accountability)
            </label>
            <textarea
              rows={3}
              placeholder="e.g., Promoted to trust and safety operations team..."
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>

      {/* Suspend / Reactivate Modal */}
      <Dialog
        open={isStatusModalOpen}
        onOpenChange={setIsStatusModalOpen}
        title={selectedUser?.is_active ? "Suspend User Account" : "Reactivate User Account"}
        description={`Changing account access for ${selectedUser?.email}`}
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsStatusModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant={selectedUser?.is_active ? "danger" : "primary"}
              size="sm"
              isLoading={statusMutation.isPending}
              onClick={() => {
                if (!selectedUser) return;
                statusMutation.mutate({
                  userId: selectedUser.id,
                  isActive: !selectedUser.is_active,
                  reason: actionReason,
                });
              }}
            >
              {selectedUser?.is_active ? "Confirm Suspension" : "Confirm Reactivation"}
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {modalError && (
            <div className="p-2.5 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
              {modalError}
            </div>
          )}

          <p className="text-xs text-slate-300">
            {selectedUser?.is_active
              ? "Suspending this user will immediately invalidate their active sessions and prevent further API access until reactivated."
              : "Reactivating this user will restore their ability to authenticate and use their account normally."}
          </p>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Reason for this action
            </label>
            <textarea
              rows={3}
              placeholder="Provide context for audit logging..."
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}

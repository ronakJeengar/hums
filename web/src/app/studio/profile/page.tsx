"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, Save, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatNumber } from "@/lib/utils";
import { CreatorStudioProfile } from "@/types";

function ProfileForm({ profile }: { profile: CreatorStudioProfile }) {
  const queryClient = useQueryClient();
  const [name, setName] = React.useState(profile.name || "");
  const [bio, setBio] = React.useState(profile.bio || "");
  const [avatarUrl, setAvatarUrl] = React.useState(profile.avatar_url || "");
  const [coverImageUrl, setCoverImageUrl] = React.useState(profile.cover_image_url || "");
  const [statusMessage, setStatusMessage] = React.useState<string | null>(null);
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null);

  const updateMutation = useMutation({
    mutationFn: (data: {
      name: string;
      bio?: string;
      avatar_url?: string;
      cover_image_url?: string;
    }) => api.studio.updateProfile(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-profile"] });
      setStatusMessage("Profile updated successfully!");
      setErrorMessage(null);
      setTimeout(() => setStatusMessage(null), 3000);
    },
    onError: (err: Error) => {
      setErrorMessage(err?.message || "Failed to update profile");
      setStatusMessage(null);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name) {
      setErrorMessage("Artist name is required.");
      return;
    }
    updateMutation.mutate({
      name,
      bio: bio || undefined,
      avatar_url: avatarUrl || undefined,
      cover_image_url: coverImageUrl || undefined,
    });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Profile Details</CardTitle>
        <CardDescription>
          Public details displayed on your artist landing page
        </CardDescription>
      </CardHeader>
      <CardContent>
        {statusMessage && (
          <div className="mb-4 p-3 rounded-lg bg-emerald-950/50 border border-emerald-800 text-xs text-emerald-300 flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
            <span>{statusMessage}</span>
          </div>
        )}

        {errorMessage && (
          <div className="mb-4 p-3 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
            {errorMessage}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Artist Name *
            </label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Solar Drift"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Biography / About
            </label>
            <textarea
              rows={4}
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              placeholder="Share your musical journey, influences, and upcoming projects..."
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Avatar Image URL
            </label>
            <Input
              value={avatarUrl}
              onChange={(e) => setAvatarUrl(e.target.value)}
              placeholder="https://cdn.hums.app/avatars/artist.png"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Banner Artwork URL
            </label>
            <Input
              value={coverImageUrl}
              onChange={(e) => setCoverImageUrl(e.target.value)}
              placeholder="https://cdn.hums.app/covers/banner.jpg"
            />
          </div>

          <Button
            type="submit"
            className="w-full"
            size="md"
            isLoading={updateMutation.isPending}
          >
            <Save className="h-4 w-4 mr-1.5" />
            Save Profile Changes
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

export default function CreatorProfilePage() {
  const { data: profile } = useQuery({
    queryKey: ["studio-profile"],
    queryFn: () => api.studio.getProfile(),
  });

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Artist Profile Settings
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Customize how your artist brand appears to listeners across Hums apps
        </p>
      </div>

      {/* Profile Overview Card */}
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="h-14 w-14 rounded-full bg-purple-950/80 border border-purple-800/60 flex items-center justify-center font-bold text-lg text-purple-300">
            {profile?.name ? profile.name.slice(0, 2).toUpperCase() : <User />}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-bold text-white">
                {profile?.name || "Artist"}
              </h2>
              {profile?.is_verified && (
                <Badge variant="purple">Verified Artist</Badge>
              )}
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              {formatNumber(profile?.followers_count ?? 0)} listeners following you
            </p>
          </div>
        </div>
      </div>

      {profile && <ProfileForm key={profile.id} profile={profile} />}
    </div>
  );
}

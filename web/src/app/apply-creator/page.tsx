"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  CheckCircle2,
  Clock,
  ExternalLink,
  Headphones,
  Music2,
  Send,
  Sparkles,
  XCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatDate } from "@/lib/utils";

export default function ApplyCreatorPage() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const [artistName, setArtistName] = React.useState("");
  const [bio, setBio] = React.useState("");
  const [genres, setGenres] = React.useState("");
  const [portfolioUrl, setPortfolioUrl] = React.useState("");
  const [formError, setFormError] = React.useState<string | null>(null);

  const { data: myApp, isLoading } = useQuery({
    queryKey: ["my-creator-application"],
    queryFn: () => api.listener.getMyApplication(),
  });

  const submitMutation = useMutation({
    mutationFn: (payload: {
      artist_name: string;
      bio?: string;
      genres?: string;
      portfolio_url?: string;
    }) => api.listener.submitApplication(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-creator-application"] });
      setFormError(null);
    },
    onError: (err: Error) => {
      setFormError(err?.message || "Failed to submit application");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!artistName) {
      setFormError("Artist name is required.");
      return;
    }
    submitMutation.mutate({
      artist_name: artistName,
      bio: bio || undefined,
      genres: genres || undefined,
      portfolio_url: portfolioUrl || undefined,
    });
  };

  return (
    <div className="min-h-screen bg-[#07090e] p-6 flex flex-col justify-between">
      <div className="max-w-2xl mx-auto w-full pt-8 space-y-8">
        {/* Header */}
        <div className="text-center space-y-2">
          <div className="inline-flex h-12 w-12 rounded-xl bg-gradient-to-tr from-purple-600 to-indigo-500 items-center justify-center shadow-lg shadow-purple-900/50 mb-2">
            <Music2 className="h-6 w-6 text-white" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-white">
            Join the Hums Creator Program
          </h1>
          <p className="text-sm text-slate-400 max-w-md mx-auto">
            Share your music with thousands of listeners, access detailed playback analytics, and manage your releases
          </p>
        </div>

        {/* Status of Existing Application if Present */}
        {myApp && (
          <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-xs uppercase font-semibold text-slate-500 block">
                  Application Status
                </span>
                <h3 className="text-base font-bold text-slate-100 mt-0.5">
                  {myApp.artist_name}
                </h3>
              </div>
              <StatusBadge status={myApp.status} />
            </div>

            <div className="text-xs text-slate-300">
              Submitted on <span className="font-medium text-slate-100">{formatDate(myApp.created_at)}</span>
            </div>

            {myApp.status === "PENDING" && (
              <div className="p-3 rounded-lg bg-amber-950/40 border border-amber-800/40 text-xs text-amber-300 flex items-center gap-2">
                <Clock className="h-4 w-4 shrink-0" />
                <span>
                  Your application is currently under review by our curation and trust team.
                </span>
              </div>
            )}

            {myApp.status === "APPROVED" && (
              <div className="p-4 rounded-lg bg-purple-950/40 border border-purple-800/40 space-y-2">
                <div className="text-xs font-semibold text-purple-300 flex items-center gap-1.5">
                  <CheckCircle2 className="h-4 w-4" />
                  <span>Congratulations! Your application has been approved.</span>
                </div>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => router.push("/studio/dashboard")}
                >
                  Enter Creator Studio
                </Button>
              </div>
            )}

            {myApp.status === "REJECTED" && (
              <div className="p-3 rounded-lg bg-rose-950/40 border border-rose-800/40 text-xs text-rose-300 space-y-1">
                <div className="font-semibold flex items-center gap-1.5">
                  <XCircle className="h-4 w-4" />
                  <span>Application Not Approved</span>
                </div>
                {myApp.review_notes && (
                  <p className="text-rose-200">{myApp.review_notes}</p>
                )}
              </div>
            )}
          </div>
        )}

        {/* Application Form (Only if no pending/approved app) */}
        {(!myApp || myApp.status === "REJECTED") && (
          <Card>
            <CardHeader>
              <CardTitle>Submit Creator Application</CardTitle>
              <CardDescription>
                Provide details about your project, sound, and previous releases
              </CardDescription>
            </CardHeader>
            <CardContent>
              {formError && (
                <div className="mb-4 p-3 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
                  {formError}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Artist / Project Name *
                  </label>
                  <Input
                    placeholder="e.g. Celestial Odyssey"
                    value={artistName}
                    onChange={(e) => setArtistName(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Primary Musical Genres
                  </label>
                  <Input
                    placeholder="e.g. Ambient, Lo-Fi, Synthwave, Indie Pop"
                    value={genres}
                    onChange={(e) => setGenres(e.target.value)}
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Portfolio / Music Link (SoundCloud, Spotify, Bandcamp)
                  </label>
                  <Input
                    type="url"
                    placeholder="https://soundcloud.com/your-artist-name"
                    value={portfolioUrl}
                    onChange={(e) => setPortfolioUrl(e.target.value)}
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Artist Bio & Production Background
                  </label>
                  <textarea
                    rows={4}
                    placeholder="Tell us about your musical history, instruments, and why you'd like to share your work on Hums..."
                    value={bio}
                    onChange={(e) => setBio(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
                  />
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  size="lg"
                  isLoading={submitMutation.isPending}
                >
                  <Send className="h-4 w-4 mr-1.5" />
                  Submit Application for Review
                </Button>
              </form>
            </CardContent>
          </Card>
        )}
      </div>

      <footer className="text-center text-xs text-slate-500 py-6">
        Hums Audio Streaming Platform &copy; 2026. All rights reserved.
      </footer>
    </div>
  );
}

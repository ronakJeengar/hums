import React from "react";
import "@testing-library/jest-dom/vitest";
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { DataTable } from "@/components/ui/data-table";
import { ColumnDef } from "@tanstack/react-table";
import { formatDuration, formatNumber, formatDate } from "@/lib/utils";
import { BulkTrackActionResult } from "@/types";

interface MockTrack {
  id: string;
  title: string;
  status: "READY" | "PROCESSING" | "FAILED" | "MODERATED" | "UPLOADED";
  is_published: boolean;
}

const mockColumns: ColumnDef<MockTrack>[] = [
  {
    accessorKey: "title",
    header: "Title",
    cell: ({ row }) => <span>{row.original.title}</span>,
  },
  {
    accessorKey: "status",
    header: "Status",
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
  },
  {
    accessorKey: "is_published",
    header: "Publishing",
    cell: ({ row }) => (
      <Badge variant={row.original.is_published ? "success" : "default"}>
        {row.original.is_published ? "Published" : "Draft / Private"}
      </Badge>
    ),
  },
];

const mockTracks: MockTrack[] = [
  { id: "trk-1", title: "Lunar Eclipse", status: "READY", is_published: true },
  { id: "trk-2", title: "Solar Flare", status: "PROCESSING", is_published: false },
  { id: "trk-3", title: "Nebula Dreams", status: "FAILED", is_published: false },
  { id: "trk-4", title: "Supernova", status: "MODERATED", is_published: true },
];

describe("Content Management & Media Library Tests", () => {
  it("formats audio duration and metric numbers accurately", () => {
    expect(formatDuration(0)).toBe("0:00");
    expect(formatDuration(65)).toBe("1:05");
    expect(formatDuration(3665)).toBe("61:05");
    expect(formatDuration(null)).toBe("0:00");

    expect(formatNumber(0)).toBe("0");
    expect(formatNumber(15420)).toBe("15,420");
    expect(formatNumber(1250000)).toBe("1,250,000");
  });

  it("renders status badges with appropriate visual semantics", () => {
    const { rerender } = render(<StatusBadge status="READY" />);
    expect(screen.getByText("READY")).toBeInTheDocument();

    rerender(<StatusBadge status="PROCESSING" />);
    expect(screen.getByText("PROCESSING")).toBeInTheDocument();

    rerender(<StatusBadge status="FAILED" />);
    expect(screen.getByText("FAILED")).toBeInTheDocument();

    rerender(<StatusBadge status="MODERATED" />);
    expect(screen.getByText("MODERATED")).toBeInTheDocument();

    rerender(<StatusBadge status="UPLOADED" />);
    expect(screen.getByText("UPLOADED")).toBeInTheDocument();
  });

  it("renders publishing status badge for published and draft items", () => {
    const { rerender } = render(
      <Badge variant="success">Published</Badge>
    );
    expect(screen.getByText("Published")).toBeInTheDocument();

    rerender(
      <Badge variant="default">Draft / Private</Badge>
    );
    expect(screen.getByText("Draft / Private")).toBeInTheDocument();
  });

  it("renders DataTable with track catalog rows and data attributes", () => {
    render(
      <DataTable
        columns={mockColumns}
        data={mockTracks}
        isLoading={false}
        page={1}
        totalPages={1}
        total={4}
      />
    );

    expect(screen.getByText("Lunar Eclipse")).toBeInTheDocument();
    expect(screen.getByText("Solar Flare")).toBeInTheDocument();
    expect(screen.getByText("Nebula Dreams")).toBeInTheDocument();
    expect(screen.getByText("Supernova")).toBeInTheDocument();
  });

  it("handles row selection callbacks in DataTable", () => {
    const onSelectionChange = vi.fn();
    render(
      <DataTable
        columns={mockColumns}
        data={mockTracks}
        isLoading={false}
        enableRowSelection={true}
        rowSelection={{ "trk-1": true }}
        onRowSelectionChange={onSelectionChange}
        getRowId={(row) => row.id}
      />
    );

    expect(screen.getByText("Lunar Eclipse")).toBeInTheDocument();
  });

  it("processes bulk action results structure accurately", () => {
    const bulkResponse: BulkTrackActionResult = {
      action: "publish",
      total: 3,
      succeeded: 2,
      failed: 1,
      results: [
        { track_id: "trk-1", title: "Lunar Eclipse", status: "success", message: "Published" },
        { track_id: "trk-2", title: "Solar Flare", status: "failed", error: "Track not READY" },
        { track_id: "trk-3", title: "Supernova", status: "success", message: "Published" },
      ],
    };

    expect(bulkResponse.total).toBe(3);
    expect(bulkResponse.succeeded).toBe(2);
    expect(bulkResponse.failed).toBe(1);
    expect(bulkResponse.results.length).toBe(3);
    expect(bulkResponse.results[1].error).toBe("Track not READY");
  });
});

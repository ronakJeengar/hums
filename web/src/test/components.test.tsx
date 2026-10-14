import React from "react";
import "@testing-library/jest-dom/vitest";
import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/badge";
import { StatCard } from "@/components/ui/stat-card";

describe("Shared UI Components", () => {
  it("renders Button with label and loading indicator", () => {
    const { rerender } = render(<Button>Save Release</Button>);
    expect(screen.getByText("Save Release")).toBeInTheDocument();

    rerender(<Button isLoading>Save Release</Button>);
    expect(screen.getByRole("button")).toBeDisabled();
  });

  it("renders StatusBadge with semantic styling", () => {
    const { rerender } = render(<StatusBadge status="READY" />);
    expect(screen.getByText("READY")).toBeInTheDocument();

    rerender(<StatusBadge status="FAILED" />);
    expect(screen.getByText("FAILED")).toBeInTheDocument();

    rerender(<StatusBadge status="PENDING" />);
    expect(screen.getByText("PENDING")).toBeInTheDocument();
  });

  it("renders StatCard with title, formatted value, and subtitle", () => {
    render(
      <StatCard
        title="Total Plays"
        value={15420}
        subtitle="Last 30 days listening"
        trend={{ value: "+12%", isPositive: true }}
      />
    );

    expect(screen.getByText("Total Plays")).toBeInTheDocument();
    expect(screen.getByText("15,420")).toBeInTheDocument();
    expect(screen.getByText("Last 30 days listening")).toBeInTheDocument();
    expect(screen.getByText("+12%")).toBeInTheDocument();
  });
});

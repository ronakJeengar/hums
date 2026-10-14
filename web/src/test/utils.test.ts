import { describe, expect, it } from "vitest";
import { cn, formatDuration, formatNumber } from "@/lib/utils";

describe("Formatting and Styling Utilities", () => {
  it("formats audio duration in mm:ss format", () => {
    expect(formatDuration(0)).toBe("0:00");
    expect(formatDuration(45)).toBe("0:45");
    expect(formatDuration(60)).toBe("1:00");
    expect(formatDuration(185)).toBe("3:05");
    expect(formatDuration(3600)).toBe("60:00");
    expect(formatDuration(null)).toBe("0:00");
  });

  it("formats numeric counts with thousands commas", () => {
    expect(formatNumber(0)).toBe("0");
    expect(formatNumber(1500)).toBe("1,500");
    expect(formatNumber(1000000)).toBe("1,000,000");
    expect(formatNumber(null)).toBe("0");
  });

  it("merges Tailwind classes without conflicts", () => {
    expect(cn("p-2", "text-red-500", "p-4")).toBe("text-red-500 p-4");
    expect(cn("bg-black", false && "hidden", "text-white")).toBe("bg-black text-white");
  });
});

import { describe, expect, it } from "vitest";

import { config } from "./config";

describe("config", () => {
  it("expone el prefijo versionado de la API", () => {
    expect(config.apiPrefix).toBe("/api/v1");
  });
});

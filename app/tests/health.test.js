const request = require("supertest");

jest.mock("../src/db", () => ({
    pool: { query: jest.fn().mockResolvedValue({ rows: [] }) },
    initSchema: jest.fn(),
}));

const { createApp } = require("../src/app");

describe("health & metrics endpoints", () => {
    const app = createApp();

    test("GET /health returns 200 ok", async () => {
        const res = await request(app).get("/health");
        expect(res.status).toBe(200);
        expect(res.body.status).toBe("ok");
    });

    test("GET /metrics exposes prometheus metrics", async () => {
        const res = await request(app).get("/metrics");
        expect(res.status).toBe(200);
        expect(res.text).toContain("http_requests_total");
    });

    test("GET / returns the homepage", async () => {
        const res = await request(app).get("/");
        expect(res.status).toBe(200);
        expect(res.text).toContain("DeployHub Sample App");
    });
});

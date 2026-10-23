const API_URL = process.env.API_URL ?? "http://localhost:3000";

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export async function api<T>(path: string, token: string | null, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  headers.set("Accept", "application/json");
  if (init?.body) {
    headers.set("Content-Type", "application/json");
  }
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, {
      ...init,
      headers,
      cache: "no-store",
    });
  } catch {
    throw new ApiError(503, "The game API is not reachable. Start the backend on port 3000.");
  }

  const text = await response.text();
  let payload: { error?: string } = {};
  if (text) {
    try {
      payload = JSON.parse(text) as { error?: string };
    } catch {
      throw new ApiError(response.status, "The API returned an unreadable response.");
    }
  }
  if (!response.ok) {
    throw new ApiError(response.status, payload.error || "The request failed.");
  }
  return payload as T;
}

export function apiUrl() {
  return API_URL;
}

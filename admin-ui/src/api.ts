import { mockDetails, mockQueue } from "./mockData";
import type { PaginatedResponse, ReviewActionPayload, ReviewDetail, ReviewQueueItem } from "./types";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "";
const QUEUE_PAGE_SIZE = 500;

class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "HttpError";
    this.status = status;
  }
}

function shouldUseMockPostFallback(error: unknown) {
  return API_BASE_URL === "" && error instanceof HttpError && error.status === 404;
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {})
    },
    ...init
  });

  if (!response.ok) {
    const text = await response.text();
    throw new HttpError(response.status, text || `HTTP ${response.status}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const text = await response.text();
  if (!text) {
    return undefined as T;
  }

  return JSON.parse(text) as T;
}

async function fetchReviewQueuePage(status: string, limit: number, offset: number): Promise<PaginatedResponse<ReviewQueueItem>> {
  const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
  if (status !== "all") {
    params.set("review_status", status);
  }

  return requestJson<PaginatedResponse<ReviewQueueItem>>(`/api/v1/admin/manual-review?${params.toString()}`);
}

export async function fetchReviewQueue(status: string): Promise<PaginatedResponse<ReviewQueueItem>> {
  try {
    const firstPage = await fetchReviewQueuePage(status, QUEUE_PAGE_SIZE, 0);
    const items = [...firstPage.items];

    while (items.length < firstPage.total) {
      const nextPage = await fetchReviewQueuePage(status, QUEUE_PAGE_SIZE, items.length);
      if (nextPage.items.length === 0) break;
      items.push(...nextPage.items);
    }

    return { ...firstPage, items, limit: items.length, offset: 0 };
  } catch {
    const items = status === "all" ? mockQueue : mockQueue.filter((item) => item.review_status === status);
    return { items, limit: 100, offset: 0, total: items.length };
  }
}

export async function fetchReviewDetail(pollId: number): Promise<ReviewDetail> {
  try {
    return await requestJson<ReviewDetail>(`/api/v1/admin/manual-review/${pollId}`);
  } catch {
    return mockDetails[pollId] ?? mockDetails[mockQueue[0].poll_id];
  }
}

export async function submitReviewAction(pollId: number, payload: ReviewActionPayload): Promise<void> {
  try {
    await requestJson<void>(`/api/v1/admin/manual-review/${pollId}/actions`, {
      method: "POST",
      body: JSON.stringify(payload)
    });
  } catch (error) {
    if (!shouldUseMockPostFallback(error)) {
      throw error;
    }
    await new Promise((resolve) => window.setTimeout(resolve, 350));
  }
}

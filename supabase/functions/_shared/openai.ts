// Shared OpenAI Chat Completions call for the Edge Functions.
//
// Every call is bounded by a timeout set a few seconds below the app's own
// request timeout, so a function stops waiting (and paying) once the learner's
// app has already given up on it.

import { textResponse } from "./auth.ts";

export const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

export type JsonSchema = Record<string, unknown>;

/**
 * `response_format` for Structured Outputs: the reply is guaranteed to parse
 * and to match [schema] (every property required, no extra properties).
 */
export function strictJsonFormat(name: string, schema: JsonSchema) {
  return {
    type: "json_schema",
    json_schema: { name, strict: true, schema },
  };
}

export type ChatJsonResult =
  | { ok: true; json: Record<string, unknown>; content: string }
  | { ok: false; response: Response };

function fail(message: string, status: number): ChatJsonResult {
  return { ok: false, response: textResponse(message, status) };
}

function isTimeout(error: unknown): boolean {
  return error instanceof DOMException &&
    (error.name === "TimeoutError" || error.name === "AbortError");
}

/**
 * Sends [body] (model, messages, response_format, ...) to Chat Completions
 * and returns the parsed JSON object of the first choice, or an error
 * Response: 504 when [timeoutMs] elapses, 502 for any other failure.
 */
export async function chatJson(
  { apiKey, timeoutMs, body }: {
    apiKey: string;
    timeoutMs: number;
    body: Record<string, unknown>;
  },
): Promise<ChatJsonResult> {
  let content: unknown;
  try {
    const res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(body),
      // Covers reading the response body too, not just the headers.
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) {
      console.error("OpenAI error:", res.status, await res.text());
      return fail("AI service error", 502);
    }
    const message = (await res.json())?.choices?.[0]?.message;
    if (message?.refusal) {
      console.error("OpenAI refusal:", message.refusal);
      return fail("AI service error", 502);
    }
    content = message?.content;
  } catch (error) {
    if (isTimeout(error)) {
      console.error(`OpenAI request timed out after ${timeoutMs}ms`);
      return fail("AI service timeout", 504);
    }
    console.error("OpenAI request failed:", error);
    return fail("AI service error", 502);
  }

  if (typeof content !== "string" || content.length === 0) {
    return fail("Empty AI response", 502);
  }
  let json: unknown;
  try {
    json = JSON.parse(content);
  } catch {
    console.error("Failed to parse AI response:", content);
    return fail("Invalid AI response format", 502);
  }
  if (json === null || typeof json !== "object" || Array.isArray(json)) {
    console.error("AI response is not a JSON object:", content);
    return fail("Invalid AI response format", 502);
  }
  return { ok: true, json: json as Record<string, unknown>, content };
}

/**
 * Lists the ways [schema] breaks the Structured Outputs strict-mode rules
 * (every object closes `additionalProperties` and requires all of its
 * properties). OpenAI rejects such a schema with a 400 on every request, so
 * the function tests assert this returns nothing.
 */
export function strictSchemaProblems(schema: unknown, path = "$"): string[] {
  if (schema === null || typeof schema !== "object") return [];
  const node = schema as Record<string, unknown>;
  const problems: string[] = [];
  const types = Array.isArray(node.type) ? node.type : [node.type];

  if (types.includes("object")) {
    const properties = (node.properties ?? {}) as Record<string, unknown>;
    if (node.additionalProperties !== false) {
      problems.push(`${path}: additionalProperties must be false`);
    }
    const required = new Set(
      Array.isArray(node.required) ? node.required as string[] : [],
    );
    for (const key of Object.keys(properties)) {
      if (!required.has(key)) problems.push(`${path}.${key}: not required`);
      problems.push(...strictSchemaProblems(properties[key], `${path}.${key}`));
    }
    for (const key of required) {
      if (!(key in properties)) {
        problems.push(`${path}: requires unknown property ${key}`);
      }
    }
  }
  if (types.includes("array")) {
    if (node.items === undefined) problems.push(`${path}: array without items`);
    problems.push(...strictSchemaProblems(node.items, `${path}[]`));
  }
  return problems;
}

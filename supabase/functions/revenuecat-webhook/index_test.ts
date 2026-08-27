import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseWebhook } from "./index.ts";

Deno.test("webhook parser accepts required fields", () => {
  assertEquals(
    parseWebhook(
      '{"event":{"id":"evt_1","type":"INITIAL_PURCHASE","app_user_id":"abc"}}',
    ),
    {
      eventID: "evt_1",
      eventType: "INITIAL_PURCHASE",
      appUserID: "abc",
    },
  );
});

Deno.test("webhook parser rejects malformed events", () => {
  assertThrows(() => parseWebhook('{"event":{"type":"INITIAL_PURCHASE"}}'));
});

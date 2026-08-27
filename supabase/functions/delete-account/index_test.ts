import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { deleteAccountData } from "./logic.ts";

Deno.test("deletes RevenueCat data before the Supabase account", async () => {
  const calls: string[] = [];
  const result = await deleteAccountData("user-id", {
    deleteRevenueCatCustomer: (userID) => {
      calls.push(`revenuecat:${userID}`);
      return Promise.resolve();
    },
    deleteSupabaseUser: (userID) => {
      calls.push(`supabase:${userID}`);
      return Promise.resolve();
    },
  });

  assertEquals(calls, ["revenuecat:user-id", "supabase:user-id"]);
  assertEquals(result, { deleted: true });
});

Deno.test("does not delete the Supabase account when RevenueCat deletion fails", async () => {
  let deletedSupabaseUser = false;
  await assertRejects(() =>
    deleteAccountData("user-id", {
      deleteRevenueCatCustomer: () =>
        Promise.reject(new Error("RevenueCat failed")),
      deleteSupabaseUser: () => {
        deletedSupabaseUser = true;
        return Promise.resolve();
      },
    })
  );

  assertEquals(deletedSupabaseUser, false);
});

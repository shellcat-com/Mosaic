export type DeleteAccountDependencies = {
  deleteRevenueCatCustomer: (userID: string) => Promise<void>;
  deleteSupabaseUser: (userID: string) => Promise<void>;
};

export async function deleteAccountData(
  userID: string,
  dependencies: DeleteAccountDependencies,
) {
  await dependencies.deleteRevenueCatCustomer(userID);
  await dependencies.deleteSupabaseUser(userID);
  return { deleted: true as const };
}

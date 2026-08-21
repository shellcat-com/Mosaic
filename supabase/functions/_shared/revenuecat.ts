export type RevenueCatList<T> = {
  items?: T[];
  next_page?: string | null;
};

export type RevenueCatActiveEntitlement = {
  entitlement_id?: string;
  expires_at?: number | null;
};

export type RevenueCatSubscription = {
  product_id?: string | null;
  product?: { store_identifier?: string | null } | null;
  current_period_ends_at?: number | null;
  ends_at?: number | null;
  gives_access?: boolean;
  auto_renewal_status?: string | null;
  status?: string | null;
  entitlements?:
    | RevenueCatList<{
      id?: string;
      products?: RevenueCatList<{
        product?: { id?: string; store_identifier?: string | null };
      }>;
    }>
    | null;
};

export type RevenueCatVirtualCurrencyBalance = {
  currency_code?: string;
  balance?: number;
};

export type RevenueCatBillingState = {
  plusActive: boolean;
  subscriptionStatus:
    | "none"
    | "trialing"
    | "active"
    | "grace_period"
    | "billing_issue"
    | "cancelled"
    | "expired";
  productId: string | null;
  expiresAt: string | null;
  willRenew: boolean;
  passBalance: number;
};

function normalizedStatus(
  value: string | null | undefined,
  autoRenewalStatus: string | null | undefined,
): RevenueCatBillingState["subscriptionStatus"] {
  if (autoRenewalStatus?.toLowerCase() === "will_not_renew") {
    return "cancelled";
  }
  switch (value?.toLowerCase()) {
    case "trialing":
      return "trialing";
    case "active":
      return "active";
    case "in_grace_period":
      return "grace_period";
    case "in_billing_retry":
      return "billing_issue";
    case "paused":
      return "cancelled";
    case "expired":
      return "expired";
    default:
      return "active";
  }
}

export function isoDateFromMilliseconds(value: unknown): string | null {
  if (value == null) return null;
  const milliseconds = Number(value);
  if (!Number.isFinite(milliseconds) || milliseconds <= 0) return null;
  const date = new Date(milliseconds);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function passBalance(
  balances: RevenueCatVirtualCurrencyBalance[],
): number {
  const pass = balances.find((item) => item.currency_code === "PASS");
  const value = Number(pass?.balance ?? 0);
  return Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

export function billingState(
  entitlementId: string,
  activeEntitlements: RevenueCatActiveEntitlement[],
  subscriptions: RevenueCatSubscription[],
  balances: RevenueCatVirtualCurrencyBalance[],
): RevenueCatBillingState {
  const entitlement = activeEntitlements.find((item) =>
    item.entitlement_id === entitlementId
  );
  const subscription = subscriptions.find((item) =>
    item.entitlements?.items?.some((candidate) =>
      candidate.id === entitlementId
    )
  );
  const subscriptionEntitlement = subscription?.entitlements?.items?.find(
    (candidate) => candidate.id === entitlementId,
  );
  const storeProductId = subscriptionEntitlement?.products?.items?.find(
    (candidate) => candidate.product?.id === subscription?.product_id,
  )?.product?.store_identifier;
  const plusActive = entitlement != null;
  const subscriptionStatus = plusActive
    ? normalizedStatus(
      subscription?.status,
      subscription?.auto_renewal_status,
    )
    : "none";

  return {
    plusActive,
    subscriptionStatus,
    productId: plusActive
      ? subscription?.product?.store_identifier ?? storeProductId ??
        subscription?.product_id ?? null
      : null,
    expiresAt: plusActive
      ? isoDateFromMilliseconds(
        entitlement?.expires_at ?? subscription?.current_period_ends_at ??
          subscription?.ends_at,
      )
      : null,
    willRenew: plusActive && ["will_renew", "has_already_renewed"].includes(
      subscription?.auto_renewal_status ?? "",
    ),
    passBalance: passBalance(balances),
  };
}

export async function fetchRevenueCatList<T>(
  apiKey: string,
  path: string,
): Promise<T[]> {
  const response = await fetch(`https://api.revenuecat.com/v2${path}`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!response.ok) {
    throw new Error(`RevenueCat request failed with HTTP ${response.status}`);
  }
  const payload = await response.json() as RevenueCatList<T>;
  if (!Array.isArray(payload?.items)) {
    throw new Error("RevenueCat returned an invalid list response");
  }
  return payload.items;
}

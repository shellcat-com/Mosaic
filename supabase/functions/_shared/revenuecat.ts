export const revenueCatCatalog = {
  entitlement: "organizer_plus",
  monthly: "organizer_monthly",
  annual: "organizer_annual",
  pass: "PASS",
} as const;

export type BillingSnapshot = {
  plusActive: boolean;
  subscriptionState:
    | "none"
    | "trialing"
    | "active"
    | "grace_period"
    | "billing_issue"
    | "cancelled"
    | "expired";
  productID: string | null;
  expiresAt: string | null;
  willRenew: boolean;
  passBalance: number;
  synchronizedAt: string;
};

type Item = Record<string, unknown>;

function items(value: unknown): Item[] {
  if (!value || typeof value !== "object") return [];
  const candidate = (value as { items?: unknown }).items;
  return Array.isArray(candidate)
    ? candidate.filter((item): item is Item =>
      !!item && typeof item === "object"
    )
    : [];
}

function nestedItems(item: Item | undefined, key: string): Item[] {
  return items(item?.[key]);
}

function text(item: Item | undefined, ...keys: string[]): string | null {
  for (const key of keys) {
    if (typeof item?.[key] === "string") return item[key] as string;
  }
  return null;
}

function bool(item: Item | undefined, ...keys: string[]): boolean | null {
  for (const key of keys) {
    if (typeof item?.[key] === "boolean") return item[key] as boolean;
  }
  return null;
}

function time(item: Item | undefined, ...keys: string[]): string | null {
  const value = text(item, ...keys);
  if (value && !Number.isNaN(Date.parse(value))) return value;
  for (const key of keys) {
    const number = item?.[key];
    if (typeof number === "number") {
      return new Date(number > 10_000_000_000 ? number : number * 1000)
        .toISOString();
    }
  }
  return null;
}

export function parseBillingSnapshot(
  entitlements: unknown,
  subscriptions: unknown,
  currencies: unknown,
  now = new Date(),
): BillingSnapshot {
  const subscription = items(subscriptions).find((entry) =>
    nestedItems(entry, "entitlements").some((candidate) =>
      text(candidate, "lookup_key") === revenueCatCatalog.entitlement
    )
  );
  const plusEntitlement = nestedItems(subscription, "entitlements").find((
    candidate,
  ) => text(candidate, "lookup_key") === revenueCatCatalog.entitlement);
  const internalEntitlementID = text(plusEntitlement, "id");
  const activeEntitlement = items(entitlements).find((entry) =>
    text(entry, "entitlement_id") === internalEntitlementID
  );
  const entitlementExpiry = time(activeEntitlement, "expires_at", "ends_at");
  const plusActive = !!subscription &&
    bool(subscription, "gives_access") === true && !!activeEntitlement &&
    (!entitlementExpiry || Date.parse(entitlementExpiry) > now.getTime());
  const internalProductID = text(subscription, "product_id");
  const entitlementProducts = nestedItems(plusEntitlement, "products");
  const product =
    entitlementProducts.find((candidate) =>
      text(candidate, "id") === internalProductID
    ) ?? entitlementProducts[0];
  const productIdentifier = text(product, "store_identifier") ??
    text(subscription, "product_identifier", "product_lookup_key");
  const rawStatus = text(subscription, "status", "state")?.toLowerCase() ??
    (plusActive ? "active" : "none");
  const state: BillingSnapshot["subscriptionState"] =
    rawStatus.includes("trial")
      ? "trialing"
      : rawStatus.includes("grace")
      ? "grace_period"
      : rawStatus.includes("billing") || rawStatus.includes("past_due")
      ? "billing_issue"
      : rawStatus.includes("cancel")
      ? "cancelled"
      : rawStatus.includes("expire")
      ? "expired"
      : plusActive || rawStatus === "active"
      ? "active"
      : "none";
  const pass = items(currencies).find((entry) =>
    text(entry, "currency_code", "code") === revenueCatCatalog.pass
  );
  const rawBalance = pass?.balance;
  return {
    plusActive,
    subscriptionState: state,
    productID: productIdentifier,
    expiresAt: time(subscription, "current_period_ends_at", "expires_at") ??
      entitlementExpiry,
    willRenew: bool(subscription, "will_renew") ??
      text(subscription, "auto_renewal_status") === "will_renew",
    passBalance: typeof rawBalance === "number" && Number.isFinite(rawBalance)
      ? Math.max(0, Math.trunc(rawBalance))
      : 0,
    synchronizedAt: now.toISOString(),
  };
}

export function revenueCatConfiguration() {
  const projectID = Deno.env.get("REVENUECAT_PROJECT_ID")?.trim();
  const secretKey = Deno.env.get("REVENUECAT_SECRET_API_KEY")?.trim();
  if (!projectID || !secretKey || !secretKey.startsWith("sk_")) {
    throw new Error("RevenueCat server configuration is missing");
  }
  return { projectID, secretKey };
}

export async function revenueCatRequest(
  projectID: string,
  secretKey: string,
  path: string,
  init: RequestInit = {},
) {
  const response = await fetch(
    `https://api.revenuecat.com/v2/projects/${
      encodeURIComponent(projectID)
    }${path}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${secretKey}`,
        "Content-Type": "application/json",
        ...(init.headers ?? {}),
      },
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      `RevenueCat ${response.status}: ${
        (payload as { message?: string }).message ?? "request failed"
      }`,
    );
  }
  return payload;
}

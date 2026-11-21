import { z } from "zod";

/** Response shapes from the FastAPI backend, parsed at the boundary. */

export const Macros = z.object({ p: z.number(), c: z.number(), f: z.number() });

export const AdminSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string(),
  role: z.enum(["owner", "editor"]),
  createdAt: z.string(),
});
export type Admin = z.infer<typeof AdminSchema>;

export const LoginResponse = z.object({ accessToken: z.string(), admin: AdminSchema });

const DayPoint = z.object({ day: z.string(), value: z.number() });

const Revenue = z.object({ currency: z.string(), amountMinor: z.number(), payments: z.number() });
export type Revenue = z.infer<typeof Revenue>;
export type DayPoint = z.infer<typeof DayPoint>;

export const StatsSchema = z.object({
  totalUsers: z.number(),
  newUsersWeek: z.number(),
  activeToday: z.number(),
  premiumUsers: z.number(),
  mealsToday: z.number(),
  mealsTotal: z.number(),
  scansToday: z.number(),
  aiRequestsToday: z.number(),
  foodsToReview: z.number(),
  scanSuccessRate: z.number(),
  avgKcalPerMeal: z.number(),
  signups: z.array(DayPoint),
  meals: z.array(DayPoint),
  scans: z.array(DayPoint),
  topCountries: z.array(z.object({ country: z.string(), users: z.number() })),
  revenueMonth: z.array(Revenue),
  revenueTotal: z.array(Revenue),
  paymentsMonth: z.number(),
});
export type Stats = z.infer<typeof StatsSchema>;

export const page = <T extends z.ZodType>(item: T) =>
  z.object({ items: z.array(item), total: z.number(), page: z.number(), size: z.number() });

export const UserRowSchema = z.object({
  id: z.string(),
  phone: z.string(),
  name: z.string(),
  email: z.string(),
  country: z.string(),
  isPremium: z.boolean(),
  isBanned: z.boolean(),
  onboarded: z.boolean(),
  freeScansLeft: z.number(),
  mealCount: z.number(),
  createdAt: z.string(),
  lastSeenAt: z.string(),
});
export type UserRow = z.infer<typeof UserRowSchema>;

export const MealSchema = z.object({
  id: z.string(),
  name: z.string(),
  photo: z.string().nullable(),
  loggedAt: z.string(),
  type: z.string(),
  healthScore: z.number(),
  items: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      unit: z.string(),
      macros: Macros,
      servings: z.number(),
      confidence: z.number(),
    }),
  ),
});
export type Meal = z.infer<typeof MealSchema>;

export const UserDetailSchema = z.object({
  user: z.object({
    id: z.string(),
    phone: z.string(),
    name: z.string(),
    email: z.string(),
    onboarded: z.boolean(),
    profile: z.record(z.string(), z.unknown()).nullable(),
    isPremium: z.boolean(),
    premiumUntil: z.string().nullable(),
    freeScansLeft: z.number(),
    createdAt: z.string(),
  }),
  country: z.string(),
  isBanned: z.boolean(),
  lastSeenAt: z.string(),
  mealCount: z.number(),
  scanCount: z.number(),
  recentMeals: z.array(MealSchema),
  weights: z.array(z.number()),
});
export type UserDetail = z.infer<typeof UserDetailSchema>;

export const MealRowSchema = z.object({
  userId: z.string(),
  userName: z.string(),
  userPhone: z.string(),
  id: z.string(),
  name: z.string(),
  photo: z.string().nullable(),
  type: z.string(),
  kcal: z.number(),
  protein: z.number(),
  carbs: z.number(),
  fat: z.number(),
  healthScore: z.number(),
  loggedAt: z.string(),
});
export type MealRow = z.infer<typeof MealRowSchema>;

export const FoodRowSchema = z.object({
  id: z.number(),
  name: z.string(),
  unit: z.string(),
  macros: Macros,
  kcal: z.number(),
  brand: z.string().nullable(),
  barcode: z.string().nullable(),
  photo: z.string().nullable(),
  isActive: z.boolean(),
  source: z.string(),
  reviewed: z.boolean(),
});
export type FoodRow = z.infer<typeof FoodRowSchema>;

export const BroadcastSchema = z.object({
  id: z.number(),
  title: z.string(),
  body: z.string(),
  kind: z.string(),
  segment: z.string(),
  recipients: z.number(),
  adminEmail: z.string(),
  createdAt: z.string(),
});
export type Broadcast = z.infer<typeof BroadcastSchema>;

export const ScanLogSchema = z.object({
  id: z.number(),
  userId: z.string().nullable(),
  provider: z.string(),
  kind: z.enum(["photo", "text", "suggest"]),
  success: z.boolean(),
  mealName: z.string(),
  kcal: z.number(),
  latencyMs: z.number(),
  error: z.string(),
  createdAt: z.string(),
});
export type ScanLog = z.infer<typeof ScanLogSchema>;

export const ConfigSchema = z.object({
  free_scan_allowance: z.number(),
  ai_daily_limit_free: z.number(),
  maintenance_mode: z.boolean(),
  maintenance_message: z.string(),
  min_app_version: z.string(),
  support_email: z.string(),
});
export type AppConfig = z.infer<typeof ConfigSchema>;

export const PricingTierSchema = z.object({
  tier: z.string(),
  currency: z.string(),
  countries: z.array(z.string()),
  prices: z.array(z.object({ plan: z.string(), label: z.string() })),
});
export type PricingTier = z.infer<typeof PricingTierSchema>;

export const PaymentRowSchema = z.object({
  id: z.string(),
  userId: z.string().nullable(),
  userName: z.string(),
  userPhone: z.string(),
  plan: z.string(),
  currency: z.string(),
  amountMinor: z.number(),
  status: z.enum(["created", "paid", "failed"]),
  orderId: z.string(),
  paymentId: z.string().nullable(),
  createdAt: z.string(),
  paidAt: z.string().nullable(),
});
export type PaymentRow = z.infer<typeof PaymentRowSchema>;

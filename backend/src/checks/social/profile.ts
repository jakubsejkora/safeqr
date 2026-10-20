import { z } from "zod";
import { Apify } from "../../intel/apify.js";
import { apifyToken } from "../../shared/apify-secret.js";
import { env, LIMITS } from "../../shared/config.js";
import { redactArticle } from "../../shared/privacy.js";
import { takeQuota } from "../../shared/storage.js";
import { externalUrl } from "./links.js";

const profileSchema = z.object({
  username: z.string(),
  verified: z.boolean(),
  private: z.boolean(),
  isBusinessAccount: z.boolean().optional(),
  businessCategoryName: z.string().nullish(),
  followersCount: z.number().int().nonnegative(),
  postsCount: z.number().int().nonnegative(),
  biography: z.string().optional(),
  externalUrl: z.string().nullish(),
  externalUrls: z
    .array(
      z.object({ url: z.string().optional(), lynx_url: z.string().optional() }),
    )
    .optional(),
});
export interface PublicProfile {
  verified: boolean;
  private: boolean;
  business: boolean;
  category?: string;
  followers: number;
  posts: number;
  bio: string;
  links: string[];
}

export function parseProfile(value: unknown, username: string): PublicProfile {
  const row = profileSchema.parse(value);
  if (row.username.toLowerCase() !== username.toLowerCase())
    throw new Error("Profile did not match the requested username");
  const links = [
    row.externalUrl,
    ...(row.externalUrls ?? []).map((link) => link.url ?? link.lynx_url),
    ...((row.biography ?? "").match(/https?:\/\/[^\s<>"']+/gi) ?? []).map(
      (url) => url.replace(/[),.;!?]+$/, ""),
    ),
  ]
    .filter((url): url is string => typeof url === "string")
    .map((url) => externalUrl(url))
    .filter((url): url is string => Boolean(url));
  return {
    verified: row.verified,
    private: row.private,
    business: row.isBusinessAccount === true,
    category: row.businessCategoryName
      ? redactArticle(row.businessCategoryName).slice(0, 100)
      : undefined,
    followers: row.followersCount,
    posts: row.postsCount,
    bio: redactArticle(row.biography ?? "").slice(0, 1200),
    links: [...new Set(links)].slice(0, 20),
  };
}

export async function inspectProfile(
  username: string,
  dependencies: {
    claim?: () => Promise<void>;
    token?: () => Promise<string>;
    request?: typeof fetch;
  } = {},
): Promise<PublicProfile> {
  if (!/^[a-z0-9_.]{1,30}$/i.test(username))
    throw new Error("Invalid public username");
  await (
    dependencies.claim ??
    (() =>
      takeQuota(
        env("CHECKS_TABLE"),
        "profiles",
        86_400,
        LIMITS.profilesPerDay,
        new Intl.DateTimeFormat("en-CA", {
          timeZone: "Europe/Prague",
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
        }).format(new Date()),
      ))
  )();
  const apify = new Apify(
    await (dependencies.token ?? apifyToken)(),
    dependencies.request ?? fetch,
    LIMITS.profileChargeUsd,
  );
  const items = await apify.run(
    {
      actor: "apify/instagram-profile-scraper",
      build: "0.0.649",
      input: { usernames: [username], includeAboutSection: false },
      capUsd: LIMITS.profileChargeUsd,
      memory: 1024,
    },
    {
      seconds: 25,
      limit: 1,
      fields: [
        "username",
        "verified",
        "private",
        "isBusinessAccount",
        "businessCategoryName",
        "followersCount",
        "postsCount",
        "biography",
        "externalUrl",
        "externalUrls",
      ],
    },
  );
  return parseProfile(items[0], username);
}

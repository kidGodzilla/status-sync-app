/**
 * Presence Relay Server (in-memory, stateless-ish)
 *
 * - No persistence: restart -> state resets, clients recover on next poll/update
 * - Identity: clients use random user_id (UUID) generated locally
 * - Consent: explicit via request + allow/deny; allow issues HMAC-signed capability token
 * - Transport: polling over HTTPS recommended; server itself is plain HTTP (put behind TLS proxy)
 *
 * ENV:
 *   PORT=5000
 *   SERVER_SECRET=some-long-random-string
 *   CORS_ORIGIN=https://your-app-origin (optional)
 */

require('dotenv').config();
const express = require("express");
const crypto = require("crypto");

const app = express();
app.use(express.json({ limit: "2mb" })); // Increased for avatar images

// ----- Config -----
const PORT = Number(process.env.PORT || 5000);
const SERVER_SECRET = process.env.SERVER_SECRET || null;
if (!SERVER_SECRET) {
  console.error("Missing SERVER_SECRET env var. Refusing to start.");
  process.exit(1);
}

const PRESENCE_TTL_MS = 3 * 60 * 1000; // 3 min
const REQUEST_TTL_MS = 24 * 60 * 60 * 1000; // 24h
const TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7d (shorter is fine too)

// Optional CORS (for debugging / web clients; your mac app won't need it)
const CORS_ORIGIN = process.env.CORS_ORIGIN || null;
if (CORS_ORIGIN) {
  app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", CORS_ORIGIN);
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
  });
}

// ----- In-memory state -----
/**
 * presenceByUserId: Map<user_id, { state, device, timestamp, updatedAt }>
 * - updatedAt is server receipt time (ms)
 */
const presenceByUserId = new Map();

/**
 * requestsByToUserId: Map<to_user_id, Map<request_id, request>>
 * request = { id, from, to, createdAt, expiresAt, status }
 * status: "pending" | "allowed" | "denied"
 */
const requestsByToUserId = new Map();

/**
 * outboundTokensByToUserId: Map<to_user_id, Array<{ from, token, issuedAt, expiresAt }>>
 * - When Bob allows Alice, the server issues a capability token for Alice to read Bob,
 *   and stores it for Alice to fetch (delivered via /tokens/inbox).
 */
const tokensInboxByUserId = new Map();

/**
 * profilesByUserId: Map<user_id, { displayName, handle, avatarData, updatedAt }>
 * - Stores user profile info (display name, handle, avatar)
 * - updatedAt is server receipt time (ms)
 */
const profilesByUserId = new Map();

// ----- Helpers -----
function nowMs() {
  return Date.now();
}

function isValidUserId(s) {
  return typeof s === "string" && s.length >= 8 && s.length <= 128;
}

function cleanup() {
  const t = nowMs();

  // Presence TTL
  for (const [uid, p] of presenceByUserId.entries()) {
    if (t - p.updatedAt > PRESENCE_TTL_MS) presenceByUserId.delete(uid);
  }

  // Request TTL
  for (const [to, m] of requestsByToUserId.entries()) {
    for (const [rid, r] of m.entries()) {
      if (t > r.expiresAt) m.delete(rid);
    }
    if (m.size === 0) requestsByToUserId.delete(to);
  }

  // Token inbox TTL
  for (const [uid, arr] of tokensInboxByUserId.entries()) {
    const kept = arr.filter((x) => t <= x.expiresAt);
    if (kept.length) tokensInboxByUserId.set(uid, kept);
    else tokensInboxByUserId.delete(uid);
  }
}

// Run cleanup periodically
setInterval(cleanup, 30 * 1000).unref();

function hmacSign(payloadB64) {
  return crypto.createHmac("sha256", SERVER_SECRET).update(payloadB64).digest("base64url");
}

function issueCapabilityToken({ subject, resource, scope }) {
  const issuedAt = Math.floor(Date.now() / 1000);
  const exp = Math.floor((Date.now() + TOKEN_TTL_MS) / 1000);

  const payload = {
    v: 1,
    iss: "presence-relay",
    sub: subject,      // requester (e.g. Alice)
    res: resource,     // target (e.g. Bob)
    scope,             // "read_presence"
    iat: issuedAt,
    exp
  };

  const payloadJson = JSON.stringify(payload);
  const payloadB64 = Buffer.from(payloadJson, "utf8").toString("base64url");
  const sig = hmacSign(payloadB64);

  // token format: payloadB64.sig
  return `${payloadB64}.${sig}`;
}

function verifyCapabilityToken(token, expectedSub, expectedRes, expectedScope) {
  if (typeof token !== "string") return { ok: false, reason: "token_not_string" };
  const parts = token.split(".");
  if (parts.length !== 2) return { ok: false, reason: "token_format" };
  const [payloadB64, sig] = parts;

  const sigExpected = hmacSign(payloadB64);
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(sigExpected))) {
    return { ok: false, reason: "bad_signature" };
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(payloadB64, "base64url").toString("utf8"));
  } catch {
    return { ok: false, reason: "bad_payload" };
  }

  const now = Math.floor(Date.now() / 1000);
  if (!payload || payload.v !== 1) return { ok: false, reason: "bad_version" };
  if (payload.exp && now > payload.exp) return { ok: false, reason: "expired" };
  if (payload.sub !== expectedSub) return { ok: false, reason: "sub_mismatch" };
  if (payload.res !== expectedRes) return { ok: false, reason: "res_mismatch" };
  if (payload.scope !== expectedScope) return { ok: false, reason: "scope_mismatch" };

  return { ok: true, payload };
}

function getOrCreateRequestsMap(toUserId) {
  let m = requestsByToUserId.get(toUserId);
  if (!m) {
    m = new Map();
    requestsByToUserId.set(toUserId, m);
  }
  return m;
}

function pushTokenToInbox(userId, item) {
  const arr = tokensInboxByUserId.get(userId) || [];
  arr.push(item);
  tokensInboxByUserId.set(userId, arr);
}

// ----- Routes -----

app.get("/", (req, res) => {
  res.type("text/plain");
  res.send("Status Sync API - Nothing to see here");
});

app.get("/health", (req, res) => {
  res.json({ ok: true, ts: nowMs() });
});

/**
 * POST /presence/update
 * Body: { user_id, state: "active"|"away"|"asleep", device?: "mac"|"iphone"|"unknown", timestamp?: unixSeconds }
 */
app.post("/presence/update", (req, res) => {
  const { user_id, state, device, timestamp } = req.body || {};
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });
  if (!["active", "away", "asleep"].includes(state)) return res.status(400).json({ ok: false, error: "bad_state" });

  const serverNow = nowMs();
  presenceByUserId.set(user_id, {
    state,
    device: device || "unknown",
    timestamp: typeof timestamp === "number" ? timestamp : Math.floor(serverNow / 1000),
    updatedAt: serverNow
  });

  res.json({ ok: true });
});

/**
 * POST /requests/create
 * Body: { from_user_id, to_user_id }
 * Creates a pending request, visible to `to_user_id` via /requests/inbox.
 */
app.post("/requests/create", (req, res) => {
  const { from_user_id, to_user_id } = req.body || {};
  if (!isValidUserId(from_user_id) || !isValidUserId(to_user_id)) {
    return res.status(400).json({ ok: false, error: "bad_user_id" });
  }
  if (from_user_id === to_user_id) return res.status(400).json({ ok: false, error: "same_user" });

  const id = crypto.randomUUID();
  const createdAt = nowMs();
  const expiresAt = createdAt + REQUEST_TTL_MS;

  const request = { id, from: from_user_id, to: to_user_id, createdAt, expiresAt, status: "pending" };

  const m = getOrCreateRequestsMap(to_user_id);
  m.set(id, request);

  res.json({ ok: true, request_id: id, expiresAt });
});

/**
 * GET /requests/inbox?user_id=...
 * Returns pending requests for user_id
 */
app.get("/requests/inbox", (req, res) => {
  const user_id = req.query.user_id;
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });

  const m = requestsByToUserId.get(user_id);
  const out = [];
  if (m) {
    for (const r of m.values()) {
      if (r.status === "pending" && nowMs() <= r.expiresAt) out.push(r);
    }
  }
  res.json({ ok: true, requests: out });
});

/**
 * POST /requests/respond
 * Body: { to_user_id, request_id, decision: "allow"|"deny" }
 *
 * If allow: server issues capability token allowing `from` to read `to` presence.
 * Token is delivered to `from` via /tokens/inbox?user_id=<from>.
 */
app.post("/requests/respond", (req, res) => {
  const { to_user_id, request_id, decision } = req.body || {};
  if (!isValidUserId(to_user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });
  if (typeof request_id !== "string") return res.status(400).json({ ok: false, error: "bad_request_id" });
  if (!["allow", "deny"].includes(decision)) return res.status(400).json({ ok: false, error: "bad_decision" });

  const m = requestsByToUserId.get(to_user_id);
  if (!m) return res.status(404).json({ ok: false, error: "request_not_found" });

  const r = m.get(request_id);
  if (!r || r.to !== to_user_id) return res.status(404).json({ ok: false, error: "request_not_found" });
  if (nowMs() > r.expiresAt) {
    m.delete(request_id);
    return res.status(410).json({ ok: false, error: "request_expired" });
  }
  if (r.status !== "pending") return res.status(409).json({ ok: false, error: "already_responded", status: r.status });

  if (decision === "deny") {
    r.status = "denied";
    m.set(request_id, r);
    return res.json({ ok: true, status: "denied" });
  }

  // allow
  r.status = "allowed";
  m.set(request_id, r);

  const token = issueCapabilityToken({
    subject: r.from,       // Alice (requester)
    resource: r.to,        // Bob (target)
    scope: "read_presence"
  });

  const issuedAt = nowMs();
  const expiresAt = issuedAt + TOKEN_TTL_MS;

  // Put token into requester's inbox (Alice fetches it)
  pushTokenToInbox(r.from, { from: r.to, token, issuedAt, expiresAt });

  res.json({ ok: true, status: "allowed" });
});

/**
 * GET /tokens/inbox?user_id=...
 * Returns capability tokens issued to this user (the requester).
 * Client should store tokens locally and can call /tokens/ack to remove them.
 */
app.get("/tokens/inbox", (req, res) => {
  const user_id = req.query.user_id;
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });

  const arr = tokensInboxByUserId.get(user_id) || [];
  const now = nowMs();
  const tokens = arr.filter((x) => now <= x.expiresAt);

  res.json({ ok: true, tokens });
});

/**
 * POST /tokens/ack
 * Body: { user_id, token }
 * Removes a token from the inbox (optional housekeeping)
 */
app.post("/tokens/ack", (req, res) => {
  const { user_id, token } = req.body || {};
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });
  if (typeof token !== "string") return res.status(400).json({ ok: false, error: "bad_token" });

  const arr = tokensInboxByUserId.get(user_id) || [];
  const kept = arr.filter((x) => x.token !== token);
  if (kept.length) tokensInboxByUserId.set(user_id, kept);
  else tokensInboxByUserId.delete(user_id);

  res.json({ ok: true });
});

/**
 * POST /presence/get
 * Body: { requester_user_id, target_user_id, capability_token }
 * Returns target's latest presence if authorized.
 */
app.post("/presence/get", (req, res) => {
  const { requester_user_id, target_user_id, capability_token } = req.body || {};
  if (!isValidUserId(requester_user_id) || !isValidUserId(target_user_id)) {
    return res.status(400).json({ ok: false, error: "bad_user_id" });
  }

  const v = verifyCapabilityToken(capability_token, requester_user_id, target_user_id, "read_presence");
  if (!v.ok) return res.status(403).json({ ok: false, error: "unauthorized", reason: v.reason });

  const p = presenceByUserId.get(target_user_id);
  if (!p) return res.json({ ok: true, presence: null });

  // If TTL expired, treat as null
  if (nowMs() - p.updatedAt > PRESENCE_TTL_MS) return res.json({ ok: true, presence: null });

  res.json({
    ok: true,
    presence: {
      user_id: target_user_id,
      state: p.state,
      device: p.device,
      timestamp: p.timestamp
    }
  });
});

/**
 * POST /profile/update
 * Body: { user_id, displayName, handle, avatarData? (base64) }
 * Updates the user's profile info.
 */
app.post("/profile/update", (req, res) => {
  const { user_id, displayName, handle, avatarData } = req.body || {};
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });
  if (typeof displayName !== "string" || typeof handle !== "string") {
    return res.status(400).json({ ok: false, error: "bad_profile_data" });
  }

  profilesByUserId.set(user_id, {
    displayName: displayName.trim(),
    handle: handle.trim(),
    avatarData: typeof avatarData === "string" ? avatarData : null,
    updatedAt: nowMs()
  });

  res.json({ ok: true });
});

/**
 * GET /profile/get?user_id=...
 * Returns profile info for a user (public, no auth required).
 */
app.get("/profile/get", (req, res) => {
  const user_id = req.query.user_id;
  if (!isValidUserId(user_id)) return res.status(400).json({ ok: false, error: "bad_user_id" });

  const profile = profilesByUserId.get(user_id);
  if (!profile) return res.json({ ok: true, profile: null });

  res.json({
    ok: true,
    profile: {
      user_id,
      displayName: profile.displayName,
      handle: profile.handle,
      avatarData: profile.avatarData
    }
  });
});

app.listen(PORT, () => {
  console.log(`Presence relay listening on :${PORT}`);
});


import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { createHash } from "node:crypto"

import { AccessService, AccessError } from "../src/service.mjs"

// Mirrors the hashSecret used in service.mjs (sha256 hex)
function hashSecret(value) {
  return createHash("sha256").update(String(value)).digest("hex")
}

function makeStore(overrides = {}) {
  const RAW_KEY = "mka_test_key_context_query_12345678"
  const KEY_HASH = hashSecret(RAW_KEY)

  const data = {
    users: [{ id: "usr_001", email: "test@example.com", password_hash: "x", account_type: "developer", account_state: "active", password_pending: false, created_from: "signup", full_signup_completed: true, plan: "free_unlimited", created_at: new Date().toISOString(), updated_at: new Date().toISOString() }],
    apps: [{ id: "app_001", owner_user_id: "usr_001", name: "Test App", slug: "test-app", description: "", developer_url: "", redirect_urls: [], default_scopes: ["memory:read_summary"], default_categories: ["fitness"], compiled_policy: "", created_at: new Date().toISOString(), updated_at: new Date().toISOString(), revoked_at: null }],
    api_keys: [{ id: "key_001", app_id: "app_001", owner_user_id: "usr_001", name: "Test Key", key_hash: KEY_HASH, key_prefix: RAW_KEY.slice(0, 12), scopes: ["memory:read_summary"], created_at: new Date().toISOString(), last_used_at: null, revoked_at: null }],
    consents: [{ id: "cns_001", user_id: "usr_001", app_id: "app_001", scopes: ["memory:read_summary"], categories: ["fitness"], compiled_policy: "", created_at: new Date().toISOString(), updated_at: new Date().toISOString(), revoked_at: null }],
    memory_records: [
      { id: "mem_001", connection_id: "cns_001", memory_type: "fitness", subject: "workout_type", value: "strength training", confidence: 0.9, created_at: new Date().toISOString() },
      { id: "mem_002", connection_id: "cns_001", memory_type: "fitness", subject: "fitness_goal", value: "build muscle", confidence: 0.85, created_at: new Date().toISOString() }
    ],
    sessions: [], audit_log: [], usage_events: [], credit_events: [],
    feature_runs: [], feature_connections: [], feature_registry: [],
    schema_definitions: [], subschema_definitions: [], schema_packets: [],
    wiki_proposals: [], capture_events: [],
    ...overrides
  }

  return {
    RAW_KEY,
    store: {
      read: async () => JSON.parse(JSON.stringify(data)),
      write: async () => {}
    }
  }
}

describe("POST /v1/context/query", () => {
  it("returns matches when memory_records are provided in body", async () => {
    const { RAW_KEY, store } = makeStore()
    const service = new AccessService(store)

    const result = await service.queryContextFields(RAW_KEY, {
      requested_context: ["workout_type"],
      memory_records: [{ subject: "workout_type", value: "strength training" }],
      connection_id: "cns_001"
    })

    assert.ok(result, "result should exist")
    assert.ok("matches" in result, "result should have matches field")
    assert.strictEqual(result.requested_count, 1)
    assert.strictEqual(result.memory_count, 1)
  })

  it("falls back to store memory_records filtered by connection when none provided in body", async () => {
    const { RAW_KEY, store } = makeStore()
    const service = new AccessService(store)

    const result = await service.queryContextFields(RAW_KEY, {
      requested_context: ["workout_type", "fitness_goal"],
      memory_records: [],
      connection_id: "cns_001"
    })

    assert.ok(result, "result should exist")
    assert.ok("matches" in result, "result should have matches field")
    assert.strictEqual(result.memory_count, 2)
  })

  it("rejects API key missing memory:read_summary scope", async () => {
    const RAW_KEY_NO_SCOPE = "mka_no_scope_key_999999999999999999"
    const { store } = makeStore({
      api_keys: [{ id: "key_002", app_id: "app_001", owner_user_id: "usr_001", name: "No Scope Key", key_hash: hashSecret(RAW_KEY_NO_SCOPE), key_prefix: RAW_KEY_NO_SCOPE.slice(0, 12), scopes: ["capture:event_write"], created_at: new Date().toISOString(), last_used_at: null, revoked_at: null }]
    })
    const service = new AccessService(store)

    await assert.rejects(
      () => service.queryContextFields(RAW_KEY_NO_SCOPE, {
        requested_context: ["workout_type"],
        connection_id: "cns_001"
      }),
      (err) => {
        assert.ok(err instanceof AccessError)
        assert.strictEqual(err.status, 403)
        return true
      }
    )
  })
})
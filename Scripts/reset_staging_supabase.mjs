#!/usr/bin/env node

const projectRef = process.env.SUPABASE_STAGING_PROJECT_REF
const serviceRoleKey = process.env.SUPABASE_STAGING_SERVICE_ROLE_KEY
const expectedProjectRef = "tdpvtdblphojutjifdlc"

if (projectRef !== expectedProjectRef) {
  throw new Error(`Refusing to reset unexpected project: ${projectRef ?? "(missing)"}`)
}

if (!serviceRoleKey) {
  throw new Error("SUPABASE_STAGING_SERVICE_ROLE_KEY is required")
}

const baseUrl = `https://${projectRef}.supabase.co`
const headers = {
  apikey: serviceRoleKey,
  authorization: `Bearer ${serviceRoleKey}`,
  "content-type": "application/json",
}

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers: { ...headers, ...options.headers } })
  if (!response.ok) {
    throw new Error(`${options.method ?? "GET"} ${path} failed: ${response.status} ${await response.text()}`)
  }
  return response.status === 204 ? null : response.json()
}

async function deleteAuthUsers() {
  let deleted = 0
  for (;;) {
    // Always request the first page again: deleting an earlier page shifts the
    // remaining users, so incrementing a page number would leave users behind.
    const result = await request("/auth/v1/admin/users?page=1&per_page=1000")
    const users = result.users ?? []
    for (const user of users) {
      await request(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`, { method: "DELETE" })
      deleted += 1
    }
    if (users.length < 1000) break
  }
  return deleted
}

async function listBucketObjects(bucketId, prefix = "") {
  const files = []
  for (let offset = 0; ; offset += 1000) {
    const entries = await request(`/storage/v1/object/list/${encodeURIComponent(bucketId)}`, {
      method: "POST",
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
    })
    for (const entry of entries) {
      const name = prefix ? `${prefix}/${entry.name}` : entry.name
      if (entry.id) files.push(name)
      else files.push(...await listBucketObjects(bucketId, name))
    }
    if (entries.length < 1000) break
  }
  return files
}

async function deleteStorageObjects() {
  const buckets = await request("/storage/v1/bucket")
  let deleted = 0
  for (const bucket of buckets) {
    const names = await listBucketObjects(bucket.id)
    for (let index = 0; index < names.length; index += 1000) {
      const prefixes = names.slice(index, index + 1000)
      await request(`/storage/v1/object/${encodeURIComponent(bucket.id)}`, {
        method: "DELETE",
        body: JSON.stringify({ prefixes }),
      })
      deleted += prefixes.length
    }
  }
  return deleted
}

const deletedUsers = await deleteAuthUsers()
const deletedObjects = await deleteStorageObjects()
console.log(`Removed ${deletedUsers} Auth users and ${deletedObjects} Storage objects from staging.`)

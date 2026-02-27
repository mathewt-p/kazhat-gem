const API_BASE = document.querySelector('meta[name="kazhat-api-url"]')?.content || "/kazhat/api/v1"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content
}

async function request(method, path, data) {
  const url = `${API_BASE}${path}`
  console.log(`[Kazhat] API ${method} ${url}`, data || "")

  const options = {
    method,
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken()
    }
  }

  if (data && method !== "GET") {
    options.body = JSON.stringify(data)
  }

  const response = await fetch(url, options)

  if (!response.ok) {
    const text = await response.text().catch(() => "")
    console.error(`[Kazhat] API error: ${response.status} ${response.statusText}`, text)
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  if (response.status === 204) return null
  const json = await response.json()
  console.log(`[Kazhat] API response:`, json)
  return json
}

export const api = {
  get: (path) => request("GET", path),
  post: (path, data) => request("POST", path, data),
  patch: (path, data) => request("PATCH", path, data),
  delete: (path) => request("DELETE", path)
}

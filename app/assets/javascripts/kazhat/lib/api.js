const API_BASE = "/kazhat/api/v1"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content
}

async function request(method, path, data) {
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

  const response = await fetch(`${API_BASE}${path}`, options)

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  if (response.status === 204) return null
  return response.json()
}

export const api = {
  get: (path) => request("GET", path),
  post: (path, data) => request("POST", path, data),
  patch: (path, data) => request("PATCH", path, data),
  delete: (path) => request("DELETE", path)
}

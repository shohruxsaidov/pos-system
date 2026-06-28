import { useSessionStore } from '../stores/session.js'
import { getApiBaseUrl } from '../config/apiConfig.js'

export function useApi() {
  const session = useSessionStore()

  async function request(method, path, body = null, opts = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...opts.headers
    }

    if (session.token) {
      headers.Authorization = `Bearer ${session.token}`
    }

    const config = {
      method,
      headers
    }

    if (body !== null) {
      config.body = JSON.stringify(body)
    }

    const res = await fetch(`${getApiBaseUrl()}${path}`, config)

    if (res.status === 401) {
      session.logout()
      throw new Error('Unauthorized')
    }

    const data = await res.json()

    if (!res.ok) {
      throw new Error(data.error || `HTTP ${res.status}`)
    }

    return data
  }

  return {
    get: (path, opts) => request('GET', path, null, opts),
    post: (path, body, opts) => request('POST', path, body, opts),
    put: (path, body, opts) => request('PUT', path, body, opts),
    patch: (path, body, opts) => request('PATCH', path, body, opts),
    delete: (path, opts) => request('DELETE', path, null, opts)
  }
}

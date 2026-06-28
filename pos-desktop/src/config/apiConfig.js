const STORAGE_KEY = 'pos_api_base_url'
const DEFAULT_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000'

export function getApiBaseUrl() {
  return localStorage.getItem(STORAGE_KEY) || DEFAULT_BASE_URL
}

export function setApiBaseUrl(url) {
  // trim and strip trailing slash
  localStorage.setItem(STORAGE_KEY, url.trim().replace(/\/+$/, ''))
}

export function resetApiBaseUrl() {
  localStorage.removeItem(STORAGE_KEY)
}

export function getDefaultApiBaseUrl() {
  return DEFAULT_BASE_URL
}

export function getWsUrl() {
  // http→ws, https→wss
  return getApiBaseUrl().replace(/^http/, 'ws') + '/ws/status'
}

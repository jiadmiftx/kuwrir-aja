export function getToken() {
  return localStorage.getItem('token')
}

// Mirrors backend/internal/handler/admin/admins.go's rootSuperadminPhone —
// only this account can delete customer/driver/merchant accounts. The
// backend re-checks this independently; this is just used to show/hide the
// delete action in the UI.
const ROOT_SUPERADMIN_PHONE = '+6281907031'

export function isRootSuperadmin(): boolean {
  try {
    const raw = localStorage.getItem('user')
    if (!raw) return false
    return JSON.parse(raw).phone === ROOT_SUPERADMIN_PHONE
  } catch {
    return false
  }
}

function handleUnauthorized() {
  localStorage.removeItem('token')
  if (window.location.pathname !== '/login') {
    window.location.href = '/login'
  }
}

/**
 * Wrapper around fetch that attaches the admin auth token and redirects to
 * /login on 401 instead of leaving pages silently empty.
 */
export async function apiFetch(path: string, opts?: RequestInit): Promise<Response> {
  // FormData bodies (file uploads) need the browser to set its own
  // multipart boundary — a manual Content-Type header breaks the request.
  const isFormData = opts?.body instanceof FormData
  const res = await fetch(path, {
    ...opts,
    headers: {
      Authorization: `Bearer ${getToken()}`,
      ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
      ...(opts?.headers ?? {}),
    },
  })
  if (res.status === 401) {
    handleUnauthorized()
  }
  return res
}

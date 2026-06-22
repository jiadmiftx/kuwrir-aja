export function getToken() {
  return localStorage.getItem('token')
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
  const res = await fetch(path, {
    ...opts,
    headers: {
      Authorization: `Bearer ${getToken()}`,
      'Content-Type': 'application/json',
      ...(opts?.headers ?? {}),
    },
  })
  if (res.status === 401) {
    handleUnauthorized()
  }
  return res
}

// Shared HTTP utilities for Pausely Supabase Edge Functions.

/// Streams a request body up to `maxBytes` and returns its UTF-8 text, or `null` if either the
/// declared Content-Length or the streamed byte count exceeds `maxBytes`.
export async function readBoundedText(request: Request, maxBytes: number): Promise<string | null> {
  const lenHeader = request.headers.get('content-length')
  if (lenHeader !== null) {
    const declared = Number(lenHeader)
    if (Number.isFinite(declared) && declared > maxBytes) return null
  }
  if (!request.body) return ''
  const reader = request.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    total += value.byteLength
    if (total > maxBytes) {
      await reader.cancel().catch(() => {})
      return null
    }
    chunks.push(value)
  }
  const combined = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    combined.set(chunk, offset)
    offset += chunk.byteLength
  }
  return new TextDecoder().decode(combined)
}

/// Safely cancels/drains an upstream fetch response body so Deno never leaks connections or resources.
export async function drainResponse(response: Response): Promise<void> {
  try {
    await response.body?.cancel()
  } catch {
    // Ignore already-closed or already-consumed bodies.
  }
}

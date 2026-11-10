import { Buffer } from 'node:buffer';

export type AcceptedFileType = 'image/jpeg' | 'image/png' | 'image/webp' | 'application/pdf';

function startsWith(bytes: Uint8Array, signature: number[], offset = 0): boolean {
  return signature.every((b, i) => bytes[offset + i] === b);
}

/**
 * The file's real type, read from its leading bytes. The name and the type the
 * uploader declared are never consulted, because both are chosen by the client.
 * Returns null for anything that isn't one of the four accepted types.
 */
export function detectFileType(bytes: Uint8Array): AcceptedFileType | null {
  if (startsWith(bytes, [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
  // "RIFF", a four-byte size, then "WEBP".
  if (startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) && startsWith(bytes, [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  if (startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf'; // "%PDF-"
  return null;
}

/**
 * Whether a PDF is password protected, which Anthropic can't read. Searches for
 * the marker rather than parsing, because the file is untrusted. Page text is
 * almost always compressed, so a false match is very unlikely, and the cost of
 * one is a clear error message.
 */
export function isEncryptedPdf(bytes: Uint8Array): boolean {
  return Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength).includes('/Encrypt');
}

export function toBase64(bytes: Uint8Array): string {
  return Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength).toString('base64');
}

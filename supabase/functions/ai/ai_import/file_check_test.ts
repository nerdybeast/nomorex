import { assertEquals } from 'jsr:@std/assert@1';
import { detectFileType, isEncryptedPdf } from './file_check.ts';

const bytes = (...b: number[]) => new Uint8Array(b);
const text = (s: string) => new TextEncoder().encode(s);

Deno.test('recognises the four accepted types from their leading bytes', () => {
  assertEquals(detectFileType(bytes(0xff, 0xd8, 0xff, 0xe0)), 'image/jpeg');
  assertEquals(detectFileType(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0)), 'image/png');
  assertEquals(detectFileType(text('RIFF\0\0\0\0WEBPVP8 ')), 'image/webp');
  assertEquals(detectFileType(text('%PDF-1.7\n')), 'application/pdf');
});

Deno.test('rejects everything else, including near misses', () => {
  assertEquals(detectFileType(text('MZ\x90\0 a Windows executable')), null);
  assertEquals(detectFileType(text('RIFF\0\0\0\0WAVEfmt ')), null);
  assertEquals(detectFileType(text('<svg xmlns=')), null);
  assertEquals(detectFileType(text('%PDF')), null);
  assertEquals(detectFileType(new Uint8Array()), null);
});

Deno.test('spots a password-protected PDF', () => {
  assertEquals(isEncryptedPdf(text('%PDF-1.7 trailer << /Encrypt 5 0 R >>')), true);
  assertEquals(isEncryptedPdf(text('%PDF-1.7 trailer << /Root 1 0 R >>')), false);
});

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {engine} from './engine.mjs';

export async function verifyHttp(document, cases, baseURL) {
  const base = new URL(baseURL);
  if (!['http:', 'https:'].includes(base.protocol)) throw new Error('HTTP(S) base URL required');
  const actual = [];
  for (const test of cases) {
    const method = test.method.toLowerCase();
    if (!['get', 'head', 'post', 'put', 'patch', 'delete', 'options', 'trace'].includes(method)) throw new Error('Invalid method');
    let route = test.path;
    for (const [key, value] of Object.entries(test.path_parameters ?? {})) route = route.replaceAll('{' + key + '}', encodeURIComponent(String(value)));
    if (!route.startsWith('/') || route.startsWith('//') || route.includes('{')) throw new Error('Unresolved or unsafe route');
    const url = new URL(base.pathname.replace(/\/$/, '') + route, base.origin);
    if (url.origin !== base.origin) throw new Error('Request leaves selected origin');
    for (const [key, value] of Object.entries(test.query ?? {})) url.searchParams.set(key, String(value));
    const response = await fetch(url, {method, redirect: 'error',
      headers: {'content-type': 'application/json', ...(test.header ?? {})},
      ...(test.body === undefined ? {} : {body: JSON.stringify(test.body)}),
      signal: AbortSignal.timeout(10000)});
    const reader = response.body?.getReader();
    let length = 0; const chunks = [];
    if (reader) for (;;) {
      const {done, value} = await reader.read(); if (done) break;
      length += value.length;
      if (length > 1024 * 1024) { await reader.cancel(); throw new Error('Response exceeds 1 MiB'); }
      chunks.push(Buffer.from(value));
    }
    const text = Buffer.concat(chunks).toString('utf8');
    const body = text === '' ? null : JSON.parse(text);
    actual.push({...test, path: test.path,
      response: {status: response.status, body, headers: Object.fromEntries(response.headers)}});
  }
  return engine({document, cases: actual});
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [contract, cases, base] = process.argv.slice(2);
    if (!base) throw new Error('Usage: http.mjs contract.json cases.json baseURL');
    const result = await verifyHttp(JSON.parse(fs.readFileSync(contract, 'utf8')),
      JSON.parse(fs.readFileSync(cases, 'utf8')), base);
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.valid && result.complete ? 0 : 1;
  } catch (err) { console.error(err.message); process.exitCode = 1; }
}

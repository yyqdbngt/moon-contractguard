import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {root} from './engine.mjs';
import {verifyHttp} from './http.mjs';
let invalid = false, hits = 0;
const server = http.createServer((request,response)=>{
  hits++; assert.equal(request.url,'/items?limit=2');
  response.writeHead(200,{'content-type':'application/json'});
  response.end(JSON.stringify([{id:invalid?'wrong':1}]));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
try {
  const document = JSON.parse(fs.readFileSync(path.join(root,'examples/contract.json'),'utf8'));
  const cases = [{method:'get',path:'/items',query:{limit:2}}];
  const url = 'http://127.0.0.1:' + server.address().port;
  const valid = await verifyHttp(document,cases,url);
  assert.equal(valid.valid,true); assert.equal(valid.complete,true);
  invalid = true;
  assert.equal((await verifyHttp(document,cases,url)).valid,false);
  assert.equal(hits,2);
  console.log('HTTP integration: real local GET, valid response and incorrect response rejection passed');
} finally { await new Promise(resolve=>server.close(resolve)); }

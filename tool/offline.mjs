import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join, relative, sep } from 'node:path';
const root = 'build/web';
const files = [];
async function walk(dir) {
  for (const entry of await readdir(dir, {withFileTypes:true})) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) await walk(path);
    else if (!/(\.map|\.symbols|offline\.js|flutter_service_worker\.js)$/.test(path) && !path.includes('skwasm')) files.push(relative(root,path).split(sep).join('/'));
  }
}
await walk(root);
const hash = createHash('sha256');
for (const path of files.sort()) hash.update(path).update(await readFile(join(root,path)));
const cache = 'careeros-shell-' + hash.digest('hex').slice(0,16);
await writeFile(join(root,'offline.js'), `
const current = ${JSON.stringify(cache)};
const assets = ${JSON.stringify(files)};
self.addEventListener('install', event => event.waitUntil((async()=>{
  const cache = await caches.open(current);
  await cache.addAll(assets.map(path => new Request(path, {cache:'reload'})));
})()));
self.addEventListener('activate', event => event.waitUntil((async()=>{
  for(const old of await caches.keys()) if(old.startsWith('careeros-shell-') && old !== current) await caches.delete(old);
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  if(event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith((async()=>{
    const cache = await caches.open(current);
    return await cache.match(event.request.mode === 'navigate' ? 'index.html' : event.request, {ignoreSearch:true}) || fetch(event.request);
  })());
});`);
console.log('Offline shell ready:', files.length, 'files');

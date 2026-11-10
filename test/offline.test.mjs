import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {runInNewContext} from 'node:vm';

test('packaged offline shell leaves OAuth and private API routes on the network',async()=>{
  const cwd=await mkdtemp(join(tmpdir(),'careeros-offline-test-'));
  await mkdir(join(cwd,'build/web'),{recursive:true});
  await writeFile(join(cwd,'build/web/index.html'),'<title>Fixture</title>');
  execFileSync(process.execPath,[fileURLToPath(new URL('../tool/offline.mjs',import.meta.url))],{cwd});
  const events={};
  runInNewContext(await readFile(join(cwd,'build/web/offline.js'),'utf8'),{
    URL,Request, self:{location:{origin:'http://127.0.0.1:4173'},addEventListener:(name,fn)=>events[name]=fn},
    caches:{open:async()=>({match:async()=> 'cached shell'})}
  });
  for(const path of ['/gmail/setup?lang=en','/gmail/callback?code=secret','/api/gmail']){
    let intercepted=false;
    events.fetch({request:{method:'GET',url:'http://127.0.0.1:4173'+path,mode:'navigate'},respondWith(){intercepted=true;}});
    assert.equal(intercepted,false,path);
  }
  let response;
  events.fetch({request:{method:'GET',url:'http://127.0.0.1:4173/',mode:'navigate'},respondWith(promise){response=promise;}});
  assert.equal(await response,'cached shell');
});

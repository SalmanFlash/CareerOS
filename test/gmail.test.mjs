import test from 'node:test';
import assert from 'node:assert/strict';
import {Readable} from 'node:stream';
import {mkdtemp,readFile,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGmail,protect} from '../tool/gmail.mjs';
import {extractNotice,deadlineCandidate} from '../tool/mail-notices.mjs';

const base='http://127.0.0.1:4173';
const scope='https://www.googleapis.com/auth/gmail.readonly';
const initialTime=Date.parse('2026-11-08T12:00:00Z');
const message=(id='abc123',body='Assignment deadline: November 10, 2026')=>({
  id,threadId:'thread-'+id,internalDate:String(initialTime),
  payload:{mimeType:'text/plain',headers:[
    {name:'From',value:'Course staff <staff@nu.edu.pk>'},
    {name:'Subject',value:'Assignment submission'},
  ],body:{data:Buffer.from(body).toString('base64url')}}
});
const seedAccount=()=>({
  email:'student@nu.edu.pk',refreshToken:'fixture-refresh',session:'fixture-session',
  accessToken:'fixture-access',expiresAt:initialTime+3600000,status:'connected',seen:[]
});
async function fixture(t,{seed,handler,failSave=false,autoScan=false}={}){
  const storageDir=await mkdtemp(join(tmpdir(),'careeros-gmail-test-'));
  let now=initialTime;
  const calls=[];
  if(seed)await writeFile(join(storageDir,'gmail.dpapi'),JSON.stringify(seed));
  let rejectSave=failSave;
  const service=await createGmail({
    storageDir,autoScan,now:()=>now,
    vault:async(operation,value)=>{if(operation==='protect'&&rejectSave)throw Error('fixture-save-failure');return value;},
    fetchGoogle:async(url,options)=>{
      calls.push({url,options});
      const custom=await handler?.(url,options);
      if(custom!==undefined)return custom;
      if(url.includes('/token'))return {access_token:'fixture-access',refresh_token:'fixture-refresh',scope,expires_in:3600};
      if(url.endsWith('/profile'))return {emailAddress:'student@nu.edu.pk'};
      if(url.includes('/messages?'))return {messages:[{id:'abc123'}]};
      if(url.includes('/messages/'))return message(url.split('/messages/')[1].split('?')[0]);
      throw Error('Unexpected fixture request');
    }
  });
  t.after(()=>service.close());
  async function route(path,body,{method='POST',headers={},raw}={}){
    const req=Readable.from([raw??JSON.stringify(body??{})]);
    req.method=method;
    req.headers={host:'127.0.0.1:4173',origin:base,'x-careeros':'1','x-careeros-csrf':service.status().csrf,...headers};
    const result={};
    const res={writeHead(code,h){result.code=code;result.headers=h;},end(text){result.text=text;try{result.json=JSON.parse(text);}catch{}}};
    await service.route(req,res,new URL(path,base));return result;
  }
  const configure=()=>route('/api/gmail/configure',{installed:{client_id:'fixture.apps.googleusercontent.com',client_secret:'fixture-client-secret'}});
  async function begin(campus='Karachi'){
    const result=await route('/api/gmail/connect',{campus});
    assert.equal(result.code,200);
    return new URL(result.json.url);
  }
  const finish=url=>route('/gmail/callback?state='+url.searchParams.get('state')+'&code=fixture-code',null,{method:'GET'});
  async function settled(){
    for(let i=0;i<100&&service.status().scanning;i++)await new Promise(r=>setTimeout(r,10));
    assert.equal(service.status().scanning,false,'scan must finish');
  }
  return {service,calls,storageDir,route,configure,begin,finish,settled,
    advance(ms=61000){now+=ms;},failSave(){rejectSave=true;}};
}

test('mail parsing rejects spoofed display addresses and treats dates as evidence',()=>{
  const m=message();
  const notice=extractNotice(m,'Karachi','student@nu.edu.pk');
  assert.equal(notice.deadline,'2026-11-10');
  assert.match(notice.deadlineEvidence,/November 10/);
  assert.equal(notice.url,'https://mail.google.com/mail/u/?authuser=student%40nu.edu.pk#all/abc123');
  m.payload.headers[0].value='"staff@nu.edu.pk" <outsider@example.org>';
  assert.equal(extractNotice(m,'Karachi','student@nu.edu.pk'),null);
  assert.equal(deadlineCandidate('Event November 10, 2026').date,'');
  assert.equal(deadlineCandidate('Deadline: 2026-02-30').date,'');
  assert.equal(deadlineCandidate('Deadline: 10/11/2026').date,'');
  assert.equal(deadlineCandidate('Deadline 2026-11-10 or 2026-11-11').date,'');
  assert.equal(deadlineCandidate('Submit by 10 November 2026').date,'2026-11-10');
});

test('OAuth uses PKCE, read-only scope and single-use state; scan imports once',async t=>{
  const f=await fixture(t);
  assert.equal((await f.configure()).code,200);
  const url=await f.begin();
  assert.equal(url.searchParams.get('scope'),scope);
  assert.equal(url.searchParams.get('code_challenge_method'),'S256');
  assert.equal((await f.finish(url)).code,200);
  await f.settled();
  const exchange=f.calls.find(c=>c.options.body?.get('grant_type')==='authorization_code');
  assert.equal(createHash('sha256').update(exchange.options.body.get('code_verifier')).digest('base64url'),url.searchParams.get('code_challenge'));
  assert.equal(f.service.status().notices.length,1);
  assert.equal((await f.finish(url)).code,400);
  f.advance();await f.service.scan();
  assert.equal(f.calls.filter(c=>c.url.includes('/messages/')).length,1);
  const publicState=JSON.stringify(f.service.status());
  assert.ok(!publicState.includes('fixture-refresh'));
  assert.ok(!publicState.includes('fixture-access'));
  const persisted=JSON.parse(await readFile(join(f.storageDir,'gmail.dpapi'),'utf8'));
  assert.equal(persisted.accounts.Karachi.refreshToken,'fixture-refresh');
});

test('bad Host, cross-site requests, Unicode CSRF and malformed JSON cannot break the service',async t=>{
  const f=await fixture(t);
  assert.equal((await f.route('/api/gmail',null,{method:'GET',headers:{host:'evil.example'}})).code,403);
  assert.equal((await f.route('/api/gmail/scan',{}, {headers:{origin:'https://evil.example'}})).code,403);
  assert.equal((await f.route('/api/gmail/scan',{}, {headers:{'x-careeros-csrf':'é'.repeat(64)}})).code,403);
  assert.equal((await f.route('/api/gmail/configure',null,{raw:'{bad'})).json.error,'invalid_input');
  assert.equal(f.service.status().storageError,false);
  assert.equal((await f.configure()).code,200);
});

test('authorization failure, expiry, campus mismatch and cancelled consent preserve disconnected state',async t=>{
  const f=await fixture(t);
  await f.configure();
  const lahore=await f.begin('Lahore');
  assert.equal((await f.finish(lahore)).code,400);
  const cancel=await f.begin();
  assert.equal((await f.route('/gmail/callback?state='+cancel.searchParams.get('state')+'&error=access_denied',null,{method:'GET'})).code,400);
  const expired=await f.begin();
  for(let i=0;i<11;i++)f.advance();
  assert.equal((await f.finish(expired)).code,400);
  assert.ok(f.service.status().accounts.every(a=>a.status==='not_connected'));
});

test('failed encrypted save never advertises a connected account',async t=>{
  const f=await fixture(t);
  await f.configure();const url=await f.begin();f.failSave();
  assert.equal((await f.finish(url)).code,400);
  assert.equal(f.service.status().storageError,true);
  assert.equal(f.service.status().accounts[0].status,'not_connected');
});

test('disconnect during OAuth callback prevents late reconnection',async t=>{
  let release,entered;
  const reached=new Promise(r=>entered=r),gate=new Promise(r=>release=r);
  const f=await fixture(t,{handler:async url=>{if(url.endsWith('/profile')){entered();await gate;return {emailAddress:'student@nu.edu.pk'};}}});
  await f.configure();const pending=f.finish(await f.begin());
  await reached;
  assert.equal((await f.route('/api/gmail/disconnect',{campus:'Karachi'})).code,200);
  release();assert.equal((await pending).code,400);
  assert.equal(f.service.status().accounts[0].status,'not_connected');
});

test('retry leaves the cursor unchanged until all fetched message details succeed',async t=>{
  let fail=true;
  const account=seedAccount();
  const f=await fixture(t,{seed:{version:1,client:{},accounts:{Karachi:account},notices:[]},handler:async url=>{
    if(url.includes('/messages?'))return url.includes('pageToken=next')?{messages:[{id:'def456'}]}:{messages:[{id:'abc123'}],nextPageToken:'next'};
    if(url.includes('/messages/def456')&&fail)throw Error('sync_failed');
  }});
  await f.service.scan();
  assert.equal(f.service.status().accounts[0].status,'sync_failed');
  assert.equal(f.service.status().accounts[0].lastSuccess,'');
  assert.equal(f.service.status().notices.length,0);
  fail=false;f.advance();await f.service.scan();
  assert.equal(f.service.status().notices.length,2);
  assert.equal(f.service.status().accounts[0].status,'connected');
  assert.equal(f.service.status().accounts[0].lastSuccess,new Date(initialTime).toISOString());
});

test('refresh token renewal recovers expired access and invalid grant asks for reconnect',async t=>{
  const account=seedAccount();account.expiresAt=0;
  let fail=false;
  const f=await fixture(t,{seed:{version:1,client:{client_id:'fixture',client_secret:'fixture'},accounts:{Karachi:account},notices:[]},handler:async url=>{
    if(url.includes('/token')&&fail)throw Error('reconnect_required');
    if(url.includes('/token'))return {access_token:'renewed',expires_in:0};
  }});
  await f.service.scan();
  assert.equal(f.service.status().accounts[0].status,'connected');
  fail=true;f.advance();await f.service.scan();
  assert.equal(f.service.status().accounts[0].status,'reconnect_required');
  assert.equal(f.service.status().notices.length,1);
});

test('disconnection during scanning cannot restore cached messages',async t=>{
  let release,entered;
  const reached=new Promise(r=>entered=r),gate=new Promise(r=>release=r);
  const f=await fixture(t,{seed:{version:1,client:{},accounts:{Karachi:seedAccount()},notices:[]},handler:async url=>{
    if(url.includes('/messages/')){entered();await gate;}
  }});
  const scanning=f.service.scan();await reached;
  await f.route('/api/gmail/disconnect',{campus:'Karachi'});
  release();await scanning;
  assert.equal(f.service.status().notices.length,0);
  assert.equal(f.service.status().accounts[0].status,'not_connected');
});

test('capped scans resume the original query and retain the first scan watermark',async t=>{
  const f=await fixture(t,{seed:{version:1,client:{},accounts:{Karachi:seedAccount()},notices:[]},handler:async url=>{
    if(url.includes('/messages?'))return url.includes('pageToken=remaining')?
      {messages:[{id:'ffff'}]}:
      {messages:Array.from({length:500},(_,i)=>({id:(i+1).toString(16)})),nextPageToken:'remaining'};
  }});
  await f.service.scan();
  assert.equal(f.service.status().accounts[0].status,'partial');
  f.advance(2*86400000);await f.service.scan();
  const lists=f.calls.filter(c=>c.url.includes('/messages?')).map(c=>new URL(c.url));
  assert.equal(lists[0].searchParams.get('q'),lists[1].searchParams.get('q'));
  assert.equal(lists[1].searchParams.get('pageToken'),'remaining');
  assert.equal(f.service.status().accounts[0].lastSuccess,new Date(initialTime).toISOString());
});

test('startup scans an already connected account without a browser request',async t=>{
  const f=await fixture(t,{autoScan:true,seed:{version:1,client:{},accounts:{Karachi:seedAccount()},notices:[]}});
  await new Promise(r=>setTimeout(r,1100));await f.settled();
  assert.equal(f.service.status().notices.length,1);
  assert.equal(f.service.status().accounts[0].lastSuccess,new Date(initialTime).toISOString());
});

test('a corrupt vault reports an error without overwriting the stored file',async t=>{
  const f=await fixture(t,{seed:{version:9,accounts:null}});
  assert.equal(f.service.status().storageError,true);
  assert.equal((await f.configure()).code,503);
  assert.deepEqual(JSON.parse(await readFile(join(f.storageDir,'gmail.dpapi'),'utf8')),{version:9,accounts:null});
});

test('Windows DPAPI encrypts and round-trips Unicode without exposing plaintext', {skip:process.platform!=='win32'},async()=>{
  const original=JSON.stringify({test:'CareerOS fixture • آزمائش',token:'fixture-only'});
  const encrypted=await protect('protect',original);
  assert.ok(!encrypted.includes('fixture-only'));
  assert.equal(await protect('unprotect',encrypted),original);
  await assert.rejects(protect('unprotect','not-valid-base64'));
});

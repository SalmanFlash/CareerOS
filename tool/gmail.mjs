import {readFile,writeFile,mkdir,rename} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {extractNotice} from './mail-notices.mjs';

const scope='https://www.googleapis.com/auth/gmail.readonly';
const campuses=['Karachi','Lahore'];
const interval=15*60*1000;
const base='http://127.0.0.1:4173';

export function protect(operation, text) {
  return new Promise((resolve,reject)=>{
    const ps=join(process.env.SystemRoot??'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
    const child=spawn(ps,['-NoProfile','-NonInteractive','-File',fileURLToPath(new URL('./windows-vault.ps1',import.meta.url)),operation],{windowsHide:true,stdio:['pipe','pipe','pipe']});
    let output='';
    const timeout=setTimeout(()=>child.kill(),15000);
    child.stdout.on('data',b=>output+=b);
    child.stderr.resume();
    child.on('error',()=>{clearTimeout(timeout);reject(new Error('storage_error'));});
    child.on('close',code=>{clearTimeout(timeout);code===0?resolve(output):reject(new Error('storage_error'));});
    child.stdin.on('error',()=>{});
    child.stdin.end(text);
  });
}

async function google(url,options={}) {
  const response=await fetch(url,{...options,signal:AbortSignal.timeout(20000)});
  const data=await response.json();
  if(!response.ok) {
    const error=new Error(data.error==='invalid_grant'||response.status===401?'reconnect_required':'sync_failed');
    error.status=response.status;
    throw error;
  }
  return data;
}

export async function createGmail({storageDir=join(process.env.LOCALAPPDATA??process.cwd(),'CareerOS'),fetchGoogle=google,vault=protect}={}) {
  const file=join(storageDir,'gmail.dpapi');
  let state={version:1,accounts:{},notices:[]}, storageError=false, queue=Promise.resolve(), scanning=false, lastScan=0;
  const csrf=randomBytes(32).toString('hex');
  const pending=new Map();
  try {
    state=JSON.parse(await vault('unprotect',await readFile(file,'utf8')));
    if(state.version!==1||!state.accounts||!Array.isArray(state.notices))throw new Error('storage_error');
  }
  catch(error){if(error.code!=='ENOENT')storageError=true;}

  function persist(){
    const snapshot=JSON.stringify(state);
    const operation=queue.catch(()=>{}).then(async()=>{
      const encrypted=await vault('protect',snapshot);
      await mkdir(dirname(file),{recursive:true});
      await writeFile(file+'.tmp',encrypted,{mode:0o600});
      await rename(file+'.tmp',file);
    });
    queue=operation;
    return operation;
  }
  async function client(){
    if(!state.client) throw new Error('setup_required');
    return state.client;
  }
  async function access(account){
    if(account.accessToken && account.expiresAt>Date.now()+60000)return account.accessToken;
    const config=await client();
    const data=await fetchGoogle('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({
      client_id:config.client_id,client_secret:config.client_secret,refresh_token:account.refreshToken,grant_type:'refresh_token'
    })});
    if(!data.access_token)throw new Error('reconnect_required');
    account.accessToken=data.access_token;account.expiresAt=Date.now()+Number(data.expires_in??3600)*1000;
    return data.access_token;
  }
  async function scanAccount(campus,account){
    account.lastAttempt=new Date().toISOString();
    try {
      const token=await access(account);
      const headers={Authorization:'Bearer '+token};
      // Rescan a small overlap so messages arriving during a scan are not lost.
      const after=account.lastSuccess?Math.max(Date.now()-30*86400000,Date.parse(account.lastSuccess)-86400000):Date.now()-7*86400000;
      const query=account.scanQuery??('after:'+Math.floor(after/1000)+' -in:trash -in:spam {from:nu.edu.pk from:classroom.google.com}');
      const ids=[];let page=account.nextPage??'';
      do {
        const params=new URLSearchParams({q:query,maxResults:'100'});
        if(page)params.set('pageToken',page);
        const list=await fetchGoogle('https://gmail.googleapis.com/gmail/v1/users/me/messages?'+params,{headers});
        if(!Array.isArray(list.messages)&&list.resultSizeEstimate!==0)throw new Error('sync_failed');
        ids.push(...(list.messages??[]).map(m=>m.id));
        page=list.nextPageToken??'';
      }while(page && ids.length<500);
      const found=[];
      const seen=new Set(account.seen??[]);
      for(const id of ids){
        if(seen.has(id))continue;
        const message=await fetchGoogle('https://gmail.googleapis.com/gmail/v1/users/me/messages/'+encodeURIComponent(id)+'?format=full',{headers});
        const notice=extractNotice(message,campus,account.email);
        if(notice)found.push(notice);
        seen.add(id);
      }
      if(state.accounts[campus]!==account)return;
      // A successful scan replaces updated copies without duplicating message IDs.
      const merged=new Map(state.notices.map(n=>[n.id,n]));
      for(const notice of found)merged.set(notice.id,notice);
      state.notices=[...merged.values()].filter(n=>Date.parse(n.received)>Date.now()-30*86400000)
        .sort((a,b)=>b.received.localeCompare(a.received)).slice(0,300);
      account.seen=[...seen].slice(-5000);
      account.nextPage=page;
      account.scanQuery=page?query:null;
      account.status=page?'partial':'connected';
      if(!page)account.lastSuccess=account.lastAttempt;
    }catch(error){if(state.accounts[campus]===account)account.status=error.message==='reconnect_required'?'reconnect_required':'sync_failed';}
  }
  async function scan(){
    if(scanning||storageError)return;
    if(Date.now()-lastScan<60000)return;
    lastScan=Date.now();
    scanning=true;
    try{
      for(const [campus,account] of Object.entries(state.accounts)){
        if(account.status!=='reconnect_required')await scanAccount(campus,account);
      }
      if(Object.keys(state.accounts).length)await persist();
    }catch{storageError=true;}
    finally{scanning=false;}
  }
  const timer=setInterval(()=>void scan(),interval);timer.unref();
  const start=setTimeout(()=>void scan(),1000);start.unref();
  const status=()=>({
    ready:!!state.client,storageError,scanning,csrf,intervalMinutes:15,
    accounts:campuses.map(campus=>{const account=state.accounts[campus];return{
      campus,email:account?.email??'',status:account?.status??'not_connected',
      lastSuccess:account?.lastSuccess??'',lastAttempt:account?.lastAttempt??''
    };}),notices:storageError?[]:state.notices
  });
  const send=(res,code,data)=>{res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));};
  function validCsrf(value){
    return typeof value==='string'&&value.length===csrf.length&&timingSafeEqual(Buffer.from(value),Buffer.from(csrf));
  }
  async function route(req,res,url){
    if(!url.pathname.startsWith('/api/gmail')&&!url.pathname.startsWith('/gmail/'))return false;
    // Exact Host and Origin checks prevent DNS rebinding and cross-site reads.
    if(req.headers.host!=='127.0.0.1:4173'){send(res,403,{error:'forbidden'});return true;}
    if(url.pathname==='/gmail/setup'&&req.method==='GET'){
      res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Frame-Options':'DENY','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-"+csrf+"'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'","Referrer-Policy":"no-referrer"});
      res.end(setupPage(csrf));return true;
    }
    if(url.pathname==='/gmail/callback'&&req.method==='GET'){
      const entry=pending.get(url.searchParams.get('state'));
      pending.delete(url.searchParams.get('state'));
      let success=false;
      try{
        if(storageError||!entry||entry.expires<Date.now()||url.searchParams.has('error'))throw new Error();
        const config=await client();
        const tokens=await fetchGoogle('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({
          client_id:config.client_id,client_secret:config.client_secret,code:url.searchParams.get('code')??'',
          code_verifier:entry.verifier,grant_type:'authorization_code',redirect_uri:base+'/gmail/callback'
        })});
        if(!tokens.refresh_token||!tokens.access_token||!String(tokens.scope??'').split(' ').includes(scope))throw new Error();
        const profile=await fetchGoogle('https://gmail.googleapis.com/gmail/v1/users/me/profile',{headers:{Authorization:'Bearer '+tokens.access_token}});
        const email=String(profile.emailAddress??'').toLowerCase();
        const domain=entry.campus==='Lahore'?'@lhr.nu.edu.pk':'@nu.edu.pk';
        if(!email.endsWith(domain))throw new Error();
        const previous=state.accounts[entry.campus];
        state.accounts[entry.campus]={
          email,refreshToken:tokens.refresh_token,accessToken:tokens.access_token,
          expiresAt:Date.now()+Number(tokens.expires_in??3600)*1000,status:'connected',
          seen:previous?.email===email?previous.seen??[]:[],lastSuccess:previous?.email===email?previous.lastSuccess??'':''
        };
        state.notices=state.notices.filter(n=>n.campus!==entry.campus||previous?.email===email);
        try {await persist();}catch{storageError=true;throw new Error();}
        success=true;
        // Newly authorized accounts should be checked promptly.
        lastScan=0;void scan();
      }catch{/* Authorization errors never reveal codes or tokens. */}
      res.writeHead(success?200:400,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'"});
      res.end('<!doctype html><meta charset="utf-8"><title>CareerOS Gmail</title><p>'+(success?'Connected. CareerOS will check your university email automatically.':'Connection did not complete. Confirm the selected campus account, test-user access, Gmail read permission and university policy, then try again.')+'</p><a href="/gmail/setup">Back to Gmail setup</a>');return true;
    }
    if(req.method==='GET'&&url.pathname==='/api/gmail'){
      if(req.headers['x-careeros']!=='1'||(req.headers.origin&&req.headers.origin!==base)){send(res,403,{error:'forbidden'});return true;}
      send(res,200,status());return true;
    }
    if(req.method!=='POST'||req.headers.origin!==base||!validCsrf(req.headers['x-careeros-csrf'])){send(res,403,{error:'forbidden'});return true;}
    if(storageError){send(res,503,{error:'storage_error'});return true;}
    try{
      let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>32000)throw new Error('invalid_input');}
      const input=JSON.parse(raw||'{}');
      if(url.pathname==='/api/gmail/configure'){
        if(Object.keys(state.accounts).length)throw new Error('disconnect_first');
        const config=input.installed;
        if(!config||typeof config.client_id!=='string'||!config.client_id.endsWith('.apps.googleusercontent.com')||typeof config.client_secret!=='string'||!config.client_secret)throw new Error('desktop_json_required');
        state.client={client_id:config.client_id,client_secret:config.client_secret};
        await persist();send(res,200,{ok:true});
      }else if(url.pathname==='/api/gmail/connect'){
        if(!campuses.includes(input.campus))throw new Error('invalid_input');
        const config=await client();
        for(const [key,value] of pending)if(value.expires<Date.now()||value.campus===input.campus)pending.delete(key);
        const key=randomBytes(32).toString('base64url'),verifier=randomBytes(32).toString('base64url');
        pending.set(key,{campus:input.campus,verifier,expires:Date.now()+10*60000});
        const params=new URLSearchParams({client_id:config.client_id,redirect_uri:base+'/gmail/callback',response_type:'code',
          scope,access_type:'offline',prompt:'consent select_account',state:key,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256'});
        send(res,200,{url:'https://accounts.google.com/o/oauth2/v2/auth?'+params});
      }else if(url.pathname==='/api/gmail/disconnect'){
        if(!campuses.includes(input.campus))throw new Error('invalid_input');
        delete state.accounts[input.campus];
        for(const [key,value] of pending)if(value.campus===input.campus)pending.delete(key);
        state.notices=state.notices.filter(n=>n.campus!==input.campus);
        await persist();send(res,200,{ok:true});
      }else if(url.pathname==='/api/gmail/scan'){
        if(!scanning)void scan();
        send(res,202,{ok:true});
      }else send(res,404,{error:'not_found'});
    }catch(error){
      const allowed=['invalid_input','disconnect_first','desktop_json_required','setup_required'];
      if(!allowed.includes(error.message)){storageError=true;}
      send(res,400,{error:allowed.includes(error.message)?error.message:'storage_error'});
    }
    return true;
  }
  return {route,scan,status,close(){clearInterval(timer);clearTimeout(start);}};
}

function setupPage(csrf){
  return `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CareerOS Gmail setup</title>
<style>body{max-width:660px;margin:40px auto;padding:20px;background:#080611;color:#f7f2ff;font:17px/1.6 system-ui}button,input{font:inherit;margin:10px 5px 10px 0;padding:10px}button{background:#b996ff;border:0;border-radius:8px;color:#171024}a{color:#b996ff}pre{white-space:pre-wrap}section{padding:18px;background:#171024;border-radius:12px;margin:15px 0}</style>
<h1>Connect university Gmail</h1><p>Open this page in Edge or Chrome for Google sign-in. CareerOS checks email every 15 minutes while this laptop and its local service are running.</p>
<section><h2>1. Google setup</h2><p>Create a Google Cloud project, enable Gmail API and configure Google Auth Platform for personal testing. Add both FAST email addresses as test users. Create a <b>Desktop app</b> OAuth client and download its JSON file.</p><a href="https://developers.google.com/workspace/gmail/api/quickstart/nodejs" target="_blank" rel="noreferrer">Google setup instructions</a>
<p>Choose the downloaded file. CareerOS stores credentials encrypted for your Windows account.</p><input id="config" type="file" accept="application/json,.json"><button id="save">Save Google setup</button></section>
<section><h2>2. Connect each campus</h2><button data-campus="Karachi">Connect Karachi</button><button data-campus="Lahore">Connect Lahore</button><p>Grant read-only Gmail access. The scanner uses university and Classroom messages, keeps short excerpts locally, and proposes dates for review. Google may require reconnecting when testing access expires or university policy changes.</p></section>
<section><h2>Connection status</h2><pre id="status">Loading…</pre><button id="scan">Check now</button><button data-disconnect="Karachi">Disconnect Karachi</button><button data-disconnect="Lahore">Disconnect Lahore</button><p>Disconnecting removes this service's credentials and cached notices for that campus. You can revoke Google access in your Google Account permissions.</p></section>
<p id="message" role="status"></p><a href="/">Back to CareerOS</a>
<script nonce="${csrf}">
const message=document.querySelector('#message');
const errors={desktop_json_required:'Choose the JSON for a Desktop app OAuth client.',disconnect_first:'Disconnect both accounts before changing the Google client.',storage_error:'Encrypted local storage is unavailable. Restart the local service and try again.',setup_required:'Save your Desktop app JSON first.'};
async function post(path,data={}){const response=await fetch('/api/gmail/'+path,{method:'POST',headers:{'Content-Type':'application/json','X-CareerOS-CSRF':'${csrf}'},body:JSON.stringify(data)});const json=await response.json();if(!response.ok)throw Error(errors[json.error]||'Could not complete this action.');return json;}
async function status(){try{const s=await(await fetch('/api/gmail',{headers:{'X-CareerOS':'1'}})).json();document.querySelector('#status').textContent=(s.ready?'Google client configured':'Google setup needed')+(s.storageError?' — encrypted storage error':'')+'\\n'+s.accounts.map(a=>a.campus+': '+(a.email||'Not connected')+' — '+a.status+(a.lastSuccess?'\\nLast checked: '+new Date(a.lastSuccess).toLocaleString():'' )).join('\\n');}catch{document.querySelector('#status').textContent='Local service unavailable.';}}
document.querySelector('#save').onclick=async()=>{try{const f=document.querySelector('#config').files[0];if(!f)throw Error('Choose the downloaded JSON file.');await post('configure',JSON.parse(await f.text()));message.textContent='Setup saved. Connect each campus below.';await status();}catch(e){message.textContent=e.message;}};
for(const b of document.querySelectorAll('[data-campus]'))b.onclick=async()=>{try{const data=await post('connect',{campus:b.dataset.campus});location.assign(data.url);}catch(e){message.textContent=e.message;}};
for(const b of document.querySelectorAll('[data-disconnect]'))b.onclick=async()=>{if(!confirm('Disconnect '+b.dataset.disconnect+' from CareerOS?'))return;try{await post('disconnect',{campus:b.dataset.disconnect});await status();}catch(e){message.textContent=e.message;}};
document.querySelector('#scan').onclick=async()=>{try{await post('scan');message.textContent='Scan requested.';await status();}catch(e){message.textContent=e.message;}};
status();setInterval(status,10000);
</script></html>`;
}

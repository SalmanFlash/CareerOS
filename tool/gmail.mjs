import {readFile,writeFile,mkdir,rename} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {extractNotice} from './mail-notices.mjs';
import {setupPage} from './gmail-setup.mjs';

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

export async function createGmail({storageDir=join(process.env.LOCALAPPDATA??process.cwd(),'CareerOS'),fetchGoogle=google,vault=protect,now=Date.now,autoScan=true}={}) {
  const file=join(storageDir,'gmail.dpapi');
  let state={version:1,accounts:{},notices:[]}, storageError=false, queue=Promise.resolve(), scanning=false, lastScan=-Infinity;
  const csrf=randomBytes(32).toString('hex');
  const pending=new Map();
  const activeAuth=new Map();
  try {
    const loaded=JSON.parse(await vault('unprotect',await readFile(file,'utf8')));
    if(loaded.version!==1||!loaded.accounts||Array.isArray(loaded.accounts)||!Array.isArray(loaded.notices))throw new Error('storage_error');
    for(const [campus,account] of Object.entries(loaded.accounts)){
      if(!campuses.includes(campus)||!account||typeof account.email!=='string'||typeof account.refreshToken!=='string')throw new Error('storage_error');
      account.session??=randomBytes(16).toString('hex');
    }
    state=loaded;
  }
  catch(error){if(error.code!=='ENOENT')storageError=true;}

  // Commit against the latest state after disk persistence succeeds. A scan
  // cannot restore a disconnected account or overwrite a concurrent connection.
  function commit(update){
    const operation=queue.catch(()=>{}).then(async()=>{
      if(storageError)throw new Error('storage_error');
      const next=structuredClone(state);
      if(update(next)===false)return false;
      try{
        const encrypted=await vault('protect',JSON.stringify(next));
        await mkdir(dirname(file),{recursive:true});
        await writeFile(file+'.tmp',encrypted,{mode:0o600});
        await rename(file+'.tmp',file);
      }catch{storageError=true;throw new Error('storage_error');}
      state=next;
      return true;
    });
    queue=operation;
    return operation;
  }
  async function client(){
    if(!state.client) throw new Error('setup_required');
    return state.client;
  }
  async function access(account){
    if(account.accessToken && account.expiresAt>now()+60000)return account.accessToken;
    const config=await client();
    const data=await fetchGoogle('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({
      client_id:config.client_id,client_secret:config.client_secret,refresh_token:account.refreshToken,grant_type:'refresh_token'
    })});
    if(!data.access_token)throw new Error('reconnect_required');
    if(data.refresh_token)account.refreshToken=data.refresh_token;
    account.accessToken=data.access_token;account.expiresAt=now()+Number(data.expires_in??3600)*1000;
    return data.access_token;
  }
  async function scanAccount(campus,account){
    account=structuredClone(account);
    account.lastAttempt=new Date(now()).toISOString();
    let found=[];
    try {
      let token=await access(account);
      async function request(path){
        try{return await fetchGoogle(path,{headers:{Authorization:'Bearer '+token}});}
        catch(error){
          if(error.status!==401)throw error;
          account.accessToken=null;
          token=await access(account);
          return fetchGoogle(path,{headers:{Authorization:'Bearer '+token}});
        }
      }
      // Rescan a small overlap so messages arriving during a scan are not lost.
      const after=account.lastSuccess?Math.max(now()-30*86400000,Date.parse(account.lastSuccess)-86400000):now()-7*86400000;
      const query=account.scanQuery??('after:'+Math.floor(after/1000)+' -in:trash -in:spam {from:nu.edu.pk from:classroom.google.com}');
      const ids=[];let page=account.nextPage??'';
      const pages=new Set();
      account.scanStarted??=account.lastAttempt;
      do {
        if(pages.has(page))throw new Error('sync_failed');
        pages.add(page);
        const params=new URLSearchParams({q:query,maxResults:'100'});
        if(page)params.set('pageToken',page);
        let list;
        try{list=await request('https://gmail.googleapis.com/gmail/v1/users/me/messages?'+params);}
        catch(error){
          if(error.status===400&&account.nextPage){account.nextPage='';account.scanQuery=null;account.scanStarted=null;}
          throw error;
        }
        if(!Array.isArray(list.messages)&&list.resultSizeEstimate!==0)throw new Error('sync_failed');
        ids.push(...(list.messages??[]).map(m=>m.id));
        page=list.nextPageToken??'';
      }while(page && ids.length<500);
      const seen=new Set(account.seen??[]);
      for(const id of ids){
        if(seen.has(id))continue;
        let message;
        try{message=await request('https://gmail.googleapis.com/gmail/v1/users/me/messages/'+encodeURIComponent(id)+'?format=full');}
        catch(error){if(error.status===404){seen.add(id);continue;}throw error;}
        const notice=extractNotice(message,campus,account.email);
        if(notice)found.push(notice);
        seen.add(id);
      }
      account.seen=[...seen].slice(-5000);
      account.nextPage=page;
      account.scanQuery=page?query:null;
      account.status=page?'partial':'connected';
      if(!page){account.lastSuccess=account.scanStarted;account.scanStarted=null;}
    }catch(error){
      found=[];
      account.status=error.message==='reconnect_required'?'reconnect_required':'sync_failed';
    }
    await commit(next=>{
      if(next.accounts[campus]?.session!==account.session)return false;
      next.accounts[campus]=account;
      const merged=new Map(next.notices.map(n=>[n.id,n]));
      for(const notice of found)merged.set(notice.id,notice);
      next.notices=[...merged.values()].filter(n=>Date.parse(n.received)>now()-30*86400000)
        .sort((a,b)=>b.received.localeCompare(a.received)).slice(0,300);
    });
  }
  async function scan(){
    if(scanning||storageError)return;
    if(now()-lastScan<60000)return;
    lastScan=now();
    scanning=true;
    try{
      for(const [campus,account] of Object.entries(state.accounts)){
        if(account.status!=='reconnect_required')await scanAccount(campus,account);
      }
    }catch{storageError=true;}
    finally{scanning=false;}
  }
  const timer=autoScan?setInterval(()=>void scan(),interval):null;timer?.unref();
  const start=autoScan?setTimeout(()=>void scan(),1000):null;start?.unref();
  const status=()=>({
    ready:!!state.client,storageError,scanning,csrf,intervalMinutes:15,
    accounts:campuses.map(campus=>{const account=state.accounts[campus];return{
      campus,email:account?.email??'',status:account?.status??'not_connected',
      lastSuccess:account?.lastSuccess??'',lastAttempt:account?.lastAttempt??''
    };}),notices:storageError?[]:state.notices
  });
  const send=(res,code,data)=>{res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));};
  function validCsrf(value){
    return typeof value==='string'&&/^[0-9a-f]{64}$/.test(value)&&timingSafeEqual(Buffer.from(value),Buffer.from(csrf));
  }
  async function route(req,res,url){
    if(!url.pathname.startsWith('/api/gmail')&&!url.pathname.startsWith('/gmail/'))return false;
    // Exact Host and Origin checks prevent DNS rebinding and cross-site reads.
    if(req.headers.host!=='127.0.0.1:4173'){send(res,403,{error:'forbidden'});return true;}
    if(url.pathname==='/gmail/setup'&&req.method==='GET'){
      res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Frame-Options':'DENY','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-"+csrf+"'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'","Referrer-Policy":"no-referrer"});
      res.end(setupPage(csrf,url.searchParams.get('lang')==='en'));return true;
    }
    if(url.pathname==='/gmail/callback'&&req.method==='GET'){
      const stateKey=url.searchParams.get('state');
      const entry=pending.get(stateKey);
      pending.delete(stateKey);
      let success=false;
      try{
        if(storageError||!entry||entry.expires<now()||activeAuth.get(entry.campus)!==stateKey||url.searchParams.has('error'))throw new Error();
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
        const connected=await commit(next=>{
          if(activeAuth.get(entry.campus)!==stateKey)return false;
          const previous=next.accounts[entry.campus];
          next.accounts[entry.campus]={
          email,refreshToken:tokens.refresh_token,accessToken:tokens.access_token,
          session:randomBytes(16).toString('hex'),
          expiresAt:now()+Number(tokens.expires_in??3600)*1000,status:'connected',
          seen:previous?.email===email?previous.seen??[]:[],lastSuccess:previous?.email===email?previous.lastSuccess??'':''
          };
          next.notices=next.notices.filter(n=>n.campus!==entry.campus||previous?.email===email);
        });
        if(!connected)throw new Error();
        activeAuth.delete(entry.campus);
        success=true;
        // Newly authorized accounts should be checked promptly.
        lastScan=-Infinity;void scan();
      }catch{/* Authorization errors never reveal codes or tokens. */}
      res.writeHead(success?200:400,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'"});
      const english=entry?.english===true;
      const message=success?
        (english?'Connected. CareerOS will check your university email automatically.':'Connected. CareerOS ab tumhari university email khud check karega.'):
        (english?'Connection did not complete. Check the campus account, test-user access, Gmail read permission and university policy, then try again.':'Connection complete nahi hua. Campus account, test-user access, Gmail read permission aur university policy check karke dobara try karo.');
      res.end('<!doctype html><meta charset="utf-8"><title>CareerOS Gmail</title><p>'+message+'</p><a href="/gmail/setup?lang='+(english?'en':'ur')+'">'+(english?'Back to Gmail setup':'Gmail setup par wapas')+'</a>');return true;
    }
    if(req.method==='GET'&&url.pathname==='/api/gmail'){
      if(req.headers['x-careeros']!=='1'||(req.headers.origin&&req.headers.origin!==base)){send(res,403,{error:'forbidden'});return true;}
      send(res,200,status());return true;
    }
    if(req.method!=='POST'||req.headers.origin!==base||!validCsrf(req.headers['x-careeros-csrf'])){send(res,403,{error:'forbidden'});return true;}
    if(storageError){send(res,503,{error:'storage_error'});return true;}
    try{
      let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>32000)throw new Error('invalid_input');}
      let input;
      try{input=JSON.parse(raw||'{}');}catch{throw new Error('invalid_input');}
      if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('invalid_input');
      if(url.pathname==='/api/gmail/configure'){
        if(Object.keys(state.accounts).length)throw new Error('disconnect_first');
        const config=input.installed;
        if(!config||typeof config.client_id!=='string'||!config.client_id.endsWith('.apps.googleusercontent.com')||typeof config.client_secret!=='string'||!config.client_secret)throw new Error('desktop_json_required');
        await commit(next=>{
          if(Object.keys(next.accounts).length)throw new Error('disconnect_first');
          next.client={client_id:config.client_id,client_secret:config.client_secret};
          pending.clear();activeAuth.clear();
        });send(res,200,{ok:true});
      }else if(url.pathname==='/api/gmail/connect'){
        if(!campuses.includes(input.campus))throw new Error('invalid_input');
        const config=await client();
        for(const [key,value] of pending)if(value.expires<now()||value.campus===input.campus)pending.delete(key);
        const key=randomBytes(32).toString('base64url'),verifier=randomBytes(32).toString('base64url');
        pending.set(key,{campus:input.campus,verifier,expires:now()+10*60000,english:input.language==='en'});
        activeAuth.set(input.campus,key);
        const params=new URLSearchParams({client_id:config.client_id,redirect_uri:base+'/gmail/callback',response_type:'code',
          scope,access_type:'offline',prompt:'consent select_account',state:key,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256'});
        send(res,200,{url:'https://accounts.google.com/o/oauth2/v2/auth?'+params});
      }else if(url.pathname==='/api/gmail/disconnect'){
        if(!campuses.includes(input.campus))throw new Error('invalid_input');
        activeAuth.delete(input.campus);
        for(const [key,value] of pending)if(value.campus===input.campus)pending.delete(key);
        await commit(next=>{
          delete next.accounts[input.campus];
          next.notices=next.notices.filter(n=>n.campus!==input.campus);
        });send(res,200,{ok:true});
      }else if(url.pathname==='/api/gmail/scan'){
        if(!scanning)void scan();
        send(res,202,{ok:true});
      }else send(res,404,{error:'not_found'});
    }catch(error){
      const allowed=['invalid_input','disconnect_first','desktop_json_required','setup_required'];
      send(res,400,{error:allowed.includes(error.message)?error.message:'storage_error'});
    }
    return true;
  }
  return {route,scan,status,close(){clearInterval(timer);clearTimeout(start);}};
}

export function setupPage(csrf, english = false) {
  const words = {
    title: ['University Gmail connect karo', 'Connect university Gmail'],
    intro: ['Google sign-in ke liye ye page Edge ya Chrome mein kholo. Laptop aur CareerOS service chalne par har 15 minute email check hogi.', 'Open this page in Edge or Chrome for Google sign-in. Email is checked every 15 minutes while this laptop and the CareerOS service are running.'],
    setup: ['1. Google setup', '1. Google setup'],
    instructions: ['Google Cloud project banao aur Gmail API enable karo. Google Auth Platform mein personal testing select karke dono FAST emails ko test users mein add karo. Desktop app OAuth client banao aur uski JSON download karo.', 'Create a Google Cloud project and enable Gmail API. Configure Google Auth Platform for personal testing and add both FAST emails as test users. Create a Desktop app OAuth client and download its JSON.'],
    docs: ['Google ki setup guide', 'Google setup instructions'],
    file: ['Downloaded JSON file chuno. Credentials tumhare Windows account ke liye encrypt honge.', 'Choose the downloaded JSON file. Credentials will be encrypted for your Windows account.'],
    save: ['Google setup save karo', 'Save Google setup'],
    connect: ['2. Har campus connect karo', '2. Connect each campus'],
    connectKarachi: ['Karachi connect karo', 'Connect Karachi'],
    connectLahore: ['Lahore connect karo', 'Connect Lahore'],
    consent: ['Gmail read-only access do. Scanner university aur Classroom emails se chhote excerpts aur mumkin deadlines nikaalega. Ye laptop par rahenge. Testing access expire hone ya university policy badalne par dobara sign-in chahiye ho sakta hai.', 'Grant read-only Gmail access. The scanner extracts short excerpts and possible deadlines from university and Classroom emails, and stores them on this laptop. Testing access expiry or university policy changes may require signing in again.'],
    status: ['Connection ka status', 'Connection status'],
    loading: ['Load ho raha hai…', 'Loading…'],
    scan: ['Abhi check karo', 'Check now'],
    disconnectKarachi: ['Karachi disconnect karo', 'Disconnect Karachi'],
    disconnectLahore: ['Lahore disconnect karo', 'Disconnect Lahore'],
    disconnectNote: ['Disconnect karne se is service ke campus credentials aur cached notices hat jayenge. Google Account permissions mein access revoke bhi kar sakte ho.', 'Disconnecting removes this service’s campus credentials and cached notices. You can also revoke access in Google Account permissions.'],
    back: ['CareerOS par wapas', 'Back to CareerOS'],
    chooseFile: ['Downloaded JSON file chuno.', 'Choose the downloaded JSON file.'],
    saved: ['Setup save ho gaya. Ab neeche har campus connect karo.', 'Setup saved. Connect each campus below.'],
    requested: ['Email check ki request bhej di.', 'Email check requested.'],
    configured: ['Google client tayyar hai', 'Google client configured'],
    setupNeeded: ['Google setup baqi hai', 'Google setup needed'],
    storageError: ['Encrypted local storage nahi khul saka. Local service restart karo.', 'Encrypted local storage is unavailable. Restart the local service.'],
    unavailable: ['Local service available nahi hai.', 'Local service unavailable.'],
    notConnected: ['Connect nahi hai', 'Not connected'],
    connected: ['Connected', 'Connected'],
    reconnect: ['Dobara Google sign-in karo', 'Google sign-in needed'],
    syncFailed: ['Aakhri scan fail hua', 'Last scan failed'],
    partial: ['Purani emails ka scan jaari hai', 'Catching up on older emails'],
    lastChecked: ['Aakhri check', 'Last checked'],
    confirm: ['Is campus ko CareerOS se disconnect karna hai?', 'Disconnect this campus from CareerOS?'],
    desktopJson: ['Desktop app OAuth client ki JSON chuno.', 'Choose the JSON for a Desktop app OAuth client.'],
    disconnectFirst: ['Google client badalne se pehle dono accounts disconnect karo.', 'Disconnect both accounts before changing the Google client.'],
    setupFirst: ['Pehle Desktop app JSON save karo.', 'Save your Desktop app JSON first.'],
    failed: ['Ye action complete nahi ho saka.', 'Could not complete this action.'],
  };
  const text = Object.fromEntries(Object.entries(words).map(([key, pair]) => [key, pair[english ? 1 : 0]]));
  const language = english ? 'en' : 'ur';
  return `<!doctype html>
<html lang="${english ? 'en' : 'ur-Latn'}">
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CareerOS Gmail</title>
<style>
body{max-width:660px;margin:32px auto;padding:20px;background:#080611;color:#f7f2ff;font:17px/1.6 system-ui}
button,input{font:inherit;margin:10px 5px 10px 0;padding:10px;max-width:100%;box-sizing:border-box}
button{background:#b996ff;border:0;border-radius:8px;color:#171024;cursor:pointer}
a{color:#b996ff}pre{white-space:pre-wrap;overflow-wrap:anywhere}
section{padding:18px;background:#171024;border-radius:12px;margin:15px 0}
</style>
<a href="/gmail/setup?lang=${english ? 'ur' : 'en'}">${english ? 'Roman Urdu' : 'English'}</a>
<h1>${text.title}</h1><p>${text.intro}</p>
<section><h2>${text.setup}</h2><p>${text.instructions}</p>
<a href="https://developers.google.com/workspace/gmail/api/quickstart/nodejs" target="_blank" rel="noreferrer">${text.docs}</a>
<p><label for="config">${text.file}</label></p>
<input id="config" type="file" accept="application/json,.json"><button id="save">${text.save}</button></section>
<section><h2>${text.connect}</h2>
<button data-campus="Karachi">${text.connectKarachi}</button><button data-campus="Lahore">${text.connectLahore}</button>
<p>${text.consent}</p></section>
<section><h2>${text.status}</h2><pre id="status">${text.loading}</pre>
<button id="scan">${text.scan}</button><button data-disconnect="Karachi">${text.disconnectKarachi}</button>
<button data-disconnect="Lahore">${text.disconnectLahore}</button><p>${text.disconnectNote}</p></section>
<p id="message" role="status"></p><a href="/">${text.back}</a>
<script nonce="${csrf}">
const text = ${JSON.stringify(text)};
const message = document.querySelector('#message');
const errors = {desktop_json_required:text.desktopJson, disconnect_first:text.disconnectFirst, storage_error:text.storageError, setup_required:text.setupFirst};
const states = {connected:text.connected, reconnect_required:text.reconnect, sync_failed:text.syncFailed, partial:text.partial};
async function post(path, data = {}) {
  const response = await fetch('/api/gmail/' + path, {
    method:'POST', headers:{'Content-Type':'application/json','X-CareerOS-CSRF':'${csrf}'}, body:JSON.stringify(data)
  });
  const json = await response.json();
  if (!response.ok) throw Error(errors[json.error] || text.failed);
  return json;
}
async function status() {
  try {
    const response = await fetch('/api/gmail', {headers:{'X-CareerOS':'1'}, cache:'no-store'});
    if (!response.ok) throw Error();
    const s = await response.json();
    document.querySelector('#status').textContent = (s.ready ? text.configured : text.setupNeeded)
      + (s.storageError ? '\\n' + text.storageError : '') + '\\n'
      + s.accounts.map(a => a.campus + ': ' + (a.email || text.notConnected) + ' — ' + (states[a.status] || text.notConnected)
        + (a.lastSuccess ? '\\n' + text.lastChecked + ': ' + new Date(a.lastSuccess).toLocaleString('en-GB', {timeZone:'Asia/Karachi'}) + ' PKT' : '')).join('\\n');
  } catch { document.querySelector('#status').textContent = text.unavailable; }
}
document.querySelector('#save').onclick = async () => {
  try {
    const file = document.querySelector('#config').files[0];
    if (!file) throw Error(text.chooseFile);
    await post('configure', JSON.parse(await file.text()));
    message.textContent = text.saved;
    await status();
  } catch (error) { message.textContent = error.message; }
};
for (const button of document.querySelectorAll('[data-campus]')) button.onclick = async () => {
  try {
    const data = await post('connect', {campus:button.dataset.campus, language:'${language}'});
    location.assign(data.url);
  } catch (error) { message.textContent = error.message; }
};
for (const button of document.querySelectorAll('[data-disconnect]')) button.onclick = async () => {
  if (!confirm(text.confirm)) return;
  try { await post('disconnect', {campus:button.dataset.disconnect}); await status(); }
  catch (error) { message.textContent = error.message; }
};
document.querySelector('#scan').onclick = async () => {
  try { await post('scan'); message.textContent = text.requested; await status(); }
  catch (error) { message.textContent = error.message; }
};
status();setInterval(status,10000);
</script></html>`;
}

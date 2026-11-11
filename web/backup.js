// Browser-only encrypted files. No network, credentials or mail-service state.
(() => {
  const encoder = new TextEncoder();
  const limit = 4 * 1024 * 1024;
  const iterations = 600000;
  const aad = encoder.encode('CareerOS encrypted backup v1');
  const encode = bytes => {
    let text = '';
    for (let i = 0; i < bytes.length; i += 8192) text += String.fromCharCode(...bytes.subarray(i, i + 8192));
    return btoa(text);
  };
  function decode(text) {
    if (typeof text !== 'string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(text)) throw Error('invalid_backup');
    return Uint8Array.from(atob(text), c => c.charCodeAt(0));
  }
  async function key(password, salt) {
    if (typeof password !== 'string' || password.length < 12 || password.length > 256) throw Error('password_length');
    const material = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveKey']);
    return crypto.subtle.deriveKey({name:'PBKDF2',hash:'SHA-256',salt,iterations}, material,
      {name:'AES-GCM',length:256}, false, ['encrypt','decrypt']);
  }
  async function encrypt(text, password) {
    const bytes = encoder.encode(text);
    if (bytes.length > limit) throw Error('backup_too_large');
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ciphertext = await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:aad}, await key(password,salt), bytes);
    return JSON.stringify({format:'careeros-encrypted',version:1,iterations,salt:encode(salt),iv:encode(iv),ciphertext:encode(new Uint8Array(ciphertext))});
  }
  async function decrypt(text, password) {
    if (text.length > limit * 1.5) throw Error('backup_too_large');
    const data = JSON.parse(text);
    if (data.format !== 'careeros-encrypted' || data.version !== 1 || data.iterations !== iterations) throw Error('invalid_backup');
    const salt = decode(data.salt), iv = decode(data.iv), ciphertext = decode(data.ciphertext);
    if (salt.length !== 16 || iv.length !== 12 || ciphertext.length < 16 || ciphertext.length > limit + 16) throw Error('invalid_backup');
    const plaintext = await crypto.subtle.decrypt({name:'AES-GCM',iv,additionalData:aad}, await key(password,salt), ciphertext);
    return new TextDecoder('utf-8',{fatal:true}).decode(plaintext);
  }
  function download(text) {
    const url = URL.createObjectURL(new Blob([text],{type:'application/json'}));
    const link = document.createElement('a');
    link.href = url; link.download = 'CareerOS-'+new Date().toISOString().slice(0,10)+'.careeros';
    document.body.append(link); link.click(); link.remove();
    setTimeout(()=>URL.revokeObjectURL(url),60000);
  }
  function pick() {
    return new Promise((resolve,reject)=>{
      const input = document.createElement('input');
      input.type = 'file'; input.accept = '.careeros,application/json'; input.hidden = true;
      document.body.append(input);
      input.addEventListener('cancel',()=>{input.remove();resolve('');},{once:true});
      input.addEventListener('change',async()=>{
        try {
          const file = input.files[0];
          if (!file) return resolve('');
          if (file.size > limit * 1.5) throw Error('backup_too_large');
          resolve(await file.text());
        } catch(error) { reject(error); }
        finally { input.remove(); }
      },{once:true});
      input.click();
    });
  }
  globalThis.careerosBackup = {encrypt,decrypt,download,pick};
})();

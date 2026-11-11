import test from 'node:test';
import assert from 'node:assert/strict';
await import('../web/backup.js');
const api=globalThis.careerosBackup;
const password='Fixture-only password آزمائش';
test('encrypted backups authenticate passwords, content and fresh randomness',async()=>{
  const text=JSON.stringify({note:'Private fixture • آزمائش',checkpoint:2});
  const a=await api.encrypt(text,password),b=await api.encrypt(text,password);
  assert.notEqual(a,b);assert.ok(!a.includes('Private fixture'));
  assert.equal(await api.decrypt(a,password),text);
  await assert.rejects(api.decrypt(a,'Incorrect fixture password'));
  const changed=JSON.parse(a);
  changed.ciphertext=(changed.ciphertext[0]==='A'?'B':'A')+changed.ciphertext.slice(1);
  await assert.rejects(api.decrypt(JSON.stringify(changed),password));
});
test('invalid or costly envelopes fail before expensive derivation',async()=>{
  for(const input of ['{}','not json',JSON.stringify({format:'careeros-encrypted',version:1,iterations:999999999})]) await assert.rejects(api.decrypt(input,password));
  await assert.rejects(api.encrypt('fixture','short'));
  await assert.rejects(api.encrypt('x'.repeat(4*1024*1024+1),password));
});

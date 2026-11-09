import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
const project='demo-daymind';
const auth='http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1';
const docs=`http://127.0.0.1:8180/v1/projects/${project}/databases/(default)/documents`;
async function user(){
  const response=await fetch(`${auth}/accounts:signUp?key=emulator-only`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${randomUUID()}@example.invalid`,password:randomUUID(),returnSecureToken:true})});
  assert.equal(response.status,200);return response.json();
}
const a=await user(),b=await user();
const headers=user=>({'Content-Type':'application/json',Authorization:`Bearer ${user.idToken}`});
const path=`${docs}/users/${a.localId}/tasks/poc`;
const fields={title:{stringValue:'Kiểm chứng Emulator'},revision:{integerValue:'1'}};
const create=await fetch(path,{method:'PATCH',headers:headers(a),body:JSON.stringify({fields})});assert.equal(create.status,200);
const saved=await create.json();assert.ok(saved.updateTime);
assert.equal((await fetch(path,{headers:headers(a)})).status,200);
assert.equal((await fetch(path,{headers:headers(b)})).status,403);
assert.equal((await fetch(path)).status,403);
const write=()=>fetch(`${docs}:commit`,{method:'POST',headers:headers(a),body:JSON.stringify({writes:[{update:{name:saved.name,fields:{...fields,revision:{integerValue:'2'}}},currentDocument:{updateTime:saved.updateTime}}]})});
const update=await write();assert.equal(update.status,200,await update.text());
const stale=await write();assert.notEqual(stale.status,200);assert.equal((await stale.json()).error.status,'FAILED_PRECONDITION');
assert.equal((await fetch(path,{method:'PATCH',headers:headers(b),body:JSON.stringify({fields})})).status,403);
await fetch(path,{method:'DELETE',headers:headers(a)});
for(const u of [a,b])assert.equal((await fetch(`${auth}/accounts:delete?key=emulator-only`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({idToken:u.idToken})})).status,200);
console.log('PASS: Auth A/B, authenticated Firestore CRUD, cross-user/anonymous denial, CAS stale-write rejection, cleanup. Emulator only.');

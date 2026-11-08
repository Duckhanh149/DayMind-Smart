import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { JSDOM } from 'jsdom';
const manifest=JSON.parse(fs.readFileSync('.openai/hosting.json','utf8'));
assert.ok(manifest.project_id);assert.equal(manifest.static.directory,'dist');
const html=fs.readFileSync('dist/index.html','utf8');const document=new JSDOM(html).window.document;
const ids=[...document.querySelectorAll('[id]')].map(e=>e.id);assert.equal(new Set(ids).size,ids.length,'Duplicate HTML id');
assert.equal(document.documentElement.lang,'vi');assert.match(document.title,/DayMind/);
for(const el of document.querySelectorAll('[src],[href]')){
  const value=el.getAttribute('src')||el.getAttribute('href');if(value.startsWith('./'))assert.ok(fs.existsSync(path.join('dist',value)),value);
}
const css=fs.readFileSync('dist/style.css','utf8');
for(const [,value] of css.matchAll(/url\(['"]?([^)'"\s]+)['"]?\)/g))if(!value.startsWith('data:'))assert.ok(fs.existsSync(path.join('dist',value)),value);
assert.ok(!/https?:\/\//.test(css),'Fonts and styles must be self-hosted');
for(const file of ['app.js','domain.js','database.js','storage.js']){
  const check=spawnSync(process.execPath,['--check','dist/'+file],{encoding:'utf8'});assert.equal(check.status,0,check.stderr);
}
const app=fs.readFileSync('dist/app.js','utf8');
for(const [,id] of app.matchAll(/\$\('#([a-zA-Z][\w-]*)'\)/g))assert.ok(ids.includes(id)||['retry-load'].includes(id),'Missing DOM hook #'+id);
assert.ok(fs.statSync('dist/vendor/sql-wasm.wasm').size>600000);
console.log('PASS: manifest, Vietnamese metadata, DOM IDs, local assets/fonts, module syntax and WASM payload.');

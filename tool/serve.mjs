import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {extname,resolve,sep} from 'node:path';
import {createGmail} from './gmail.mjs';
const root=resolve('build/web');
const gmail=await createGmail();
const types={'.js':'text/javascript','.json':'application/json','.html':'text/html','.wasm':'application/wasm','.png':'image/png','.css':'text/css','.ttf':'font/ttf'};
createServer(async(req,res)=>{
  try{
    const url=new URL(req.url,'http://127.0.0.1:4173');
    if(await gmail.route(req,res,url))return;
    const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const path=resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
    if(!path.startsWith(root+sep)) throw Error();
    const data=await readFile(path);
    res.writeHead(200,{'Content-Type':types[extname(path)]??'application/octet-stream','Cache-Control':'no-cache'});res.end(data);
  }catch{res.writeHead(404);res.end();}
}).listen(4173,'127.0.0.1',()=>console.log('CareerOS: http://127.0.0.1:4173'));

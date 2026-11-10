import {createHash} from 'node:crypto';

const relevant = /\b(deadlines?|due|submit|submissions?|assignments?|quiz(?:zes)?|exams?|midterms?|finals?|class(?:es)?|lectures?|schedule|registrations?|register|enroll|internships?|scholarships?|hackathons?|competitions?|fellowships?|workshops?|careers?|research|materials?|announcements?)\b/i;

function plainBody(part) {
  if (part.mimeType === 'text/plain' && part.body?.data) return Buffer.from(part.body.data,'base64url').toString('utf8');
  const parts = (part.parts ?? []).map(plainBody).filter(Boolean);
  if (parts.length) return parts.join('\n');
  return '';
}

function htmlBody(part) {
  if(part.mimeType === 'text/html' && part.body?.data) return Buffer.from(part.body.data,'base64url').toString('utf8')
    .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi,' ')
    .replace(/<br\s*\/?>|<\/p>|<\/div>/gi,'\n').replace(/<[^>]*>/g,' ')
    .replace(/&nbsp;/gi,' ').replace(/&amp;/gi,'&').replace(/&lt;/gi,'<').replace(/&gt;/gi,'>');
  return (part.parts??[]).map(htmlBody).filter(Boolean).join('\n');
}

// Extract only unambiguous full-year dates next to an explicit deadline term.
// Dates remain proposals for the user to verify against the linked email.
export function deadlineCandidate(text) {
  const months=['january','february','march','april','may','june','july','august','september','october','november','december'];
  const candidates = new Map();
  for(const line of text.split(/\r?\n/)){
    if(!/\b(deadline|due|last date|submit by|submission date)\b/i.test(line))continue;
    const patterns=[
      [...line.matchAll(/\b(20\d{2})-(\d{2})-(\d{2})\b/g)].map(m=>[Number(m[1]),Number(m[2]),Number(m[3])]),
      [...line.matchAll(/\b(\d{1,2})(?:st|nd|rd|th)?\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s*,?\s*(20\d{2})\b/gi)]
        .map(m=>[Number(m[3]),months.findIndex(v=>v.startsWith(m[2].toLowerCase().slice(0,3)))+1,Number(m[1])]),
      [...line.matchAll(/\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?\s*,?\s*(20\d{2})\b/gi)]
        .map(m=>[Number(m[3]),months.findIndex(v=>v.startsWith(m[1].toLowerCase().slice(0,3)))+1,Number(m[2])])
    ];
    for(const [year,month,day] of patterns.flat()){
      const value=[year,String(month).padStart(2,'0'),String(day).padStart(2,'0')].join('-');
      const date=new Date(value+'T00:00:00Z');
      if(!Number.isNaN(date.valueOf())&&date.toISOString().slice(0,10)===value) candidates.set(value,line.trim().slice(0,300));
    }
  }
  return candidates.size===1 ? {date:[...candidates.keys()][0],evidence:[...candidates.values()][0]} : {date:'',evidence:''};
}

export function extractNotice(message, campus, email) {
  const headers=Object.fromEntries((message.payload?.headers??[]).map(h=>[h.name.toLowerCase(),h.value]));
  const subject=headers.subject??'';
  const sender=headers.from??'';
  // Only university domains and Classroom notifications enter this feed.
  const address=sender.match(/<([^<>]+)>\s*$/)?.[1]??sender.trim();
  if(!/^[^\s<>@]+@(?:[a-z0-9-]+\.)*nu\.edu\.pk$/i.test(address)&&!/^no-reply@classroom\.google\.com$/i.test(address))return null;
  const body=(plainBody(message.payload??{})||htmlBody(message.payload??{})||message.snippet||'').slice(0,24000);
  if(!relevant.test(subject+' '+body))return null;
  const timestamp=Number(message.internalDate);
  if(!/^[0-9a-f]{1,64}$/i.test(message.id??'')||Number.isNaN(new Date(timestamp).valueOf()))return null;
  const received=new Date(timestamp).toISOString();
  const deadline=deadlineCandidate(subject+'\n'+body);
  const excerpt=body.replace(/\s+/g,' ').trim().slice(0,500);
  const canonicalSubject=subject.replace(/^(?:(?:re|fwd?)\s*:\s*)+/gi,'').trim();
  const fingerprint=createHash('sha256').update(canonicalSubject.toLowerCase()+'\n'+excerpt.toLowerCase()).digest('hex').slice(0,24);
  return {
    id:'gmail-'+campus.toLowerCase()+'-'+message.id, messageId:message.id,
    threadId:message.threadId, campus, subject, sender, received, excerpt,
    url:'https://mail.google.com/mail/u/?authuser='+encodeURIComponent(email)+'#all/'+message.id,
    deadline:deadline.date, deadlineEvidence:deadline.evidence, fingerprint,
    kind:/\b(exam|assignment|quiz|submit|submission|due|class|lecture|material)\b/i.test(subject)?'academic':'opportunity'
  };
}

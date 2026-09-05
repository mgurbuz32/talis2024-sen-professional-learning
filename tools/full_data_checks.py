import json, math, os, sys, zipfile
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import optimize, stats

ZIP = Path(os.environ.get('TALIS_ZIP','TALIS2024_teachers_NoESE_CSV.zip'))
OUT = Path('full_checks_output')
OUT.mkdir(exist_ok=True)

# ---------- helpers ----------
def find_csv():
    with zipfile.ZipFile(ZIP) as z:
        names=z.namelist()
        cand=[n for n in names if 'BTGINTT4' in n.upper() and n.lower().endswith('.csv')]
        if not cand:
            cand=[n for n in names if n.lower().endswith('.csv') and ('teacher' in n.lower() or 't4' in n.lower())]
        if not cand:
            raise RuntimeError('Could not locate ISCED-2 teacher CSV in archive. Contents: '+str(names[:30]))
        target=cand[0]
        print('Using',target)
        z.extract(target,'.')
    return Path(target)

def num(s):
    return pd.to_numeric(s, errors='coerce')

def valid_cat(s, allowed):
    x=num(s)
    return x.where(x.isin(allowed))

def make_design(d, extra=None):
    frames=[pd.DataFrame({'Intercept':np.ones(len(d)), 'SEN_PL':d.SEN_PL.astype(float).to_numpy()}, index=d.index)]
    for c in ['T4TYEXPTT','T4TCSIZE','TT4G47E','IDTQUEST']:
        frames.append(pd.get_dummies(d[c].astype(int), prefix=c, drop_first=True, dtype=float))
    if extra:
        for c in extra:
            if c in ['TT4G01','T4THEDAT']:
                frames.append(pd.get_dummies(d[c].astype(int), prefix=c, drop_first=True, dtype=float))
            else:
                frames.append(pd.DataFrame({c:d[c].astype(float).to_numpy()}, index=d.index))
    return pd.concat(frames,axis=1)

def wls_beta(X,y,w):
    xa=X.to_numpy(float); ya=np.asarray(y,float); wa=np.asarray(w,float)
    A=(xa.T*wa)@xa; b=(xa.T*wa)@ya
    try: return np.linalg.solve(A,b)
    except np.linalg.LinAlgError: return np.linalg.pinv(A)@b

def system_brr(d, extra=None):
    X=make_design(d,extra); idx=list(X.columns).index('SEN_PL'); y=d.T4SESEN.to_numpy(float)
    b=wls_beta(X,y,d.TCHWGT)[idx]
    reps=[]
    for r in range(1,101):
        reps.append(wls_beta(X,y,d[f'TRWGT{r}'])[idx])
    reps=np.asarray(reps)
    var=np.sum((reps-b)**2)/(100*(1-.5)**2)
    return float(b), float(math.sqrt(var))

def rem_meta(y,se):
    y=np.asarray(y,float); vi=np.asarray(se,float)**2
    def obj(t):
        w=1/(vi+t); mu=np.sum(w*y)/np.sum(w)
        return .5*(np.sum(np.log(vi+t))+np.log(np.sum(w))+np.sum(w*(y-mu)**2))
    res=optimize.minimize_scalar(lambda x: obj(math.exp(x)),bounds=(-20,5),method='bounded')
    tau=max(0.0,float(math.exp(res.x)))
    if obj(0)<=obj(tau): tau=0.0
    w=1/(vi+tau); mu=float(np.sum(w*y)/np.sum(w)); sem=float(math.sqrt(1/np.sum(w)))
    z=stats.norm.ppf(.975)
    wf=1/vi; muf=np.sum(wf*y)/np.sum(wf); Q=float(np.sum(wf*(y-muf)**2)); dfq=len(y)-1
    i2=max(0,(Q-dfq)/Q)*100 if Q>0 else 0
    return dict(B=mu,SE=sem,CI_low=mu-z*sem,CI_high=mu+z*sem,tau2=tau,Q=Q,df=dfq,I2=i2,
                PI_low=mu-z*math.sqrt(tau+sem**2),PI_high=mu+z*math.sqrt(tau+sem**2))

def weighted_alpha(d, items):
    dd=d[items+['TCHWGT']].dropna()
    if len(dd)<50: return np.nan, len(dd)
    X=dd[items].to_numpy(float); w=dd.TCHWGT.to_numpy(float); w=w/w.sum()
    mu=np.sum(X*w[:,None],axis=0); C=(X-mu).T@( (X-mu)*w[:,None] )
    k=len(items); total=C.sum()
    if total<=0: return np.nan,len(dd)
    alpha=k/(k-1)*(1-np.trace(C)/total)
    return float(alpha),len(dd)

# ---------- load ----------
csv=find_csv()
required=['CNTRY','IDTQUEST','T4SESEN','TT4G21K','TT4G24K','T4TYEXPTT','T4TCSIZE','TT4G47E','TCHWGT','T4SELF','TT4G01','T4THEDAT','ADJRT24']
required += [f'TT4G20{x}' for x in 'ABCDEFGHIJ']
required += [f'TT4G31{x}' for x in 'ABCDEF']
required += [f'TRWGT{i}' for i in range(1,101)]
head=pd.read_csv(csv,nrows=0)
missing=[c for c in required if c not in head.columns]
print('Missing requested columns:',missing)
use=[c for c in required if c in head.columns]
d=pd.read_csv(csv,usecols=use,low_memory=False)
for c in use: d[c]=num(d[c])
# ISCED-2 file should already be population 2. Keep B/C forms.
d=d[d.IDTQUEST.isin([2,3])].copy()
# Valid values / special missings
for c in ['T4TYEXPTT','T4TCSIZE']: d[c]=valid_cat(d[c],[1,2,3,4])
d['TT4G47E']=valid_cat(d['TT4G47E'],list(range(1,8)))
d['TT4G21K']=valid_cat(d['TT4G21K'],[1,2])
d['TT4G24K']=valid_cat(d['TT4G24K'],[1,2,3,4])
for c in [f'TT4G20{x}' for x in 'ABCDEFGHIJ']: d[c]=valid_cat(d[c],[1,2,3,4])
for c in [f'TT4G31{x}' for x in 'ABCDEF']: d[c]=valid_cat(d[c],[1,2,3,4])
d['TT4G01']=d['TT4G01'].where(d['TT4G01'].between(1,4))
d['T4THEDAT']=d['T4THEDAT'].where(d['T4THEDAT'].between(1,20))
# derived exposure
plitems=[f'TT4G20{x}' for x in 'ABCDEFGHIJ']
all_no=(d[plitems].notna().all(axis=1) & (d[plitems]==4).all(axis=1))
d['SEN_PL']=np.select([d.TT4G21K.eq(1),d.TT4G21K.eq(2),d.TT4G21K.isna()&all_no],[1,0,0],default=np.nan)
d['HIGH']=np.where(d.TT4G24K.eq(4),1,np.where(d.TT4G24K.isin([1,2,3]),0,np.nan))
# remove overlapping national Belgium aggregate
base=d[d.CNTRY.ne('BEL')].copy()
primary=base.dropna(subset=['T4SESEN','SEN_PL','T4TYEXPTT','T4TCSIZE','TT4G47E','IDTQUEST']).copy()
print('Primary N',len(primary),'systems',primary.CNTRY.nunique())

summary={'primary_N':int(len(primary)),'systems':int(primary.CNTRY.nunique())}

# T4SELF sensitivity
if 'T4SELF' in primary.columns:
    pself=primary.dropna(subset=['T4SELF']).copy()
    rows=[]
    for code,g in pself.groupby('CNTRY'):
        b,se=system_brr(g,['T4SELF']); rows.append((code,len(g),b,se))
    rr=pd.DataFrame(rows,columns=['CNTRY','N','B','SE']); rr.to_csv(OUT/'t4self_system.csv',index=False)
    summary['T4SELF_N']=int(len(pself)); summary['T4SELF_meta']=rem_meta(rr.B,rr.SE)

# Gender + education subset sensitivity
if {'TT4G01','T4THEDAT'}.issubset(primary.columns):
    ge=primary.dropna(subset=['TT4G01','T4THEDAT']).copy()
    counts=ge.groupby('CNTRY').size()
    systems=counts[counts>=50].index
    ge=ge[ge.CNTRY.isin(systems)].copy()
    r0=[]; r1=[]
    for code,g in ge.groupby('CNTRY'):
        # require variation in gender and education and enough rows
        if g.TT4G01.nunique()<2 or g.T4THEDAT.nunique()<2: continue
        b,se=system_brr(g,None); r0.append((code,len(g),b,se))
        b,se=system_brr(g,['TT4G01','T4THEDAT']); r1.append((code,len(g),b,se))
    r0=pd.DataFrame(r0,columns=['CNTRY','N','B','SE']); r1=pd.DataFrame(r1,columns=['CNTRY','N','B','SE'])
    common=set(r0.CNTRY)&set(r1.CNTRY); r0=r0[r0.CNTRY.isin(common)]; r1=r1[r1.CNTRY.isin(common)]
    r0.to_csv(OUT/'gender_education_primary.csv',index=False); r1.to_csv(OUT/'gender_education_adjusted.csv',index=False)
    summary['gender_education_N']=int(ge[ge.CNTRY.isin(common)].shape[0]); summary['gender_education_systems']=len(common)
    summary['gender_education_primary_meta']=rem_meta(r0.B,r0.SE); summary['gender_education_adjusted_meta']=rem_meta(r1.B,r1.SE)

# reliability: weighted alpha across raw six items; B/C and non-overlapping systems
items=[f'TT4G31{x}' for x in 'ABCDEF']
alphas=[]
for code,g in base.groupby('CNTRY'):
    a,n=weighted_alpha(g,items); alphas.append((code,n,a))
a=pd.DataFrame(alphas,columns=['CNTRY','complete_item_N','weighted_alpha']); a.to_csv(OUT/'t4sesen_reliability_by_system.csv',index=False)
valid=a.weighted_alpha.dropna()
summary['alpha_summary']={'systems':int(valid.size),'min':float(valid.min()),'median':float(valid.median()),'max':float(valid.max())}

# ADJRT24 values by system if supplied
if 'ADJRT24' in base.columns:
    adj=base.groupby('CNTRY')['ADJRT24'].agg(lambda x: sorted(pd.Series(x.dropna().unique()).tolist())).reset_index()
    adj.to_csv(OUT/'adjrt24_by_system.csv',index=False)

with open(OUT/'full_data_checks.json','w') as f: json.dump(summary,f,indent=2)
print(json.dumps(summary,indent=2))

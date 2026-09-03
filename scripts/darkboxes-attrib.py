import re, sys, subprocess, glob
# label-based parser for darkboxes lines; usage: attrib.py <thr> <png>...
thr=sys.argv[1]; files=sorted(sys.argv[2:], key=lambda x:int(re.search(r'f(\d+)\.png',x).group(1)))
out=subprocess.run(['/tmp/darkboxes',thr]+files,capture_output=True,text=True).stdout
rows=[]
for line in out.splitlines():
    kv=dict(re.findall(r'(\w+)=([\d.]+)%?', line)); kv['name']=line.split()[0]; rows.append(kv)
def f(k,r): return float(r.get(k,0))
print("  %-8s %6s %6s %6s %6s | %6s %6s %6s %6s" % ("frame","Rblk","Rred","Rgrn","Rblu","Tblk","Tred","Tgrn","Tblu"))
s1=s3=s3b=0
for r in rows:
    print("  %-8s %6.1f %6.1f %6.1f %6.1f | %6.1f %6.1f %6.1f %6.1f" % (r['name'],f('R',r),f('Rred',r),f('Rgreen',r),f('Rblue',r),f('T',r),f('Tred',r),f('Tgreen',r),f('Tblue',r)))
    if f('Rgreen',r)>=20: s1+=1
    if f('Rblue',r)>=20: s3b+=1
    if f('R',r)>=20 and f('Rgreen',r)<20 and f('Rblue',r)<20: s3+=1
print("  right band >=20%%: GREEN (reframe-grow, S1) %d | BLUE (child layer, S3) %d | BLACK with no colour (beneath) %d | of %d" % (s1,s3b,s3,len(rows)))

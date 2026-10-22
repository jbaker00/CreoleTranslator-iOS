import jwt,time,json,subprocess
k=open('/Users/jamesbaker/code/AppStoreConnect/AuthKey_597FS4329D.p8').read()
t=jwt.encode({'iss':'69a6de71-bcfd-47e3-e053-5b8c7c11a4d1','iat':int(time.time()),'exp':int(time.time())+1200,'aud':'appstoreconnect-v1'},k,algorithm='ES256',headers={'kid':'597FS4329D'})
def api(method,u,body=None):
    cmd=['curl','-sg','-X',method,'-H','Authorization: Bearer '+t,'-H','Content-Type: application/json']
    if body is not None: cmd+=['-d',json.dumps(body)]
    o=subprocess.run(cmd+['https://api.appstoreconnect.apple.com'+u],capture_output=True,text=True).stdout
    return json.loads(o) if o.strip() else {}
g=lambda u: api('GET',u)
CREOLE='6758288798'

import json, hashlib, os, ssl, time, urllib.request, certifi
from asc_lib import api

CTX = ssl.create_default_context(cafile=certifi.where())
IPHONE, IPAD = 'APP_IPHONE_67', 'APP_IPAD_PRO_3GEN_129'


def ok(r, what):
    if 'errors' in r:
        raise SystemExit(f'{what}: {json.dumps(r["errors"])[:900]}')
    return r


def put_ops(ops, data):
    for op in ops:
        req = urllib.request.Request(op['url'], data=data[op['offset']:op['offset'] + op['length']],
                                     method=op['method'],
                                     headers={h['name']: h['value'] for h in op['requestHeaders']})
        urllib.request.urlopen(req, context=CTX).read()


def screenshot_set(rel, rel_type, owner_id, display, files):
    """Replace any existing set of this display type under owner, then upload files in order."""
    existing = api('GET', f'/v1/{rel_type}/{owner_id}/appScreenshotSets').get('data', [])
    sid = next((s['id'] for s in existing if s['attributes']['screenshotDisplayType'] == display), None)
    if sid:
        for shot in api('GET', f'/v1/appScreenshotSets/{sid}/appScreenshots?limit=50').get('data', []):
            ok(api('DELETE', f"/v1/appScreenshots/{shot['id']}") or {}, 'delete old shot')
    else:
        sid = ok(api('POST', '/v1/appScreenshotSets', {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display},
            "relationships": {rel: {"data": {"type": rel_type, "id": owner_id}}}}}), 'create set')['data']['id']
    for f in files:
        data = open(f, 'rb').read()
        r = ok(api('POST', '/v1/appScreenshots', {"data": {"type": "appScreenshots",
            "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}}), 'reserve')
        put_ops(r['data']['attributes']['uploadOperations'], data)
        ok(api('PATCH', f"/v1/appScreenshots/{r['data']['id']}", {"data": {"type": "appScreenshots",
            "id": r['data']['id'], "attributes": {"uploaded": True,
            "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}), 'commit')
    return sid


def create_cpp(app, template_version, name, locales):
    """locales: {locale: {promo, keywords, iphone:[files], ipad:[files] (optional)}}"""
    existing = {c['attributes']['name']: c['id'] for c in api('GET', f'/v1/apps/{app}/appCustomProductPages?limit=100')['data']}
    if name in existing:
        page = existing[name]
        version = api('GET', f'/v1/appCustomProductPages/{page}/appCustomProductPageVersions')['data'][0]['id']
    else:
        locs = list(locales)
        body = {"data": {"type": "appCustomProductPages", "attributes": {"name": name},
            "relationships": {"app": {"data": {"type": "apps", "id": app}},
                "appStoreVersionTemplate": {"data": {"type": "appStoreVersions", "id": template_version}},
                "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
            "included": [{"type": "appCustomProductPageVersions", "id": "${v1}", "relationships": {
                "appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": f"${{l{i}}}"} for i in range(len(locs))]}}}]
                + [{"type": "appCustomProductPageLocalizations", "id": f"${{l{i}}}",
                    "attributes": {"locale": loc, "promotionalText": locales[loc]['promo']}} for i, loc in enumerate(locs)]}
        r = ok(api('POST', '/v1/appCustomProductPages', body), f'create {name}')
        page = r['data']['id']
        version = api('GET', f'/v1/appCustomProductPages/{page}/appCustomProductPageVersions')['data'][0]['id']
    out = {'page': page, 'version': version, 'locs': {}}
    for l in api('GET', f'/v1/appCustomProductPageVersions/{version}/appCustomProductPageLocalizations')['data']:
        loc = l['attributes']['locale']
        if loc not in locales:
            continue
        spec = locales[loc]
        lid = l['id']
        out['locs'][loc] = lid
        api('PATCH', f'/v1/appCustomProductPageLocalizations/{lid}', {"data": {"type": "appCustomProductPageLocalizations",
            "id": lid, "attributes": {"promotionalText": spec['promo']}}})
        if spec.get('keywords'):
            ok(api('POST', f'/v1/appCustomProductPageLocalizations/{lid}/relationships/searchKeywords',
                   {"data": [{"type": "appKeywords", "id": k} for k in spec['keywords']]}), f'keywords {name} {loc}')
        screenshot_set('appCustomProductPageLocalization', 'appCustomProductPageLocalizations', lid, IPHONE, spec['iphone'])
        if spec.get('ipad'):
            screenshot_set('appCustomProductPageLocalization', 'appCustomProductPageLocalizations', lid, IPAD, spec['ipad'])
        print(f'  {name} {loc}: promo, {len(spec.get("keywords") or [])} keywords, {len(spec["iphone"])} iPhone'
              + (f', {len(spec["ipad"])} iPad' if spec.get('ipad') else ''))
    return out


def library_image(app, path):
    data = open(path, 'rb').read()
    r = ok(api('POST', '/v1/appAssetLibraryImages', {"data": {"type": "appAssetLibraryImages",
        "attributes": {"category": "CREATIVE_ASSETS", "fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": app}}}}}), 'img create')
    iid = r['data']['id']
    put_ops(r['data']['attributes']['uploadOperations'], data)
    ok(api('PATCH', f'/v1/appAssetLibraryImages/{iid}', {"data": {"type": "appAssetLibraryImages", "id": iid,
        "attributes": {"uploaded": True}}}), 'img commit')
    return iid


def place(loc_id, placement, image_id):
    return api('POST', '/v1/appAssetLibraryPlacements', {"data": {"type": "appAssetLibraryPlacements",
        "attributes": {"placementType": placement},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}},
                          "image": {"data": {"type": "appAssetLibraryImages", "id": image_id}}}}})


def delivery_states(rel_type, owner_id):
    r = api('GET', f'/v1/{rel_type}/{owner_id}/appScreenshotSets?include=appScreenshots&fields[appScreenshots]=assetDeliveryState')
    return [x['attributes']['assetDeliveryState']['state'] for x in r.get('included', [])]

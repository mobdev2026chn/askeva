import urllib.request, json

token = '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'

url = 'https://api.askeva.net/v1/chat/918113801548/0/50'
req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
try:
    with urllib.request.urlopen(req) as r:
        messages = json.loads(r.read().decode()).get('data', [])
        print(f"Total messages: {len(messages)}")
        for m in messages:
            mtype = str(m.get('type')).lower()
            mdata = m.get('data') or {}
            mint = mdata.get('interactive') or {}
            mint_type = str(mint.get('type')).lower()
            
            # Print if type matches
            if mtype in ['catalog', 'interactive'] or mint_type in ['product', 'product_list', 'order']:
                print(f"\n--- MATCHED MESSAGE (id={m.get('_id')}) ---")
                print(f"type: {mtype}")
                print(json.dumps(m, indent=2))
except Exception as e:
    print("Error:", e)

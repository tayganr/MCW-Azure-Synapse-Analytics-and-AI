########### Python Form Recognizer Labeled Async Train #############
import json
import time
import sys
from requests import get, post

# Endpoint URL
endpoint = r"https://<formrecognizerservicename>.cognitiveservices.azure.com/"
post_url = endpoint + r"/formrecognizer/v2.0/custom/models"
source = r"https://asastore{{suffix}}.blob.core.windows.net/invoices?sv=2019-12-12&ss=bfqt&srt=sco&sp=rwdlacupx&se=2020-10-10T07:44:28Z&st=2020-10-06T23:44:28Z&spr=https&sig=ogYvp8%2FhNfBuCrLjCzba7n3%2FjZZWWyfTpD%2BaESmA3Yw%3D"
prefix = "Train"
includeSubFolders = False
useLabelFile = False

headers = {
    # Request headers
    'Content-Type': 'application/json',
    'Ocp-Apim-Subscription-Key': '<FormRecognizer KEY1 Value>',
}

body =     {
    "source": source,
    "sourceFilter": {
        "prefix": prefix,
        "includeSubFolders": includeSubFolders
    },
    "useLabelFile": useLabelFile
}

try:
    resp = post(url = post_url, json = body, headers = headers)
    if resp.status_code != 201:
        print("POST model failed (%s):\n%s" % (resp.status_code, json.dumps(resp.json())))
        sys.exit()
    print("POST model succeeded:\n%s" % resp.headers)
    get_url = resp.headers["location"]
except Exception as e:
    print("POST model failed:\n%s" % str(e))
    sys.exit()


n_tries = 15
n_try = 0
wait_sec = 5
max_wait_sec = 60
while n_try < n_tries:
    try:
        resp = get(url = get_url, headers = headers)
        resp_json = resp.json()
        if resp.status_code != 200:
            print("GET model failed (%s):\n%s" % (resp.status_code, json.dumps(resp_json)))
            sys.exit()
        model_status = resp_json["modelInfo"]["status"]
        if model_status == "ready":
            print("Training succeeded:\n%s" % json.dumps(resp_json))
            sys.exit()
        if model_status == "invalid":
            print("Training failed. Model is invalid:\n%s" % json.dumps(resp_json))
            sys.exit()
        # Training still running. Wait and retry.
        time.sleep(wait_sec)
        n_try += 1
        wait_sec = min(2*wait_sec, max_wait_sec)     
    except Exception as e:
        msg = "GET model failed:\n%s" % str(e)
        print(msg)
        sys.exit()
print("Train operation did not complete within the allocated time.")
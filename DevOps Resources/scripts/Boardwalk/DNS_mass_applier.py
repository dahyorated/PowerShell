import requests
import json

code =  "N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
tower_url = f"http://gtpprovisioning.sbp.eyclienthub.com/api/tower?code={code}"
client_adress = [
        "gtpbw01170p",
        "gtpbw01170weup"
        
        
    ## 1. ADD IN ALL OF THE PREFIXES YOU WOULD LIKE HERE, FOR EXAMPLE "gtpbw01205p" 
    ##     FOR THE URL gtpbw01205p.sbp.eyclienthub.com
]

## 2.  ADD IN THE CNAME RECORD OF THE WAF BELOW
#Gateway 02 - gtpwafbw505c26de.westeurope.cloudapp.azure.com
#Gateway 04 - gtpwafbwca1a96a6.westeurope.cloudapp.azure.com
#Gateway 05 - gtpwafbwc28e92f2.westeurope.cloudapp.azure.com
#Gateway 06 - gtpwafbwe45d06b2.westeurope.cloudapp.azure.com
#Gateway 07 - gtpwafbw2408d9d3.westeurope.cloudapp.azure.com
#Gateway 08 - gtpwafbw9243bec4.westeurope.cloudapp.azure.com
#Gateway 09 - gtpwafbw9127a2ce.westeurope.cloudapp.azure.com


#GW2
waf_address = "gtpwafbw505c26de.westeurope.cloudapp.azure.com"
#GW4
#waf_address = "gtpwafbwca1a96a6.westeurope.cloudapp.azure.com"
#GW5
#waf_address = "gtpwafbwc28e92f2.westeurope.cloudapp.azure.com"
#GW6
#waf_address = "gtpwafbwe45d06b2.westeurope.cloudapp.azure.com"
#GW7
#waf_address = "gtpwafbw2408d9d3.westeurope.cloudapp.azure.com"
#GW8
#waf_address = "gtpwafbw9243bec4.westeurope.cloudapp.azure.com"
#GW9
#waf_address = "gtpwafbw9127a2ce.westeurope.cloudapp.azure.com"

###############

def call_dns_adder(client, internal_external_flag, waf_address):
    if internal_external_flag == "internal": 
        payload = {
                    "component": "update-internal-cname-dns-records",
                    "extra_vars": {
                        "Action": "add",
                        "RecordName": client,
                        "ZoneName": "sbp.eyclienthub.com",
                        "Alias": waf_address,
                        "TTL": "01:00:00",
                        "var_environment": "Production"
                    }
            }
    elif internal_external_flag == "external": 
        payload = {
                "component": "eydnscloudone",
                "extra_vars": {
                    "var_action": "add",
                    "var_record_type": "CNAME",
                    "var_zone": "azure",
                    "var_fqdn":f"{client}.sbp.eyclienthub.com",
                    "var_value": waf_address,
                    "var_owner":"Dante.DeWitt@ey.com; john.vande.woude@ey.com",
                    "var_environment":"Production"        
                }
            }
    else: 
        return "unknown request"

    payload_json = json.dumps(payload)
    headers = {
    'Content-Type': 'application/json',
    'Content-Type': 'text/plain'
    }

    response = requests.request("POST", tower_url, headers=headers, data = payload_json)
    results_string = "For client: " , client, response, response.text.encode('utf8')
    return results_string

def bulk_url_creator(client_address_array, tower_url, waf_address): 
    for client in client_address_array: 
        internal_results  = call_dns_adder(client, "internal", waf_address)
        external_results  = call_dns_adder(client, "external", waf_address)
        print("INTERNAL: ", internal_results)
        print("EXTERNAL: ", external_results)


bulk_url_creator(client_adress, tower_url, waf_address)

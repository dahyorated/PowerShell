	SELECT 
	cc.ClientId, c.ClientNm, 
	csc.AccountName as AppService,
	'AppService (appName): ' + csc.AccountName + CHAR(13) + CHAR(10) +
	'(404)' + CHAR(13) + CHAR(10) + 'https://' + csc.ResourceURL + CHAR(13) + CHAR(10) +
	'(Swagger)' + CHAR(13) + CHAR(10) + 'https://' + csc.ResourceURL + '/html/PingBWServer.html' + CHAR(13) + CHAR(10) +
	'(403)' + CHAR(13) + CHAR(10) +  'https://' + csc.AccountName + '.azurewebsites.net/' AS SmokeTest
	FROM Common.ClientConfiguration cc
	INNER JOIN Common.ClientServiceConfiguration csc ON csc.ClientConfigId = cc.ClientConfigId
	INNER JOIN common.ClientProfile cp ON cp.ClientId = cc.ClientId AND cp.CurrentRecord = 1
	INNER JOIN common.AzureRegion ar ON ar.AzureRegionId = cc.AzureRegionId
	INNER JOIN common.Client c ON c.ClientId = cc.ClientId
	WHERE 
	cc.ClientId BETWEEN 1281 AND 1288
	--cc.ClientId IN (1281)
	AND csc.ResourceTypeId IN (3) 
AND csc.Service IN ('boardwalk','bwapods')


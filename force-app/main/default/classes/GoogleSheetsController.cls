public with sharing class GoogleSheetsController {
    private static final String NAMED_CREDENTIAL = 'GoogleSheets';
    private static final String DEFAULT_RANGE = 'A1:Z1000'; // Adjust range as needed
    private static final String BASE_URL = 'callout:' + NAMED_CREDENTIAL + '/v4/spreadsheets/';

    // Helper method to extract spreadsheet ID from URL
    private static String extractSpreadsheetId(String url) {
        if (String.isBlank(url)) return '';
        
        // Handle different URL formats
        // Format 1: https://docs.google.com/spreadsheets/d/{spreadsheetId}/edit
        // Format 2: https://docs.google.com/spreadsheets/d/{spreadsheetId}/view
        Pattern p = Pattern.compile('/spreadsheets/d/([a-zA-Z0-9-_]+)');
        Matcher m = p.matcher(url);
        if (m.find()) {
            return m.group(1);
        }
        return url; // If the input is already a spreadsheet ID
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSheetData(String spreadsheetUrl, String sheetName) {
        String spreadsheetId = extractSpreadsheetId(spreadsheetUrl);
        if (String.isBlank(spreadsheetId)) {
            throw new AuraHandledException('Invalid Google Sheets URL');
        }

        String range = String.isNotBlank(sheetName) ? sheetName + '!' + DEFAULT_RANGE : DEFAULT_RANGE;
        try {
            // Construct the API URL using Named Credentials
            String endpoint = 'callout:' + NAMED_CREDENTIAL + 
                            '/v4/spreadsheets/' + spreadsheetId + 
                            '/values/' + range;

            // Make the HTTP request
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // Parse the response
                Map<String, Object> responseBody = (Map<String, Object>) 
                    JSON.deserializeUntyped(response.getBody());
                
                List<Object> values = (List<Object>) responseBody.get('values');
                if (values == null || values.isEmpty()) {
                    return new List<Map<String, String>>();
                }
                
                // Get headers from first row
                List<String> headers = new List<String>();
                for (Object header : (List<Object>)values[0]) {
                    headers.add(String.valueOf(header));
                }
                
                // Convert data rows to map
                List<Map<String, String>> result = new List<Map<String, String>>();
                for (Integer i = 1; i < values.size(); i++) {
                    List<Object> row = (List<Object>)values[i];
                    Map<String, String> rowMap = new Map<String, String>();
                    
                    for (Integer j = 0; j < headers.size() && j < row.size(); j++) {
                        rowMap.put(headers[j], String.valueOf(row[j]));
                    }
                    
                    result.add(rowMap);
                }
                
                return result;
            } else {
                throw new AuraHandledException('Error fetching data: ' + 
                    response.getStatusCode() + ' ' + response.getStatus());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateSheetData(String spreadsheetUrl, String sheetName, Integer rowIndex, Map<String, String> updatedData) {
        String spreadsheetId = extractSpreadsheetId(spreadsheetUrl);
        if (String.isBlank(spreadsheetId)) {
            throw new AuraHandledException('Invalid Google Sheets URL');
        }

        try {
            // Get the current headers first
            List<Map<String, String>> currentData = getSheetData(spreadsheetUrl, sheetName);
            List<String> headers = new List<String>(currentData[0].keySet());
            
            // Prepare the values array
            List<Object> values = new List<Object>();
            for(String header : headers) {
                values.add(updatedData.containsKey(header) ? updatedData.get(header) : '');
            }
            
            // Construct the update request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'values' => new List<List<Object>>{ values },
                'majorDimension' => 'ROWS'
            };

            // Calculate the update range (e.g., Sheet1!A2 for row 1 since row 0 is headers)
            String range = (String.isNotBlank(sheetName) ? sheetName + '!' : '') + 
                         'A' + (rowIndex + 2); // +2 because rowIndex is 0-based and we skip header row

            // Make the API request
            String endpoint = BASE_URL + spreadsheetId + '/values/' + range + 
                            '?valueInputOption=RAW';

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('PUT');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Error updating data: ' + 
                    response.getStatusCode() + ' ' + response.getStatus());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void appendSheetData(String spreadsheetUrl, String sheetName, Map<String, String> newData) {
        String spreadsheetId = extractSpreadsheetId(spreadsheetUrl);
        if (String.isBlank(spreadsheetId)) {
            throw new AuraHandledException('Invalid Google Sheets URL');
        }

        try {
            // Get the current headers first
            List<Map<String, String>> currentData = getSheetData(spreadsheetUrl, sheetName);
            List<String> headers = new List<String>(currentData[0].keySet());
            
            // Prepare the values array
            List<Object> values = new List<Object>();
            for(String header : headers) {
                values.add(newData.containsKey(header) ? newData.get(header) : '');
            }
            
            // Construct the append request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'values' => new List<List<Object>>{ values },
                'majorDimension' => 'ROWS'
            };

            // Calculate the range
            String range = String.isNotBlank(sheetName) ? sheetName : 'Sheet1';

            // Make the API request
            String endpoint = BASE_URL + spreadsheetId + '/values/' + range + 
                            ':append?valueInputOption=RAW&insertDataOption=INSERT_ROWS';

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Error appending data: ' + 
                    response.getStatusCode() + ' ' + response.getStatus());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}

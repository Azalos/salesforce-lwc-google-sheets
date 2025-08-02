# Salesforce Lightning Web Component - Google Sheets Integration

This project implements a Lightning Web Component (LWC) that integrates with Google Sheets, allowing users to view, edit, and manage Google Sheets data directly within Salesforce.

## Features

- Display Google Sheets data in a Lightning data table
- Configurable in Lightning App Builder
- Support for public Google Sheets
- URL and sheet name configuration
- Automatic data refresh
- Error handling and user feedback

## Project Structure

```
force-app/
├── main/
    └── default/
        ├── classes/
        │   ├── GoogleSheetsController.cls         # Apex controller for Google Sheets API integration
        │   └── GoogleSheetsController.cls-meta.xml
        └── lwc/
            └── googleSheetsList/                  # Main LWC component
                ├── googleSheetsList.html          # Component template
                ├── googleSheetsList.js           # Component JavaScript
                ├── googleSheetsList.js-meta.xml  # Component configuration
                └── googleSheetsList.css          # Component styles
```

## Setup

1. Set up Google Sheets API Access (Free Tier)
   - Go to the [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project (no billing required)
   - Enable the Google Sheets API for your project:
     - Navigate to "APIs & Services" > "Library"
     - Search for "Google Sheets API"
     - Click "Enable" (free, no billing needed)
   - Create OAuth 2.0 credentials:
     - Go to "APIs & Services" > "Credentials"
     - Create OAuth consent screen:
       - Choose "External" for testing (free)
       - Add required app information
       - Add test users (your Salesforce users' email addresses)
     - Create OAuth 2.0 Client ID:
       - Select "Web application" type
       - Add authorized redirect URIs (your Salesforce domain)
     - Download the client credentials JSON file
   - Note your Client ID and Client Secret
   
   Note: You can complete all these steps without setting up billing!

2. Configure Named Credentials in Salesforce
   - Navigate to Setup > Security > Named Credentials
   - Click "New Named Credential"
   - Set the following values:
     - Label: GoogleSheets
     - Name: GoogleSheets
     - URL: https://sheets.googleapis.com
     - Identity Type: Named Principal
     - Authentication Protocol: OAuth 2.0
     - Authentication Provider: Create New
       - Type: Google
       - Consumer Key: Your Google Client ID
       - Consumer Secret: Your Google Client Secret
       - Scope: https://www.googleapis.com/auth/spreadsheets
     - Start Authentication Flow on Save: Checked
   - Save and authenticate when prompted

3. Deploy the Components
   - Deploy the Apex class and LWC to your Salesforce org
   - Ensure proper permissions are set up for the Apex class

3. Using the Component
   - Add the component to a Lightning page using Lightning App Builder
   - Configure the component settings:
     - Show/hide URL input
     - Set default Google Sheet URL
     - Set default sheet name

## Component Configuration

The component can be configured in Lightning App Builder with the following properties:

- **Show URL Input** (Boolean): Controls whether users can input their own Google Sheet URLs
- **Default Google Sheet URL** (String): The default Google Sheet URL to load
- **Default Sheet Name** (String): The default sheet name to display

## Apex Controller Methods

### GoogleSheetsController.cls

#### `getSheetData(String spreadsheetUrl, String sheetName)`
- **Parameters:**
  - `spreadsheetUrl`: The URL or ID of the Google Sheet
  - `sheetName`: Name of the specific sheet to load (optional)
- **Returns:** List<Map<String, String>> containing the sheet data
- **Description:** Fetches data from the specified Google Sheet and converts it to a format suitable for display in the Lightning data table

#### `updateSheetData(String spreadsheetUrl, String sheetName, Integer rowIndex, Map<String, String> updatedData)`
- **Parameters:**
  - `spreadsheetUrl`: The URL or ID of the Google Sheet
  - `sheetName`: Name of the specific sheet to update (optional)
  - `rowIndex`: The zero-based index of the row to update (excluding header row)
  - `updatedData`: Map of column names to new values
- **Returns:** void
- **Description:** Updates a specific row in the Google Sheet with new values

#### `appendSheetData(String spreadsheetUrl, String sheetName, Map<String, String> newData)`
- **Parameters:**
  - `spreadsheetUrl`: The URL or ID of the Google Sheet
  - `sheetName`: Name of the specific sheet to append to (optional)
  - `newData`: Map of column names to values for the new row
- **Returns:** void
- **Description:** Appends a new row to the end of the Google Sheet

## Named Credentials

The component uses a Named Credential called "GoogleSheets" for API authentication. Ensure this is properly configured in your Salesforce org with:

- Authentication Protocol: OAuth 2.0
- Scope: https://www.googleapis.com/auth/spreadsheets
- Generate Authorization Header: True

## Limitations

- Maximum range is set to A1:Z1000 by default (configurable in the controller)
- Requires Google Sheets API setup even for public sheets
- Requires proper Named Credentials configuration
- Changes are made using RAW input option (no formula support)
- API quotas and limitations apply (check Google Sheets API documentation for current limits)

## Error Handling

The component includes robust error handling for:
- Invalid Google Sheet URLs
- API access issues
- Missing or malformed data
- Network connectivity problems

## Best Practices

1. Always use Named Credentials for secure API authentication
2. Test with different Google Sheet formats and sizes
3. Consider data volume limitations when configuring the range
4. Implement proper error handling in consuming components
5. Use appropriate sharing settings for Google Sheets

## Cost Analysis

### Google Sheets API Costs
- **Free Tier (No Cost, No Billing Required)**:
  - No credit card or billing setup needed
  - 500 requests per 100 seconds per project
  - 100 requests per 100 seconds per user
  - 40,000 requests per minute per project
  - Daily quota: 60 million queries per day
  
### Free Usage Requirements
1. Create a GCP project (free)
2. Enable Google Sheets API (free)
3. Set up OAuth 2.0 credentials (free)
4. No billing account needed for these features
  
### Cost Calculations
1. **Per Read Operation**:
   - 1 API request per getSheetData call
   - Estimated cost: Free under quota

2. **Per Write Operation**:
   - updateSheetData: 1 API request
   - appendSheetData: 1 API request
   - Estimated cost: Free under quota

### Salesforce Costs
- No additional Salesforce license costs
- Standard API calls count towards your Salesforce API limits
- Storage impact: Minimal (only configuration data stored)

### Google Cloud Project Costs
- Free tier includes:
  - No cost for project hosting
  - Free OAuth 2.0 authentication
  - Basic monitoring and logging

### Cost Optimization Tips
1. Implement caching for frequently accessed data
2. Use batch operations when possible
3. Monitor API usage to stay within free tier limits
4. Set up usage alerts in Google Cloud Console

### Enterprise Considerations
For large-scale enterprise usage:
- Consider upgrading to Google Workspace Enterprise
- Monitor API quotas and adjust as needed
- Set up billing alerts and quotas
- Plan for potential scale-based costs

## Security Considerations

- Ensure Google Sheets are properly secured
- Use appropriate Salesforce permissions
- Follow OAuth best practices
- Regularly audit Named Credentials access

## Installation from GitHub

1. Clone the repository:
   ```bash
   git clone https://github.com/[your-username]/salesforce-lwc-google-sheets.git
   cd salesforce-lwc-google-sheets
   ```

2. Deploy to your Salesforce org using SFDX:
   ```bash
   # Authorize your org
   sfdx auth:web:login -a YourOrgAlias

   # Deploy the components
   sfdx force:source:deploy -p force-app/main/default
   ```

3. Follow the setup instructions above to configure Google Sheets API and Named Credentials.

## Contributing

1. Fork the repository
2. Create your feature branch:
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. Commit your changes:
   ```bash
   git commit -m 'Add some AmazingFeature'
   ```
4. Push to the branch:
   ```bash
   git push origin feature/AmazingFeature
   ```
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSheetData from '@salesforce/apex/GoogleSheetsController.getSheetData';
import updateSheetRow from '@salesforce/apex/GoogleSheetsController.updateSheetRow';
import addSheetRow from '@salesforce/apex/GoogleSheetsController.addSheetRow';
import deleteSheetRow from '@salesforce/apex/GoogleSheetsController.deleteSheetRow';

export default class GoogleSheetsList extends LightningElement {
    @api showUrlInput = true;  // Default to true for backward compatibility
    @api defaultSpreadsheetUrl = '';
    @api defaultSheetName = '';
    
    data = [];
    columns = [];
    error;
    isLoading = true;
    wiredData;
    showModal = false;
    currentRecord = {};
    isNewRecord = false;
    draftValues = [];
    
    _spreadsheetUrl = '';
    _sheetName = '';
    modifiedRows = new Set();
    
    connectedCallback() {
        // Initialize with default values if provided
        this._spreadsheetUrl = this.defaultSpreadsheetUrl || '';
        this._sheetName = this.defaultSheetName || '';
        
        // If defaults are provided and URL input is hidden, load the sheet automatically
        if (!this.showUrlInput && this._spreadsheetUrl) {
            this.handleLoadSheet();
        }
    }
    _spreadsheetUrl = '';
    _sheetName = 'Sheet1';
    _showUrlInput = false;

    // Properties from App Builder
    @api
    get spreadsheetUrl() {
        return this._spreadsheetUrl;
    }
    set spreadsheetUrl(value) {
        this._spreadsheetUrl = value;
        if (value) {
            this.handleLoadSheet();
        }
    }

    @api
    get sheetName() {
        return this._sheetName;
    }
    set sheetName(value) {
        this._sheetName = value || 'Sheet1';
    }

    @api showUrlInput = false;
    
    @wire(getSheetData, { spreadsheetUrl: '$spreadsheetUrl', sheetName: '$sheetName' })
    wiredSheetData(result) {
        this.wiredData = result;
        this.processData(result);
    }
    
    get hasUnsavedChanges() {
        return this.draftValues && this.draftValues.length > 0;
    }

    get unsavedChangeCount() {
        return this.draftValues ? this.draftValues.length : 0;
    }

    async handleSaveAll() {
        if (!this.hasUnsavedChanges) return;

        try {
            this.isLoading = true;
            const savePromises = this.draftValues.map(async (change) => {
                const rowIndex = change.rowIndex;
                const originalRow = this.data.find(row => row.rowIndex === rowIndex);
                if (!originalRow) {
                    throw new Error(`Row ${rowIndex} not found`);
                }

                // Create updated row data by merging original and changes
                const updatedRow = { ...originalRow, ...change };
                delete updatedRow.id; // Remove any temporary id

                await updateSheetRow({ 
                    rowIndex: rowIndex,
                    rowData: updatedRow 
                });
            });

            await Promise.all(savePromises);
            this.showToast('Success', 'All changes saved successfully', 'success');
            this.draftValues = []; // Clear all draft values
            await refreshApex(this.wiredData);
        } catch (error) {
            this.showToast('Error', `Error saving changes: ${error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleDiscardChanges() {
        if (!this.hasUnsavedChanges) return;

        // Show confirmation dialog
        const confirmation = confirm('Are you sure you want to discard all unsaved changes?');
        if (confirmation) {
            this.draftValues = []; // Clear all draft values
            this.showToast('Info', 'All changes discarded', 'info');
            refreshApex(this.wiredData); // Refresh to original state
        }
    }

    handleUrlChange(event) {
        this._spreadsheetUrl = event.target.value;
    }

    handleSheetNameChange(event) {
        this._sheetName = event.target.value;
    }

    handleLoadSheet() {
        if (!this._spreadsheetUrl) {
            this.showToast('Error', 'Please enter a Google Sheets URL', 'error');
            return;
        }
        
        // Clear previous data
        this.data = [];
        this.columns = [];
        this.error = undefined;
        this.draftValues = [];
        
        // The @wire service will automatically refresh with the new URL
        getSheetData({ 
            spreadsheetUrl: this._spreadsheetUrl, 
            sheetName: this._sheetName 
        })
            .then(result => {
                this.processData({ data: result, error: undefined });
            })
            .catch(error => {
                this.processData({ data: undefined, error });
            });
    }

    @wire(getSheetData)
    wiredSheetData(result) {
        this.wiredData = result;
        this.processData(result);
    }

    processData(result) {
        const { data, error } = result;
        this.isLoading = true;
        if (data) {
            // If we have data, create columns from the keys of the first row
            if (data.length > 0) {
                this.columns = [
                    ...Object.keys(data[0])
                        .filter(key => key !== 'rowIndex') // Exclude rowIndex from visible columns
                        .map(key => ({
                            label: key,
                            fieldName: key,
                            type: 'text',
                            sortable: true,
                            editable: true,
                            typeAttributes: {
                                required: false,
                                placeholder: 'Double click to edit'
                            }
                        })),
                    {
                        type: 'action',
                        typeAttributes: {
                            rowActions: [
                                { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
                                { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
                            ]
                        }
                    }
                ];
            }
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = [];
            this.columns = [];
            console.error('Error:', error);
        }
        this.isLoading = false;
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredData)
            .then(() => {
                // Show success toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Data refreshed successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                // Show error toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error refreshing data',
                        message: error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Handles sorting
    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.data];

        cloneData.sort((a, b) => {
            let valueA = a[sortedBy] || '';
            let valueB = b[sortedBy] || '';

            return sortDirection === 'asc' ? 
                valueA.localeCompare(valueB) : 
                valueB.localeCompare(valueA);
        });

        this.data = cloneData;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        switch(action.name) {
            case 'edit':
                this.editRecord(row);
                break;
            case 'delete':
                this.handleDeleteClick(row);
                break;
        }
    }

    handleDeleteClick(row) {
        // Show confirmation dialog
        const result = confirm('Are you sure you want to delete this record?');
        if (result) {
            this.deleteRecord(row);
        }
    }

    async deleteRecord(row) {
        try {
            this.isLoading = true;
            await deleteSheetRow({ rowIndex: row.rowIndex });
            this.showToast('Success', 'Record deleted successfully', 'success');
            return refreshApex(this.wiredData);
        } catch (error) {
            this.showToast('Error', error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCellChange(event) {
        // Update draft values to show visual indicators
        this.draftValues = event.detail.draftValues;
        
        // Process each changed value
        this.draftValues.forEach(async (change) => {
            try {
                this.isLoading = true;
                const rowIndex = change.rowIndex;
                
                // Find the original row
                const originalRow = this.data.find(row => row.rowIndex === rowIndex);
                if (!originalRow) {
                    throw new Error('Row not found');
                }

                // Create updated row data by merging original and changes
                const updatedRow = { ...originalRow, ...change };
                delete updatedRow.id; // Remove any temporary id from draftValues

                // Update the row in Google Sheets
                await updateSheetRow({ 
                    rowIndex: rowIndex,
                    rowData: updatedRow 
                });

                this.showToast('Success', 'Update successful', 'success');
                this.draftValues = this.draftValues.filter(draft => draft.rowIndex !== rowIndex);
                await refreshApex(this.wiredData);
            } catch (error) {
                this.showToast('Error', error.message, 'error');
            } finally {
                this.isLoading = false;
            }
        });
    }

    handleNewClick() {
        this.isNewRecord = true;
        this.currentRecord = {};
        this.showModal = true;
    }

    editRecord(row) {
        this.isNewRecord = false;
        this.currentRecord = { ...row };
        this.showModal = true;
    }

    handleModalClose() {
        this.showModal = false;
        this.currentRecord = {};
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;
        this.currentRecord = { ...this.currentRecord, [fieldName]: value };
    }

    async handleSave() {
        try {
            this.isLoading = true;
            if (this.isNewRecord) {
                await addSheetRow({ rowData: this.currentRecord });
                this.showToast('Success', 'Record added successfully', 'success');
            } else {
                await updateSheetRow({ 
                    rowIndex: this.currentRecord.rowIndex,
                    rowData: this.currentRecord 
                });
                this.showToast('Success', 'Record updated successfully', 'success');
            }
            this.handleModalClose();
            return refreshApex(this.wiredData);
        } catch (error) {
            this.showToast('Error', error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}

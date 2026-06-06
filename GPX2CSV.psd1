@{RootModule = 'GPX2CSV.psm1'
ModuleVersion = '2.0'
GUID = '9f3c2a1e-7b6d-4c8a-91d5-3e2f6a8b0c4d'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'PowerShell module to convert the basic fitness information from GPX JSON files to CSV for import into other trackers.'
PowerShellVersion = '5.1'
FunctionsToExport = @('GPX2CSV')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('GPX2CSV.psm1')

PrivateData = @{PSData = @{Tags = @('csv', 'export', 'fitness', 'import', 'json', 'powershell')
LicenseUri = 'https://github.com/Schvenn/TCX2CSV/blob/GPX2CSV/LICENSE'
ProjectUri = 'https://github.com/Schvenn/TCX2CSV/tree/GPX2CSV'
ReleaseNotes = 'Switched to converting GPX files, instead of TCX.'}

weight = 94}}

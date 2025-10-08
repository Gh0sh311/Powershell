# Security Analysis & Hardening

## Security Improvements Implemented

This document outlines the security measures implemented in the File Type Detector GUI application.

## 🔒 JSON Signature Validation

### Threat: Malicious JSON Input
**Risk**: Untrusted JSON files could contain malicious content designed to exploit the application.

### Protections Implemented:

#### 1. **File Size Limits**
- Maximum JSON file size: **10 MB**
- Prevents memory exhaustion attacks
- Blocks attempts to load extremely large files

```powershell
if ($fileInfo.Length -gt 10MB) {
    # Reject file
}
```

#### 2. **Signature Count Limits**
- Maximum signatures: **1,000**
- Prevents DoS through excessive signature processing

#### 3. **Offset Validation**
- Maximum offset: **1 MB (1,048,576 bytes)**
- Prevents attempts to read beyond reasonable file headers
- Blocks integer overflow attacks

#### 4. **Signature Length Limits**
- Maximum signature length: **1 KB (1,024 bytes)**
- Prevents memory issues from extremely long signatures

#### 5. **Name Field Validation**
- Maximum length: **200 characters**
- Character whitelist: Alphanumeric and basic punctuation only
- **Blocked characters**: `;`, `$`, `{`, `}`, `(`, `)`, `[`, `]`, `|`, `&`, `<`, `>`
- Prevents code injection in display names

#### 6. **Hex Signature Validation**
- **Format check**: Must contain only `0-9`, `A-F`, `a-f`
- **Length check**: Must be even number of characters (byte pairs)
- Prevents malformed hex strings

#### 7. **ASCII Signature Validation**
- **Script detection**: Blocks PowerShell-like patterns:
  - Variables: `$variableName`
  - Commands: `Invoke-`, `iex`
  - Operators: Backticks, pipes, semicolons
- Prevents embedded script execution

#### 8. **Property Whitelisting**
- Only allowed properties: `name`, `sigHex`, `sigAscii`, `offset`
- Unexpected properties flagged as suspicious
- Prevents JSON with hidden executable content

#### 9. **Required Field Validation**
- Each signature must have: `name`, `offset`, and either `sigHex` or `sigAscii`
- Malformed entries are rejected

### Example Validation Output:
```
Successfully loaded and validated 50 file signatures.
Valid signatures: 50
```

---

## 📂 File Scanning Security

### Threat: Scanning Sensitive System Files
**Risk**: Accidental scanning of system directories could expose sensitive data or cause performance issues.

### Protections Implemented:

#### 1. **Protected Path Warning**
The following system paths trigger a warning (but allow override):

- `C:\Windows`
- `C:\Windows\System32`
- `C:\Program Files`
- `C:\Program Files (x86)`
- `C:\ProgramData\Microsoft`
- `%USERPROFILE%\AppData\Local\Microsoft`

```powershell
function Test-PathSafe {
    # Checks if path is in protected system directories
    # Returns warning that user must acknowledge
}
```

#### 2. **File Size Limits**
- **Zero-byte files**: Skipped automatically
- **Large files**: Files > 100 MB are skipped
- **Read buffer cap**: Maximum read size capped at 10 MB

#### 3. **Read-Only Access**
- Files opened with `Read` access only
- `FileShare.ReadWrite` allows non-exclusive access
- Never modifies or locks files

#### 4. **Error Resilience**
- Individual file failures don't crash the scan
- Errors logged but scan continues
- Proper exception handling on all file operations

---

## 🔐 Export Security

### Threat: Path Injection in Export Files
**Risk**: Malicious filenames could cause issues during export.

### Protections Implemented:

#### 1. **Safe File Dialog**
- Uses Windows SaveFileDialog
- Automatic file extension validation
- User must explicitly choose save location

#### 2. **Data Sanitization**
- File paths displayed as-is (read-only)
- Base64 prefixes are encoded, not raw bytes
- No user-supplied data executed

---

## 🛡️ Memory & Resource Protection

### 1. **Buffer Size Limits**
```powershell
$script:readSize = [Math]::Max(64, $maxNeeded)

# Cap at 10 MB regardless of signature offsets
if ($script:readSize -gt 10MB) {
    $script:readSize = 10MB
}
```

### 2. **Proper Resource Disposal**
```powershell
try {
    $fs = [System.IO.File]::Open(...)
    # Read file
}
finally {
    $fs.Close()
    $fs.Dispose()
}
```

### 3. **Scan Cancellation**
- User can stop long-running scans
- Prevents indefinite resource consumption
- Cleanup on abort

---

## ⚠️ Known Limitations

### 1. **Base64 Prefix Exposure**
- **Risk**: Base64 prefixes displayed in GUI and exports
- **Impact**: Could leak partial file content
- **Mitigation**: User discretion when exporting results
- **Future**: Consider redacting prefixes for sensitive file types

### 2. **Signature Database Trust**
- **Risk**: Application trusts loaded signatures are legitimate
- **Impact**: Malicious signatures could misidentify files
- **Mitigation**: Comprehensive validation (see above)
- **Recommendation**: Only load signatures from trusted sources

### 3. **System Path Scanning**
- **Risk**: Users can override system path warnings
- **Impact**: Could scan sensitive directories
- **Mitigation**: Clear warning dialog with explicit consent
- **Recommendation**: Administrators should educate users

---

## ✅ Security Checklist

| Security Control | Status | Implementation |
|-----------------|--------|----------------|
| JSON file size validation | ✅ | Max 10 MB |
| Signature count limits | ✅ | Max 1,000 signatures |
| Offset range validation | ✅ | 0 to 1 MB |
| Signature length limits | ✅ | Max 1 KB |
| Character whitelisting | ✅ | Name field sanitized |
| Hex format validation | ✅ | Regex pattern match |
| ASCII script detection | ✅ | PowerShell pattern blocking |
| Property whitelisting | ✅ | Only allowed properties |
| Required field validation | ✅ | name, offset, sig* required |
| File size limits | ✅ | 0 bytes - 100 MB |
| Read buffer cap | ✅ | Max 10 MB |
| Path traversal protection | ✅ | System path warnings |
| Read-only file access | ✅ | No file modifications |
| Resource cleanup | ✅ | Proper disposal in finally blocks |
| Error handling | ✅ | Try-catch on all file ops |
| Export sanitization | ✅ | Safe file dialog |

---

## 🔍 Validation Examples

### Valid Signature (Accepted):
```json
{
  "name": "PDF Document",
  "sigHex": "25504446",
  "offset": 0
}
```

### Invalid Signatures (Rejected):

#### Example 1: Suspicious Characters in Name
```json
{
  "name": "PDF;Invoke-Expression",  ← REJECTED: Contains ;
  "sigHex": "25504446",
  "offset": 0
}
```

#### Example 2: Script-like ASCII Signature
```json
{
  "name": "Malicious",
  "sigAscii": "Invoke-WebRequest",  ← REJECTED: PowerShell command
  "offset": 0
}
```

#### Example 3: Invalid Hex Format
```json
{
  "name": "Invalid",
  "sigHex": "ZZZZZZ",  ← REJECTED: Not valid hex
  "offset": 0
}
```

#### Example 4: Offset Too Large
```json
{
  "name": "ISO",
  "sigHex": "4344303031",
  "offset": 99999999  ← REJECTED: Exceeds 1 MB limit
}
```

#### Example 5: Unexpected Properties
```json
{
  "name": "Suspicious",
  "sigHex": "25504446",
  "offset": 0,
  "executeCode": "Invoke-Something"  ← REJECTED: Unknown property
}
```

---

## 📋 Security Recommendations for Users

### 1. **Signature Files**
- ✅ Only load signature JSON from trusted sources
- ✅ Review signature file contents before loading
- ✅ Keep signature database in a protected directory
- ❌ Never load signatures from untrusted websites or emails

### 2. **Scanning Paths**
- ✅ Scan user directories and downloads
- ✅ Scan specific project folders
- ⚠️ Exercise caution when scanning system directories
- ❌ Avoid scanning Windows, Program Files unless necessary

### 3. **Export Files**
- ✅ Store exports in secure locations
- ✅ Protect CSV/JSON exports (may contain path information)
- ⚠️ Base64 prefixes might reveal file content
- ❌ Don't share exports containing sensitive file paths

### 4. **Large Scans**
- ✅ Use specific directories rather than entire drives
- ✅ Monitor scan progress and cancel if needed
- ⚠️ Large recursive scans may take significant time
- ❌ Avoid scanning network drives over slow connections

---

## 🔬 Testing Validation

To test the security validation, try loading these malicious JSON samples:

### Test 1: Malicious Name
```json
[{"name": "Test;$env:TEMP", "sigHex": "ABCD", "offset": 0}]
```
**Expected**: Rejected - suspicious characters

### Test 2: PowerShell in ASCII
```json
[{"name": "Test", "sigAscii": "Invoke-Evil", "offset": 0}]
```
**Expected**: Rejected - script-like content

### Test 3: Invalid Hex
```json
[{"name": "Test", "sigHex": "GHIJKL", "offset": 0}]
```
**Expected**: Rejected - invalid hex characters

### Test 4: Excessive Offset
```json
[{"name": "Test", "sigHex": "ABCD", "offset": 9999999}]
```
**Expected**: Rejected - offset exceeds 1 MB

All of these should be **blocked** with appropriate error messages.

---

## 📝 Version History

### Version 2.1 (Current) - Security Hardened
- Added comprehensive JSON validation
- Implemented file size limits
- Added system path protection
- Enhanced error handling
- Resource cleanup improvements

### Version 2.0
- Initial GUI release
- Basic validation
- File scanning functionality

---

## 📞 Security Contact

If you discover a security vulnerability in this application, please:

1. **DO NOT** create a public GitHub issue
2. Review the code and verify the vulnerability
3. Document the issue with clear reproduction steps
4. Contact the developer directly

---

**Last Updated**: 2025-10-08
**Security Review**: Version 2.1
**Status**: Production Ready with Security Hardening

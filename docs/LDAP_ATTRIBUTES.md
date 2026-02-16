# Common LDAP/Active Directory Attributes

This document lists common attributes available in LDAP/Active Directory that the Flask app will retrieve.

## Standard User Identity Attributes

- `sAMAccountName` - Windows username (login name)
- `userPrincipalName` - User principal name (email-like format: user@domain.com)
- `displayName` - Full display name
- `givenName` - First name
- `sn` - Surname/last name
- `cn` - Common name
- `initials` - User's initials
- `name` - Full name

## Contact Information

- `mail` - Primary email address
- `proxyAddresses` - All email addresses (SMTP aliases)
- `telephoneNumber` - Primary phone number
- `mobile` - Mobile phone number
- `homePhone` - Home phone number
- `pager` - Pager number
- `facsimileTelephoneNumber` - Fax number
- `ipPhone` - IP phone number

## Job/Organization Information

- `title` - Job title
- `department` - Department name
- `company` - Company name
- `employeeID` - Employee ID number
- `employeeNumber` - Employee number
- `employeeType` - Employee type (full-time, contractor, etc.)
- `division` - Division name
- `manager` - Manager's distinguished name (DN)
- `directReports` - List of direct reports (DNs)

## Location Information

- `physicalDeliveryOfficeName` - Office location/building
- `streetAddress` - Street address
- `postOfficeBox` - PO Box
- `l` - City/locality
- `st` - State/province
- `postalCode` - Postal/ZIP code
- `c` - Country code (2-letter)
- `co` - Country name (full)
- `countryCode` - Country code (numeric)

## Group Membership

- `memberOf` - List of groups the user belongs to (DNs)
- `primaryGroupID` - Primary group ID

## Account Information

- `objectGUID` - Globally unique identifier
- `objectSid` - Security identifier (SID)
- `userAccountControl` - Account control flags (enabled/disabled, password settings, etc.)
- `accountExpires` - Account expiration date
- `lockoutTime` - Account lockout timestamp
- `badPwdCount` - Number of failed login attempts
- `badPasswordTime` - Last bad password attempt timestamp

## Timestamps

- `whenCreated` - When the account was created
- `whenChanged` - When the account was last modified
- `lastLogon` - Last logon time (not replicated)
- `lastLogonTimestamp` - Last logon timestamp (replicated across DCs)
- `pwdLastSet` - When password was last set
- `lastLogoff` - Last logoff time

## Password & Security

- `pwdLastSet` - Password last set time
- `msDS-UserPasswordExpiryTimeComputed` - Computed password expiration time
- `userPassword` - Password (usually not readable)
- `unicodePwd` - Unicode password (usually not readable)

## Custom Extension Attributes

- `extensionAttribute1` through `extensionAttribute15` - Custom attributes for organization-specific data
- `info` - Additional information field
- `comment` - Comments field
- `description` - Description field

## Micron-Specific Attributes (Examples)

- `MTgroup` - Micron group assignment (custom attribute)
- Other custom attributes specific to Micron's Active Directory schema

## Distinguished Name & Path

- `distinguishedName` - Full LDAP path (DN)
- `canonicalName` - Canonical name format

## Object Information

- `objectClass` - Object class types
- `objectCategory` - Object category
- `instanceType` - Instance type

## Operational Attributes (Hidden by default)

These are retrieved when `get_operational_attributes=True`:

- `createTimeStamp` - Creation timestamp
- `modifyTimeStamp` - Last modification timestamp
- `uSNCreated` - Update sequence number at creation
- `uSNChanged` - Update sequence number at last change
- `dSCorePropagationData` - Replication metadata

## Notes

- The Flask app is configured to retrieve **ALL** attributes automatically using `ldap3.ALL_ATTRIBUTES`
- Operational/hidden attributes are also retrieved with `get_operational_attributes=True`
- Not all attributes will have values for every user
- Custom attributes (like `MTgroup`) depend on your organization's Active Directory schema
- Some sensitive attributes (like passwords) are not readable even with proper permissions

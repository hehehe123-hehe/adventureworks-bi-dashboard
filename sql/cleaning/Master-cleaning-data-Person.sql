USE AdventureWorks2025;
GO

/* VIEW NAME: Person.vCleanPerson
DESCRIPTION: Consolidates person identity, contact details, and address information.
             Handles NULL values, standardizes casing, and joins multiple schemas.
AUTHOR: Ruki
*/

CREATE OR ALTER VIEW Person.vCleanPerson AS
SELECT 
    p.BusinessEntityID, 
    p.PersonType,

    -- 1. Identity Name Section
    -- Standardizes titles and handles suffixes, creates a unified full name string.
    ISNULL(p.Title, 'N/A') AS Title,
    CONCAT_WS(' ', p.FirstName, p.MiddleName, p.LastName) AS FullName,
    ISNULL(p.Suffix, '') AS Suffix,

    -- 2. Contact Details Section
    -- Cleans email addresses (lowercase/trimmed) and retrieves phone types.
    LOWER(TRIM(e.EmailAddress)) AS CleanEmail,
    ph.PhoneNumber,
    pnt.Name AS PhoneType,

    -- 3. Address Information Section
    -- Joins geographic data to provide a complete location profile.
    TRIM(a.AddressLine1) AS MainAddress,
    ISNULL(TRIM(a.AddressLine2), '-') AS SecondaryAddress,
    a.City,
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    a.PostalCode,
    at.Name AS AddressType,

    -- 4. Marketing Preferences
    -- Converts numeric flags into human-readable descriptions.
    CASE p.EmailPromotion
        WHEN 0 THEN 'No Promotion'
        WHEN 1 THEN 'Internal Only'
        WHEN 2 THEN 'All Promotions'
    END AS MarketingPreference,

    p.ModifiedDate
	
FROM Person.Person p
-- Join for Email Contact
LEFT JOIN Person.EmailAddress e ON p.BusinessEntityID = e.BusinessEntityID
-- Join for Phone Contact
LEFT JOIN Person.PersonPhone ph ON p.BusinessEntityID = ph.BusinessEntityID
LEFT JOIN Person.PhoneNumberType pnt ON ph.PhoneNumberTypeID = pnt.PhoneNumberTypeID

-- Join for Address (Bridge via BusinessEntityAddress)
-- FIXED: Joined on BusinessEntityID instead of ModifiedDate
LEFT JOIN Person.BusinessEntityAddress bea ON p.BusinessEntityID = bea.BusinessEntityID
LEFT JOIN Person.Address a ON bea.AddressID = a.AddressID
LEFT JOIN Person.AddressType at ON bea.AddressTypeID = at.AddressTypeID
LEFT JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
LEFT JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode;
GO

-- Validation Query:
SELECT TOP 10 * FROM Person.vCleanPerson;

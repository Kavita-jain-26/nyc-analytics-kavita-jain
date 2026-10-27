-- Clean and standardize DOB NOW Job Filings data
-- One row per job filing
WITH source AS (
    SELECT * FROM {{ source('raw', 'job_applications_filing_requests_homework') }}
),

cleaned AS (
    SELECT
        -- Keep all other columns except the ones we are explicitly cleaning/casting below
        * EXCEPT (
            job_filing_number,
            filing_date,
            current_status_date,
            zip,
            borough,
            filing_representative_first_name,
            filing_representative_middle_initial,
            filing_representative_last_name,
            filing_representative_business_name,
            filing_representative_street_name,
            filing_representative_city,
            filing_representative_state,
            filing_representative_zip
        ),
        
        -- Identifiers 
        CAST(job_filing_number AS STRING) AS request_id,
        
        -- Date/Time casting (casting through TIMESTAMP first to handle time components safely)
        CAST(CAST(filing_date AS TIMESTAMP) AS DATE) AS created_date,
        CAST(CAST(current_status_date AS TIMESTAMP) AS DATE) AS closed_date,
        
        -- Status (defaulting to UNKNOWN if not in raw table)
        CAST('UNKNOWN' AS STRING) AS status,
        
        -- Location - clean zip code
        CASE 
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', 'ANONYMOUS') THEN NULL
            WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 9 THEN CAST(zip AS STRING)
            ELSE NULL
        END AS incident_zip,
        
        -- Location - standardized borough to match 311 staging conventions
        CASE 
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Filing Representative details
        CAST(filing_representative_first_name AS STRING) AS filing_representative_first_name,
        CAST(filing_representative_middle_initial AS STRING) AS filing_representative_middle_initial,
        CAST(filing_representative_last_name AS STRING) AS filing_representative_last_name,
        CAST(filing_representative_business_name AS STRING) AS filing_representative_business_name,
        CAST(filing_representative_street_name AS STRING) AS filing_representative_street_name,
        CAST(filing_representative_city AS STRING) AS filing_representative_city,
        CAST(filing_representative_state AS STRING) AS filing_representative_state,
        CAST(filing_representative_zip AS STRING) AS filing_representative_zip,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source
    
    -- Filters to keep data clean and manageable
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL
      
    -- Deduplication to ensure unique job filing numbers
    QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned
WITH cte AS (
    SELECT
        acc,
        collection_date_sam,
        element_at(
            map_agg(attr.k, attr.v) FILTER (WHERE attr.k = 'collection_date_sam'),
            'collection_date_sam'
        ) AS raw_collection_date,
        assay_type,
        center_name,
        consent,
        experiment,
        sample_name,
        instrument,
        librarylayout,
        libraryselection,
        librarysource,
        platform,
        sample_acc,
        biosample,
        organism,
        sra_study,
        releasedate,
        bioproject,
        mbytes,
        loaddate,
        avgspotlen,
        mbases,
        insertsize,
        library_name,
        biosamplemodel_sam,
        geo_loc_name_country_calc,
        geo_loc_name_country_continent_calc,
        geo_loc_name_sam,
        ena_first_public_run,
        ena_last_update_run,
        sample_name_sam,
        datastore_filetype,
        datastore_provider,
        datastore_region
    FROM sra.metadata,
        UNNEST(attributes) AS t(attr)
    GROUP BY
        acc,
        assay_type,
        center_name,
        consent,
        experiment,
        sample_name,
        instrument,
        librarylayout,
        libraryselection,
        librarysource,
        platform,
        sample_acc,
        biosample,
        organism,
        sra_study,
        releasedate,
        bioproject,
        mbytes,
        loaddate,
        avgspotlen,
        mbases,
        insertsize,
        library_name,
        biosamplemodel_sam,
        collection_date_sam,
        geo_loc_name_country_calc,
        geo_loc_name_country_continent_calc,
        geo_loc_name_sam,
        ena_first_public_run,
        ena_last_update_run,
        sample_name_sam,
        datastore_filetype,
        datastore_provider,
        datastore_region
)
SELECT *
FROM cte
WHERE lower(organism) LIKE '%mycobacterium tuberculosis%'
  AND platform = 'ILLUMINA'
  AND assay_type IN ('WGS', 'WGA')
  AND librarysource = 'GENOMIC'
  AND libraryselection IN ('RANDOM', 'RANDOM PCR', 'size fractionation', 'unspecified')
  AND mbases > 180
  AND geo_loc_name_country_calc NOT IN ('', 'Uncalculated')
  AND raw_collection_date NOT IN ('', 'missing', 'Missing', 'NA', '-', '9999')
  AND lower(raw_collection_date) NOT LIKE '%not%'

INSTALL httpfs;
LOAD httpfs;
INSTALL parquet;
LOAD parquet;

CREATE OR REPLACE TEMPORARY SECRET sra_public (
  TYPE s3,
  PROVIDER config,
  REGION 'us-east-1',
  ENDPOINT 's3.amazonaws.com',
  SCOPE 's3://sra-pub-metadata-us-east-1/'
);

SET s3_region='us-east-1';
SET s3_endpoint='s3.amazonaws.com';
SET s3_access_key_id='';
SET s3_secret_access_key='';
SET s3_session_token='';

COPY (
  SELECT
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
      geo_loc_name_country_calc,
      geo_loc_name_country_continent_calc,
      geo_loc_name_sam,
      ena_first_public_run,
      ena_last_update_run,
      sample_name_sam,
      datastore_filetype,
      datastore_provider,
      datastore_region,
      collection_date_sam,
      list_extract(
          list_filter(attributes, x -> x.k = 'collection_date_sam'),
          1
      ).v AS raw_collection_date
  FROM read_parquet('s3://sra-pub-metadata-us-east-1/sra/metadata/*')
  WHERE
      lower(organism) LIKE '%mycobacterium tuberculosis%'
      AND platform = 'ILLUMINA'
      AND assay_type IN ('WGS', 'WGA')
      AND librarysource = 'GENOMIC'
      AND mbases > 180
      AND libraryselection IN ('RANDOM', 'RANDOM PCR', 'size fractionation', 'unspecified')
      AND geo_loc_name_country_calc IS NOT NULL
      AND geo_loc_name_country_calc != ''
      AND geo_loc_name_country_calc != 'uncalculated'
) TO 'data/metadata_raw.tsv'
  WITH (HEADER TRUE, DELIMITER '\t');

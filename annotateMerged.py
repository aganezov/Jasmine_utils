import argparse

from cyvcf2 import cyvcf2

from utils import read_variants, is_specific_via_origin, get_supp_vector, get_supp_mvector


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file-list", type=argparse.FileType("rt"), required=True)
    parser.add_argument("-m", "--merged-vcf", type=str, required=True)
    parser.add_argument("--merged-ids-field", type=str, required=True)
    parser.add_argument("-o", "--output", type=str, required=True)
    args = parser.parse_args()
    samples = []
    variants_by_sample = {}
    for line in args.file_list:
        line = line.strip()
        sample_name, variants = read_variants(line)
        samples.append(sample_name)
        variants_by_sample[sample_name] = variants
    reader = cyvcf2.VCF(args.merged_vcf)
    reader.add_info_to_header({
        "ID": "SUPP_VEC",
        "Description": "Support vector",
        "Type": "String",
        "Number": "1",
    })
    reader.add_info_to_header({
        "ID": "SUPP_MVEC",
        "Description": "Support multiplicity vector",
        "Type": "String",
        "Number": "1",
    })
    reader.add_info_to_header({
        "ID": "IS_SPECIFIC",
        "Description": "Whether or not a variant has enough read support and length to be specific",
        "Type": "String",
        "Number": "1",
    })
    writer = cyvcf2.Writer(args.output, reader)
    for record in reader:
        is_specific = str(int(is_specific_via_origin(record, variants_by_sample, args.merged_ids_field)))
        supp_mvec = get_supp_mvector(record, samples, args.merged_ids_field)
        record.INFO["SUPP_MVEC"] = supp_mvec
        record.INFO["IS_SPECIFIC"] = is_specific
        record.INFO["SUPP_VEC"] = get_supp_vector(supp_mvec)
        writer.write_record(record)
    reader.close()
    writer.close()

if __name__ == "__main__":
    main()

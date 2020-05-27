import argparse
import sys
from collections import defaultdict

import cyvcf2 as cyvcf2


class Sample(object):
    __slots__ = ('idx', 'specific')

    def __init__(self, idx: str, specific: bool):
        self.idx = idx
        self.specific = specific


def read_variants(source_path):
    result = {}
    reader = cyvcf2.VCF(source_path)
    sample_name = reader.samples[0]
    for variant in reader:
        sample = Sample(variant.ID, bool(int(variant.INFO.get("IS_SPECIFIC", variant.INFO.get("IN_SPECIFIC", "0")))))
        result[sample.idx] = sample
    reader.close()
    return sample_name, result


def get_supp_mvector(record, samples):
    result = defaultdict(int)
    for entry in record.INFO["SNAME"].split(","):
        sample, idx = entry.split(":")
        result[sample] += 1
    return "".join([str(result[sample]) for sample in samples])


def get_supp_vector(supp_mvec):
    return "".join(["1" if int(value) > 0 else "0" for value in supp_mvec])


def is_specific_via_origin(record, variants_by_sample):
    for entry in record.INFO["SNAME"].split(","):
        sample, idx = entry.split(":")
        if variants_by_sample[sample][idx].specific:
            return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file-list", type=argparse.FileType("rt"), required=True)
    parser.add_argument("-m", "--merged-vcf", type=str, required=True)
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
        is_specific = str(int(is_specific_via_origin(record, variants_by_sample)))
        supp_mvec = get_supp_mvector(record, samples)
        record.INFO["SUPP_MVEC"] = supp_mvec
        record.INFO["IS_SPECIFIC"] = is_specific
        record.INFO["SUPP_VEC"] = get_supp_vector(supp_mvec)
        writer.write_record(record)
    reader.close()
    writer.close()


if __name__ == "__main__":
    main()

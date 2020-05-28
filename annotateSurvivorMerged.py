import argparse

from cyvcf2 import cyvcf2


class Sample(object):
    __slots__ = ('idx', 'chr1', 'coord1', 'chr2', 'coord2', 'strands', 'is_specific')

    def __init__(self, idx, chr1, coord1, chr2, coord2, strands, is_specific):
        self.idx = idx
        self.chr1 = chr1
        self.coord1 = coord1
        self.chr2 = chr2
        self.coord2 = coord2
        self.strands = strands
        self.is_specific = is_specific


def read_variants(source):
    reader = cyvcf2.VCF(source)
    sample_name = reader.samples[0]
    result = {}
    for variant in reader:
        chr1 = variant.CHROM
        coord1 = int(variant.POS)
        if variant.INFO["SVTYPE"] == "TRA":
            alt_str = variant.ALT[0]
            if "[" in alt_str:
                data = alt_str.split("[")[1].split(":")
            else:
                data = alt_str.split("]")[1].split(":")
            chr2 = data[0]
            coord2 = int(data[1])
        else:
            chr2 = variant.INFO["CHR2"]
            coord2 = int(variant.INFO["END"])
        strands = variant.INFO["STRANDS"]
        is_specific = bool(int(variant.INFO.get("IS_SPECIFIC", variant.INFO.get("IN_SPECIFIC", "0"))))
        result[(chr1, coord1, chr2, coord2)] = Sample(variant.ID, chr1, coord1, chr2, coord2, strands, is_specific)
    return sample_name, result


def get_supp_mvector(record):
    result = []
    for entry in record.format("CO"):
        if entry.lower() == "nan":
            result.append(0)
        else:
            result.append(len(entry.split(",")))
    return "".join([str(entry) for entry in result])


def is_specific_via_origin(record, variants_by_sample, samples):
    for origin_entry, sample in zip(record.format("CO"), samples):
        if origin_entry.lower() == "nan":
            continue
        origin_entries = origin_entry.split(",")
        for origin in origin_entries:
            data1, data2 = origin.split("-")
            chr1, coord1 = data1.split("_")
            chr2, coord2 = data2.split("_")
            coord1, coord2 = int(coord1), int(coord2)
            original_variant = variants_by_sample[sample][(chr1, coord1, chr2, coord2)]
            if original_variant.is_specific:
                return True
    return False


def original_ids(record, variants_by_sample, samples):
    result = []
    for origin_entry, sample in zip(record.format("CO"), samples):
        if origin_entry.lower() == "nan":
            continue
        origin_entries = origin_entry.split(",")
        for origin in origin_entries:
            data1, data2 = origin.split("-")
            chr1, coord1 = data1.split("_")
            chr2, coord2 = data2.split("_")
            coord1, coord2 = int(coord1), int(coord2)
            original_variant = variants_by_sample[sample][(chr1, coord1, chr2, coord2)]
            result.append(f"{sample}:{original_variant.idx}")
    return result


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
    reader.add_info_to_header({
        "ID": "MERGED_IDS",
        "Description": "':'-separated sample:id values for the merged variants",
        "Type": "String",
        "Number": ".",
    })
    writer = cyvcf2.Writer(args.output, reader)
    for record in reader:
        is_specific = str(int(is_specific_via_origin(record, variants_by_sample, samples)))
        supp_mvec = get_supp_mvector(record)
        origin_ids = original_ids(record, variants_by_sample, samples)
        record.INFO["SUPP_MVEC"] = supp_mvec
        record.INFO["IS_SPECIFIC"] = is_specific
        record.INFO["MERGED_IDS"] = ",".join(origin_ids)
        writer.write_record(record)
    reader.close()
    writer.close()


if __name__ == "__main__":
    main()

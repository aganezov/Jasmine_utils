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


def get_supp_vector(supp_mvec):
    return "".join(["1" if int(value) > 0 else "0" for value in supp_mvec])


def is_specific_via_origin(record, variants_by_sample, merged_field, split_id=True):
    for entry in record.INFO[merged_field].split(","):
        sample, idx = entry.split(":")
        if not split_id:
            idx = entry
        if variants_by_sample[sample][idx].specific:
            return True
    return False


def get_supp_mvector(record, samples, merged_field):
    result = defaultdict(int)
    for entry in record.INFO[merged_field].split(","):
        sample, idx = entry.split(":")
        result[sample] += 1
    return "".join([str(result[sample]) for sample in samples])

import argparse

from cyvcf2 import cyvcf2


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("vcf", type=str)
    parser.add_argument("-o", "--output", type=str, required=True)
    args = parser.parse_args()
    reader = cyvcf2.VCF(args.vcf)
    writer = cyvcf2.Writer(args.output, reader)
    records = []
    sample_name = reader.samples[0]
    for record in reader:
        if int(record.INFO.get("END", record.POS)) < int(record.POS):
            record.INFO["END"] = int(str(record.POS))
        record.ID = f"{sample_name}:{record.ID}"
        records.append(record)
    reader.close()
    records = sorted(records, key=lambda r: (r.CHROM, r.POS))
    for record in records:
        writer.write_record(record)
    writer.close()


if __name__ == "__main__":
    main()

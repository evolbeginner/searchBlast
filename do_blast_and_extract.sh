#! /bin/env bash


#####################################################################
indir=''
cpu=10
SB=~/project/Rhizobiales/scripts/searchBlast/searchInBatch.rb
EC=~/project/Rhizobiales/scripts/extractCOG.rb


#####################################################################
while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indir=$2
			shift
			;;
		--cpu)
			cpu=$2
			shift
			;;
		--type)
			type=$2
			shift
			;;
	esac
	shift
done


#####################################################################
if [ -z $type ]; then
	echo "type has to be given! Exiting ......" >&2
	exit 1
fi


case $type in
	euk)
		dbs=(mito-euk nucl-euk29)
		;;
	bac)
		dbs=(mito-bac mito-bac29)
		;;
	*)
		echo "type \"$type\" is invalid!" >&2
		exit 1
		;;
esac



#####################################################################
for i in nucl-euk29 mito-euk; do
	echo $i
	ruby $SB --indir $indir --force --cpu 10 --db $i --outdir blast/$i
done


for i in mito-euk nucl-euk29; do
	ruby $EC --blast_dir blast/$i --cpu 10 --seq_dir $indir --min_gene_no 1 --outdir pep/$i --fam_list ~/resource/db/$i/fam.list --evalue 1e-10 --force --noDupli --same_fam
done



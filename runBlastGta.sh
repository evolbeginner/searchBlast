#! /bin/bash


###############################################################################
indir=''
query_indir=''
outdir=''


###############################################################################
while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indir=$2
			shift
			;;
		--query_indir)
			query_indir=$2
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
	esac
	shift
done


###############################################################################
if [ ! -d "$indir" ]; then
	echo "indir has not been provided! Exiting ......" >&2
	exit 1
elif [ ! -d "$query_indir" ]; then
	echo "query_indir has not been provided! Exiting ......" >&2
	exit 1
elif [ -z "$outdir" ]; then
	echo "outdir has not been provided! Exiting ......" >&2
	exit 1
fi


###############################################################################
for i in $indir/*; do
	b=`basename $i`; c=${b%%.protein};
	mkdir -p $outdir/$c;
	for j in $query_indir/*;
		do b2=`basename $j`
		c2=${b2%.fa}
		blastp -query $j -subject $i -out $outdir/$c/$c2.blast8 -evalue 1e-3 -outfmt 6 #-word_size 4
	done
done



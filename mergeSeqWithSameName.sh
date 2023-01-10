#! /bin/bash


###############################################
# after combineSeqs.rb


###############################################
indirs=()
outdir=''
is_force=0


###############################################
if [ $# -eq 0 ]; then
	echo "usage: after combineSeqs.rb"; exit
fi

while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indirs=(${indirs[@]} $2)
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--force)
			is_force=1
			;;
	esac
	shift
done


###############################################
if [ $is_force -eq 1 ]; then
	[ -d $outdir ] && rm -rf $outdir
fi
mkdir -p $outdir


###############################################
for indir in ${indirs[@]}; do
	for sub_indir in $indir/*; do
		#echo $sub_indir
		#[ "(ls -A $sub_indir)" ] && continue
		for i in $sub_indir/*; do
			b=`basename $i`
			cat $i >> $outdir/$b
		done
	done
done



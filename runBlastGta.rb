#! /usr/bin/env ruby


###############################################################################
require 'getoptlong'
require 'parallel'

require 'util'
require 'Dir'
require 'processbar'


###############################################################################
indir = nil
query_indir = nil
evalue = 1e-3
prog = 'blastp'
outdir = nil
is_force = false
cpu = 1

infiles = Array.new


###############################################################################
opts = GetoptLong.new(
  ['--indir', '--protein_indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--query_indir', GetoptLong::REQUIRED_ARGUMENT],
  ['-e', '--evalue', GetoptLong::REQUIRED_ARGUMENT],
  ['--prog', '--type', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--indir', '--protein_indir'
      indir = value
    when '--query_indir'
      query_indir = value
    when '-e', '--evalue'
      evalue = value.to_f
    when '--prog', '--type'
      prog = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
    when '--cpu'
      cpu = value.to_i
  end
end


###############################################################################
mkdir_with_force(outdir, is_force)

infiles = read_infiles(indir)

query_infiles = read_infiles(query_indir)


###############################################################################
count = Thread.new{
  while true;
    count = `ls -1 #{outdir} | wc -l`.chomp.to_i
    processbar(count, infiles.size)
    sleep 2
  end
} 


Parallel.map(infiles, in_threads: cpu) do |infile|
	b = File.basename(infile)
  c = getCorename(infile)
  #puts c
  outdir2 = File.join(outdir, c)
  mkdir_with_force(outdir2, is_force)
  query_infiles.each do |query_infile|
    c2 = getCorename(query_infile)
    outfile = File.join(outdir2, c2+'.blast8')
    `#{prog} -query #{query_infile} -subject #{infile} -out #{outfile} -evalue #{evalue} -outfmt 6`
  end
end



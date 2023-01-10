#! /usr/bin/env ruby


######################################################
# Author: Sishuo Wang from Haiwei Luo Lab at Chinese University of Hong Kong
# E-mail: sishuowang@hotmail.ca sishuowang@cuhk.edu.hk
# Last updated: 2019-08-05
# Copyright: CC 4.0 (https://creativecommons.org/licenses/by/4.0/)
# To see the usage, run 'ruby searchInBatch.rb'


######################################################
dir = File.dirname($0)
$:.unshift << File.join(dir, 'lib')


######################################################
require 'getoptlong'
require 'parallel'

require 'chang_yong'
require 'Dir'
require 'util'
require 'seqIO'
require 'processbar'


######################################################
$hmmsearch = "/home-user/software/hmmer-search/v3.1b2/hmmer-3.1b2-linux-intel-x86_64/binaries/hmmsearch"
$hmmscan = "/home-user/software/hmmer-search/v3.1b2/hmmer-3.1b2-linux-intel-x86_64/binaries/hmmscan"
$pfam_hmm = "/home-db/db_from_SZcluster/Pfam/v30.0/Pfam-A.hmm"

$cog_db = "/home-db//pub/protein_db/COG/huang.formatted/COG"

$cdd_db = "/mnt/home-db/pub/protein_db/CDD/Cdd"

#$kegg_db = File.expand_path("~/db/kegg/v2017/kegg_prot_bacteria_201704.fas")
$kegg_diamond_db = File.expand_path("~/db/diamond/kegg/latest/kegg")


######################################################
# set your path to the DB here
$cog_rbp_db = File.expand_path("~/resource/db/CogRbp/CogRbp")
$sing_db = File.expand_path("~/resource/db/sing/sing")
$mito_bac_db = File.expand_path("~/resource/db/mito-bac/mito-bac")
$bork_db = File.expand_path("~/resource/db/Bork/Bork")


######################################################
$is_cover = false


indirs = Array.new
outdir = nil
$is_diamond = false
suffix = 'protein'
hmmfile = $pfam_hmm
what2do = Hash.new
add_cmd = ''
cpu = 1
$thread = 1
range = Array.new
include_list_file = nil
exclude_list_file = nil
is_force = false
is_tolerate = false


infiles = Array.new


######################################################
def pf(arr)
  printf("%-20s%-80s\n", arr[0], arr[1])
end

def usage()
  puts "ruby #{__FILE__}"
  pf(["--indir", "indir"])
  pf(["--outdir", "outdir"])
  pf(['--diamond', "use diamond"])
  pf(['--suffix', 'suffix of seq'])
  pf(['--hmmsearch', 'use hmmsearch'])
  pf(['--cog', 'blast against cog'])
  pf(['--cog_rbp', 'blast against the 55 ribosomal proteins'])
  pf(['--cdd', 'blast against cdd'])
  pf(['--sing', 'blast against the 25 single copy protein used for bacterial molecular dating'])
  pf(['--mito_bac|mitoBac', 'the 24 bacterial mitochondrial cogs (MitoCOGs)'])
  pf(['--Bork|bork', 'blast against the 40 proteins used in Bork et al. 2011'])
  pf(['--kegg', 'blast against KEGG'])
  pf(['--hmmfile', ""])
  pf(['--add_cmd', "additional arguments for blast"])
  pf(['--cpu', "No. of cpus"])
  pf(['--thread', "No. of threads in BLAST"])
  pf(['--range', "only do blast for the XXX to XXX files"])
  pf(['--include_list', 'the list of species included'])
  pf(['--exclude_list', 'the list of species excluded'])
  pf(['--force', 'remove the outdir if it exists'])
  pf(['--tolerate', 'keep the outdir if it exists'])
  pf(['-h', 'print this message'])
  puts 'any questions? please write to Sishuo Wang (sishuowang@hotmail.ca)'
  exit 1
end


######################################################
def isPass?(file)
  if not $is_cover and File.exists?(file)
    return(true)
  else
    return(false)
  end
end


def runAnalysis(infile, outdir, what2do, hmmfile, add_cmd)
  begin
    if what2do.include?(:hmmsearch)
      outfile = File.join(outdir, getCorename(infile)+'.hmmsearch')
      `#{$hmmsearch} #{add_cmd} --domtblout #{outfile} --noali #{hmmfile} #{infile} >/dev/null`
    elsif what2do.include?(:cog)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$cog_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:cog_rbp)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$cog_rbp_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:sing)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$sing_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:mito_bac)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$mito_bac_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:bork)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$bork_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:cdd)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      `rpsblast -query #{infile} -out #{outfile} -db #{$cdd_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
    elsif what2do.include?(:kegg)
      outfile = File.join(outdir, getCorename(infile)+'.blast8')
      if $is_diamond
        `diamond blastp -q #{infile} -o #{outfile} -k 100 -d #{$kegg_diamond_db} -p #{$thread}`
        #p "diamond blastp -q #{infile} -o #{outfile} -d #{$kegg_diamond_db} -p #{$thread}"
      else
        puts("diamond is not specified for kegg!").colorize(:blue)
        `blastp -query #{infile} -out #{outfile} -db #{$kegg_db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
      end
    else
      if not what2do.empty?
        type = what2do.to_a[0][0].to_s
        outfile = File.join(outdir, getCorename(infile)+'.blast8')
        db = File.exists?(type+'.phr') ? type : File.join(File.expand_path("~/resource/db/"), type, File.basename(type))
        #raise "#{db} does not exist! Exiting ......" if not File.exists?(db+'.freq') and not File.exists(db+'.pal')
        #raise "#{db} does not exist! Exiting ......" if not File.exists?(db+'.psq')
        `blastp -query #{infile} -out #{outfile} -db #{db} -evalue 1e-3 -outfmt 6 -num_threads #{$thread}`
      else
        raise "Wrong! Unknown type of analysis."
      end
    end
    #puts "DONE: #{infile}"
  rescue
    STDERR.puts "Problem: #{infile}"
  end

  #$?.exitstatus == 0 ? puts "DONE: #{infile}" : puts "Problem: #{infile}"
end


def selectInfilesBasedOnRange(infiles, range)
  if ! range.empty?
    infiles = infiles[range[0]-1, range[1]-range[0]+1]
  end
  return(infiles)
end


def selectInfiles(infiles, include_list_file, exclude_list_file, suffix, range)
  infiles = getFilesGood(infiles, {}, suffix)
  if ! include_list_file.nil?
    species_included = read_list(include_list_file)
    infiles = getFilesGood(infiles, species_included, suffix)
  elsif ! exclude_list_file.nil?
    species_excluded = read_list(exclude_list_file)
    infiles = infiles - getFilesGood(infiles, species_excluded, suffix)
  end
  infiles = selectInfilesBasedOnRange(infiles, range)
  return(infiles)
end


######################################################
if __FILE__ == $0
  opts = GetoptLong.new(
    ['--indir', GetoptLong::REQUIRED_ARGUMENT],
    ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
    ['--diamond', GetoptLong::NO_ARGUMENT],
    ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
    ['--hmmsearch', GetoptLong::NO_ARGUMENT],
    ['--cog', GetoptLong::NO_ARGUMENT],
    ['--cog_rbp', GetoptLong::NO_ARGUMENT],
    ['--cdd', GetoptLong::NO_ARGUMENT],
    ['--sing', GetoptLong::NO_ARGUMENT],
    ['--mito_bac', '--mitoBac', GetoptLong::NO_ARGUMENT],
    ['--Bork', '--bork', GetoptLong::NO_ARGUMENT],
    ['--db', GetoptLong::REQUIRED_ARGUMENT],
    ['--kegg', GetoptLong::NO_ARGUMENT],
    ['--kegg_db', GetoptLong::REQUIRED_ARGUMENT],
    ['--kegg_diamond_db', GetoptLong::REQUIRED_ARGUMENT],
    ['--hmmfile', GetoptLong::REQUIRED_ARGUMENT],
    ['--add_cmd', GetoptLong::REQUIRED_ARGUMENT],
    ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
    ['--thread', GetoptLong::REQUIRED_ARGUMENT],
    ['--range', GetoptLong::REQUIRED_ARGUMENT],
    ['--include_list', GetoptLong::REQUIRED_ARGUMENT],
    ['--exclude_list', GetoptLong::REQUIRED_ARGUMENT],
    ['--force', GetoptLong::NO_ARGUMENT],
    ['--tolerate', GetoptLong::NO_ARGUMENT],
    ['-h', GetoptLong::NO_ARGUMENT],
  )


  opts.each do |opt, value|
    case opt
      when /^--indir$/
        indirs << value.split(',')
      when /^--outdir$/
        outdir = value
      when /^--diamond$/
        $is_diamond = true
      when /^--suffix$/
        suffix = value
      when /^--hmmsearch$/
        what2do[:hmmsearch] = ''
      when /^--cog$/
        what2do[:cog] = ''
      when /^--cog_rbp$/
        what2do[:cog_rbp] = ''
      when /^--cdd$/
        what2do[:cdd] = ''
      when /^--sing$/
        what2do[:sing] = ''
      when /^--(mito_bac|mitoBac)$/
        what2do[:mito_bac] = ''
      when /^--bork$/i
        what2do[:bork] = ''
      when /^--db$/
        what2do[value.to_sym] = ''
      when /^--kegg$/
        what2do[:kegg] = ''
        $is_diamond = true
      when /^--kegg_db$/
        $kegg_db = value
      when /^--kegg_diamond_db$/
        $is_diamond = true
        $kegg_diamond_db = value
        what2do[:kegg] = ''
      when /^--hmmfile$/
        hmmfile = value
      when /^--add_cmd$/
        add_cmd = value
      when /^--cpu$/
        cpu = value.to_i
      when /^--thread$/
        $thread = value.to_i
      when /^--range$/
        range = value.split('-').map{|i|i.to_i}
      when /^--include_list$/
        include_list_file = value
      when /^--exclude_list$/
        exclude_list_file = value
      when /^--fam_list$/
        fam_list_file = value
      when /^--force$/
        is_force = true
      when /^--tolerate$/
        is_tolerate = true
      when /^-h$/
        usage()
      else
        usage()
    end
  end


  ######################################################
  indirs.flatten!
  mkdir_with_force(outdir, is_force, is_tolerate)


  ######################################################
  indirs.each do |indir|
    infiles << read_infiles(indir)
  end
  infiles.flatten!

  infiles = selectInfiles(infiles, include_list_file, exclude_list_file, suffix, range)

  puts ['No. of total infiles:', infiles.size].join("\t")

  count = Thread.new{
    while true;
      count = `ls -1 #{outdir} | wc -l`.chomp.to_i
      processbar(count, infiles.size)
      sleep 2
    end
  } 

  Parallel.map(infiles, in_processes: cpu) do |infile|
    runAnalysis(infile, outdir, what2do, hmmfile, add_cmd)
  end

  puts "Done!"
end



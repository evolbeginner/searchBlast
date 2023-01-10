#! /usr/bin/env ruby


#######################################################################
def read_seq_from_dir(infiles, suffix, species_included, cpu, in2out)
  require 'bio'

  infiles_good = getFilesGood(infiles, species_included, suffix)

  results = Parallel.map(infiles_good, in_processes: cpu) do |infile|
    h = Hash.new
    outName = nil
    in_fh = Bio::FlatFile.open(infile, 'r')
    in_fh.each_entry do |f|
      seq_title = f.definition.split(' ')[0]
      inName = seq_title.split('|')[0]
      outName = in2out[inName]
      h[seq_title] = f
    end
    [outName, h]
  end

  seq_objs = Hash.new
  results.each do |a|
    taxon, h = a
    seq_objs[taxon] = h
  end
  return(seq_objs)
end


def getFilesGood(infiles, species_included, suffix)
  infiles_good = Array.new
  infile_basenames_included = species_included.keys.map{|i| [i,suffix].join('.')}
  infiles.each do |infile|
    b = File.basename(infile)
    if infile_basenames_included.empty?
      ;
    else
      next if not infile_basenames_included.include?(b)
    end
    infiles_good << infile
  end
  return(infiles_good)
end



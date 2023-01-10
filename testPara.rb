#! /bin/env ruby


#############################
require 'parallel'


#############################
a = 1..100000
cpu = 2


#############################
count = 0

task = Thread.new{
  while 1 == 1;
    p "haha"
    sleep 0.1
  end
} 

Parallel.each(a, in_processes: cpu) do |i|
  count += 1
  p count
end




#!/usr/bin/env ruby

require 'optparse'
require_relative "expand_root_vol"

options = {region: nil, instance: nil, size: nil, cleanupSnapshot: false, cleanupOriginalVolume: false}

parser = OptionParser.new do|opts|
	opts.banner = "Usage: go.rb [options]"

  opts.on('-r', '--region region', '(required) AWS region') do |region|
		options[:region] = region;
	end

  opts.on('-i', '--instance instance-id', '(required) instance ID') do |instanceID|
		options[:instance] = instanceID;
	end

	opts.on('-s', '--size size', Integer, '(required) new size (Gib)') do |size|
		options[:size] = size;
	end

  opts.on('-n', '--cleansnap', 'cleanup snapshot (defaults to false)') do |setting|
		options[:cleanupSnapshot] = true;
	end

  opts.on('-v', '--cleanvol', 'cleanup original volume (defaults to false)') do |setting|
		options[:cleanupOriginalVolume] = true;
	end

	opts.on('-h', '--help', 'displays this help') do
		puts opts
		exit
	end
end

parser.parse!

mandatory = [:region, :instance, :size]
missing = mandatory.select{ |param| options[param].nil? }
unless missing.empty?
  puts "Missing required parameters: #{missing.join(', ')}"
  puts parser
  exit
end

ExpandRootVol.expand(options[:region], options[:instance], options[:size], options[:cleanupSnapshot], options[:cleanupOriginalVolume])

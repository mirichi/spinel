#!/usr/bin/env ruby
# spinel-gem (POC) — Spinelfile reader + loadpath writer.
#
# Phase 0 scope:
#   - `gem "name", path: "./relative"` only
#   - writes Spinelfile.loadpaths (newline-separated absolute lib dirs)
#   - no network, no cache, no lockfile, no semver

require "pathname"

class Spinelfile
  Gem = Struct.new(:name, :path, :version, :source_line)

  attr_reader :gems

  def self.load(path)
    new.tap { |sf| sf.instance_eval(File.read(path), path.to_s) }
  end

  def initialize
    @gems = []
    @sources = []
  end

  def spinel(_version); end
  def source(url); @sources << url; end

  def gem(name, *args)
    raise ArgumentError, "gem name must be a non-empty string (got #{name.inspect})" \
      unless name.is_a?(String) && !name.empty?
    opts = args.last.is_a?(Hash) ? args.pop : {}
    unsupported = opts.keys - %i[path]
    unless unsupported.empty?
      raise ArgumentError,
            "gem '#{name}': option(s) #{unsupported.inspect} not supported in Phase 0 (only path:)"
    end
    version = args.first
    @gems << Gem.new(name, opts[:path], version, caller_locations(1, 1).first&.lineno)
  end

  def group(*_names); yield if block_given?; end
end

def die(msg)
  warn "spinel-gem: #{msg}"
  exit 1
end

def find_spinelfile(start)
  dir = Pathname.new(start).realpath
  dir = dir.dirname if dir.file?
  until dir.root?
    candidate = dir.join("Spinelfile")
    return candidate if candidate.file?
    dir = dir.parent
  end
  nil
end

def cmd_install(spinelfile_path)
  begin
    sf = Spinelfile.load(spinelfile_path)
  rescue ArgumentError, SyntaxError => e
    die "#{spinelfile_path}: #{e.message}"
  end
  base = Pathname.new(spinelfile_path).dirname
  loadpaths = []
  sf.gems.each do |g|
    die "gem '#{g.name}' has no path: (Phase 0 only supports path gems)" unless g.path
    lib = (base + g.path + "lib").expand_path
    die "gem '#{g.name}' path '#{lib}' missing or not a directory" unless lib.directory?
    entry = lib.realpath.to_s
    loadpaths << entry unless loadpaths.include?(entry)
    puts "  resolved  #{g.name.ljust(20)} -> #{entry}"
  end
  out = base.join("Spinelfile.loadpaths")
  File.write(out, loadpaths.join("\n") + (loadpaths.empty? ? "" : "\n"))
  puts "wrote #{out} (#{loadpaths.size} entr#{loadpaths.size == 1 ? 'y' : 'ies'})"
end

def cmd_list(spinelfile_path)
  sf = Spinelfile.load(spinelfile_path)
  sf.gems.each do |g|
    puts "  #{g.name}#{g.version ? " (#{g.version})" : ''}#{g.path ? " [path: #{g.path}]" : ''}"
  end
end

if __FILE__ == $PROGRAM_NAME
  cmd = ARGV.shift || "install"
  sfile = find_spinelfile(Dir.pwd) or die "no Spinelfile in #{Dir.pwd} or any parent"

  case cmd
  when "install" then cmd_install(sfile)
  when "list"    then cmd_list(sfile)
  when "help"    then puts "usage: spinel-gem [install|list|help]"
  else die "unknown command: #{cmd}"
  end
end

#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "pathname"
require_relative "../spinel_gem"

class SpinelfileTest < Minitest::Test
  def with_tmp
    Dir.mktmpdir("spinelfile-test-") { |d| yield Pathname.new(d) }
  end

  def write(path, content)
    File.write(path, content)
    path
  end

  def test_empty_spinelfile_has_no_gems
    with_tmp do |d|
      sf = Spinelfile.load(write(d + "Spinelfile", "spinel '1.0'\n"))
      assert_empty sf.gems
    end
  end

  def test_single_path_gem_recorded
    with_tmp do |d|
      sf = Spinelfile.load(write(d + "Spinelfile", %(gem "foo", path: "./vendor/foo"\n)))
      assert_equal 1, sf.gems.size
      assert_equal "foo", sf.gems[0].name
      assert_equal "./vendor/foo", sf.gems[0].path
    end
  end

  def test_multiple_gems_preserve_order
    sfile = <<~RUBY
      gem "a", path: "./a"
      gem "b", path: "./b"
      gem "c", path: "./c"
    RUBY
    with_tmp do |d|
      sf = Spinelfile.load(write(d + "Spinelfile", sfile))
      assert_equal %w[a b c], sf.gems.map(&:name)
    end
  end

  def test_version_constraint_stored
    with_tmp do |d|
      sf = Spinelfile.load(write(d + "Spinelfile", %(gem "x", "~> 1.2", path: "./x"\n)))
      assert_equal "~> 1.2", sf.gems[0].version
    end
  end

  def test_gem_with_nil_name_raises
    with_tmp do |d|
      assert_raises(ArgumentError) do
        Spinelfile.load(write(d + "Spinelfile", %(gem nil, path: "./x"\n)))
      end
    end
  end

  def test_gem_with_empty_name_raises
    with_tmp do |d|
      assert_raises(ArgumentError) do
        Spinelfile.load(write(d + "Spinelfile", %(gem "", path: "./x"\n)))
      end
    end
  end

  def test_unsupported_source_option_raises_with_phase0_message
    with_tmp do |d|
      err = assert_raises(ArgumentError) do
        Spinelfile.load(write(d + "Spinelfile",
                              %(gem "x", git: "https://example.com/x"\n)))
      end
      assert_match(/Phase 0/, err.message)
      assert_match(/git/, err.message)
    end
  end

  def test_group_block_still_records_gems
    sfile = <<~RUBY
      gem "runtime", path: "./r"
      group :test do
        gem "testdep", path: "./t"
      end
    RUBY
    with_tmp do |d|
      sf = Spinelfile.load(write(d + "Spinelfile", sfile))
      assert_equal %w[runtime testdep], sf.gems.map(&:name)
    end
  end

  def test_find_spinelfile_walks_up
    with_tmp do |d|
      write(d + "Spinelfile", "")
      nested = d + "a/b/c"
      nested.mkpath
      found = find_spinelfile(nested.to_s)
      assert_equal (d + "Spinelfile").realpath, found.realpath
    end
  end

  def test_find_spinelfile_returns_nil_when_absent
    with_tmp do |d|
      assert_nil find_spinelfile(d.to_s)
    end
  end

  def test_find_spinelfile_stops_at_first_hit
    # outer Spinelfile shouldn't win when inner one is closer
    with_tmp do |d|
      write(d + "Spinelfile", "# outer\n")
      inner = d + "sub"
      inner.mkpath
      write(inner + "Spinelfile", "# inner\n")
      found = find_spinelfile(inner.to_s)
      assert_equal (inner + "Spinelfile").realpath, found.realpath
    end
  end
end

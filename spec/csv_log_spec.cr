require "./spec_helper"
require "../src/bamboohr_cli/csv_log"
require "file_utils"

describe BambooHRCLI::CsvLog do
  dir = File.join(Dir.tempdir, "bamboohr-cli-csv-#{Random.new.hex(4)}")

  after_each { FileUtils.rm_rf(dir) }

  it "appends rows to the month file with a single header" do
    start = Time.local(2026, 10, 6, 9, 0, 0)
    BambooHRCLI::CsvLog.append(BambooHRCLI::CsvLog::Row.new(1, start, start + 2.hours, "a"), dir)
    path = BambooHRCLI::CsvLog.append(BambooHRCLI::CsvLog::Row.new(2, start + 3.hours, start + 4.hours, nil), dir)

    File.basename(path).should eq "2026-10.csv"
    lines = File.read_lines(path)
    lines.size.should eq 3
    lines[0].should eq "entry_id,date,start,end,duration_hours,note"
    lines[1].should contain "2.00"
  end

  it "skips rows whose entry_id already exists" do
    start = Time.local(2026, 10, 6, 9, 0, 0)
    row = BambooHRCLI::CsvLog::Row.new(7, start, start + 1.hour, nil)
    BambooHRCLI::CsvLog.append(row, dir)
    path = BambooHRCLI::CsvLog.append(row, dir)
    File.read_lines(path).size.should eq 2
  end

  it "uses the start month for sessions crossing a month boundary" do
    start = Time.local(2026, 9, 30, 23, 0, 0)
    path = BambooHRCLI::CsvLog.append(BambooHRCLI::CsvLog::Row.new(3, start, start + 2.hours, nil), dir)
    File.basename(path).should eq "2026-09.csv"
  end

  it "prefixes formula-like notes and restricts permissions" do
    start = Time.local(2026, 10, 6, 9, 0, 0)
    path = BambooHRCLI::CsvLog.append(BambooHRCLI::CsvLog::Row.new(4, start, start + 1.hour, "=SUM(A1)"), dir)
    File.read(path).should contain "'=SUM(A1)"
    File.info(path).permissions.should eq File::Permissions.new(0o600)
  end

  it "rewrites a month atomically, sorted by start" do
    a = Time.local(2026, 10, 7, 9, 0, 0)
    b = Time.local(2026, 10, 6, 9, 0, 0)
    path = BambooHRCLI::CsvLog.write_month("2026-10", [
      BambooHRCLI::CsvLog::Row.new(2, a, a + 1.hour, nil),
      BambooHRCLI::CsvLog::Row.new(1, b, b + 1.hour, nil),
    ], dir)
    lines = File.read_lines(path)
    lines[1].should start_with "1,"
    lines[2].should start_with "2,"
    File.exists?("#{path}.tmp").should be_false
  end
end

describe "CLI#export_month" do
  it "does not overwrite an existing file unless told to" do
    dir = File.join(Dir.tempdir, "bamboohr-cli-export-#{Random.new.hex(4)}")
    Dir.mkdir_p(dir)
    path = File.join(dir, "2026-10.csv")
    File.write(path, "keep")
    io = IO::Memory.new
    cli = BambooHRCLI::CLI.new("acme", "key", "1", 8, io, dir)

    cli.export_month("2026-10").should be_false
    File.read(path).should eq "keep"
    io.to_s.should contain "already exists"
    FileUtils.rm_rf(dir)
  end
end

require "csv"
require "time"

module BambooHRCLI
  # Per-month CSV log of completed time-tracking sessions, stored under the
  # XDG data directory (one file per month: YYYY-MM.csv).
  class CsvLog
    HEADER = %w(entry_id date start end duration_hours note)

    record Row, entry_id : Int32?, start : Time, finish : Time, note : String?

    def self.data_dir : String
      base = ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
      File.join(base, "bamboohr-cli")
    end

    def self.path_for(time : Time, dir : String = data_dir) : String
      path_for(time.to_local.to_s("%Y-%m"), dir)
    end

    def self.path_for(month : String, dir : String = data_dir) : String
      File.join(dir, "#{month}.csv")
    end

    # Appends a session to the CSV of the month it started in. Rows whose
    # entry_id is already present are skipped. Returns the file path.
    def self.append(row : Row, dir : String = data_dir) : String
      ensure_dir(dir)
      path = path_for(row.start, dir)
      new_file = !File.exists?(path)

      if !new_file && (id = row.entry_id) && has_entry?(path, id)
        return path
      end

      File.open(path, "a", perm: File::Permissions.new(0o600)) do |file|
        CSV.build(file) do |csv|
          csv.row HEADER if new_file
          csv.row cells(row)
        end
      end
      File.chmod(path, 0o600) if new_file
      path
    end

    # Atomically replaces the CSV for the given month (YYYY-MM) with the rows.
    def self.write_month(month : String, rows : Array(Row), dir : String = data_dir) : String
      ensure_dir(dir)
      path = path_for(month, dir)
      tmp = "#{path}.tmp"

      File.open(tmp, "w", perm: File::Permissions.new(0o600)) do |file|
        CSV.build(file) do |csv|
          csv.row HEADER
          rows.sort_by(&.start).each { |row| csv.row cells(row) }
        end
      end
      File.chmod(tmp, 0o600)
      File.rename(tmp, path)
      path
    end

    # Prefixes cells that a spreadsheet could interpret as a formula (CSV injection).
    def self.sanitize(value : String) : String
      value.starts_with?(/[=+\-@\t\r]/) ? "'#{value}" : value
    end

    private def self.cells(row : Row) : Array(String)
      start = row.start.to_local
      finish = row.finish.to_local
      hours = (finish - start).total_hours

      [
        row.entry_id.to_s,
        start.to_s("%Y-%m-%d"),
        start.to_rfc3339,
        finish.to_rfc3339,
        "%.2f" % hours,
        sanitize(row.note || ""),
      ]
    end

    private def self.has_entry?(path : String, entry_id : Int32) : Bool
      File.open(path) do |file|
        CSV.each_row(file) do |cols|
          return true if cols[0]? == entry_id.to_s
        end
      end
      false
    end

    private def self.ensure_dir(dir : String)
      Dir.mkdir_p(dir, 0o700)
    end
  end
end

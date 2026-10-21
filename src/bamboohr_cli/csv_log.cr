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
      drop_open_rows(path)
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

    # Records a clock-in that has no clock-out yet: a row with empty end and
    # duration. It lets a later run know the user is still clocked in; the row
    # is replaced by the completed session on clock-out (see `append`).
    def self.start_session(start : Time, entry_id : Int32?, note : String?, dir : String = data_dir) : String
      ensure_dir(dir)
      path = path_for(start, dir)
      drop_open_rows(path)
      new_file = !File.exists?(path)

      File.open(path, "a", perm: File::Permissions.new(0o600)) do |file|
        CSV.build(file) do |csv|
          csv.row HEADER if new_file
          csv.row [
            entry_id.to_s,
            start.to_local.at_beginning_of_minute.to_s("%Y-%m-%d"),
            start.to_local.at_beginning_of_minute.to_rfc3339,
            "",
            "",
            sanitize(note || ""),
          ]
        end
      end
      File.chmod(path, 0o600) if new_file
      path
    end

    # Start time of the session that was clocked in but never clocked out, if
    # any. Looks at the current and previous month (a session can span midnight
    # on the last day of a month).
    def self.open_session(dir : String = data_dir) : Time?
      now = Time.local
      [now, now.at_beginning_of_month - 1.day].each do |time|
        path = path_for(time, dir)
        next unless File.exists?(path)
        File.open(path) do |file|
          CSV.each_row(file) do |cols|
            next if cols[0]? == HEADER[0]
            if cols[3]?.try(&.empty?) && (start = cols[2]?) && !start.empty?
              return Time.parse_rfc3339(start)
            end
          end
        end
      end
      nil
    rescue Time::Format::Error | File::Error | CSV::Error
      nil
    end

    # Removes rows without a clock-out time from the file (no-op if none).
    private def self.drop_open_rows(path : String)
      return unless File.exists?(path)

      kept = [] of Array(String)
      dropped = false
      File.open(path) do |file|
        CSV.each_row(file) do |cols|
          if cols[3]?.try(&.empty?) && cols[0]? != HEADER[0]
            dropped = true
          else
            kept << cols
          end
        end
      end
      return unless dropped

      tmp = "#{path}.tmp"
      File.open(tmp, "w", perm: File::Permissions.new(0o600)) do |file|
        CSV.build(file) { |csv| kept.each { |cols| csv.row cols } }
      end
      File.chmod(tmp, 0o600)
      File.rename(tmp, path)
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
      # BambooHR stores times to the minute (truncated), so match it here.
      start = row.start.to_local.at_beginning_of_minute
      finish = row.finish.to_local.at_beginning_of_minute
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

require "http/client"
require "json"
require "base64"
require "time"

module BambooHRCLI
  # Response models based on API specification
  struct TimesheetEntry
    include JSON::Serializable

    property id : Int32
    property employeeId : Int32
    property type : String
    property date : String
    property start : String?
    property end : String?
    property timezone : String?
    property hours : Float32?
    property note : String?

    def initialize(@id : Int32, @employeeId : Int32, @type : String, @date : String,
                   @start : String? = nil, @end : String? = nil, @timezone : String? = nil,
                   @hours : Float32? = nil, @note : String? = nil)
    end
  end

  struct EmployeeTimesheetEntry
    include JSON::Serializable

    property id : Int32
    property employeeId : Int32
    property date : String
    property start : String?
    property end : String?
    property timezone : String?
    property hours : Float32?
    property note : String?
    property projectId : Int32?
    property taskId : Int32?

    def initialize(@id : Int32, @employeeId : Int32, @date : String,
                   @start : String? = nil, @end : String? = nil, @timezone : String? = nil,
                   @hours : Float32? = nil, @note : String? = nil,
                   @projectId : Int32? = nil, @taskId : Int32? = nil)
    end
  end

  # The API returns a direct array, not an object with a property
  alias EmployeeTimesheetEntryCollection = Array(EmployeeTimesheetEntry)

  # BambooHR API Client
  class BambooHRAPI
    @auth_header : String

    def initialize(@company_domain : String, @api_key : String, @employee_id : String)
      @auth_header = "Basic " + Base64.strict_encode("#{@api_key}:x")
    end

    def clock_in(note : String? = nil, project_id : Int32? = nil, task_id : Int32? = nil) : {Bool, TimesheetEntry?}
      # Build request body with optional parameters
      body = {} of String => JSON::Any
      body["note"] = JSON::Any.new(note) if note
      body["projectId"] = JSON::Any.new(project_id.to_i64) if project_id
      body["taskId"] = JSON::Any.new(task_id.to_i64) if task_id

      # Add current date and timezone in UTC
      utc_now = Time.utc
      body["date"] = JSON::Any.new(utc_now.to_s("%Y-%m-%d"))
      body["start"] = JSON::Any.new(utc_now.to_s("%H:%M"))
      body["timezone"] = JSON::Any.new("UTC")

      response = make_request("POST", "/api/v1/time_tracking/employees/#{@employee_id}/clock_in", body)

      if response.success?
        begin
          entry = TimesheetEntry.from_json(response.body)
          return {true, entry}
        rescue ex : JSON::ParseException
          return {true, nil} # Success but couldn't parse response
        end
      else
        return {false, nil}
      end
    end

    def clock_out : {Bool, TimesheetEntry?}
      # Build request body with UTC time
      body = {} of String => JSON::Any
      utc_now = Time.utc

      body["date"] = JSON::Any.new(utc_now.to_s("%Y-%m-%d"))
      body["end"] = JSON::Any.new(utc_now.to_s("%H:%M"))
      body["timezone"] = JSON::Any.new("UTC")

      response = make_request("POST", "/api/v1/time_tracking/employees/#{@employee_id}/clock_out", body)

      if response.success?
        begin
          entry = TimesheetEntry.from_json(response.body)
          return {true, entry}
        rescue ex : JSON::ParseException
          return {true, nil} # Success but couldn't parse response
        end
      else
        return {false, nil}
      end
    end

    def get_timesheet_entries(start_date : String, end_date : String) : {Bool, EmployeeTimesheetEntryCollection?}
      response = make_request("GET", "/api/v1/time_tracking/timesheet_entries?start=#{start_date}&end=#{end_date}&employeeIds=#{@employee_id}")

      if response.success?
        begin
          entries = EmployeeTimesheetEntryCollection.from_json(response.body)
          return {true, entries}
        rescue ex : JSON::ParseException
          return {false, nil}
        end
      else
        return {false, nil}
      end
    end

    def get_current_status : {Bool, Time?}
      today = Time.local.at_beginning_of_day
      today_str = today.to_s("%Y-%m-%d")

      success, entries = get_timesheet_entries(today_str, today_str)

      if success && entries
        # Find the latest entry for today that has a start time but no end time
        latest_entry = entries.select { |entry|
          entry.start && !entry.end
        }.last?

        if latest_entry && latest_entry.start
          begin
            clock_in_time = Time.parse_iso8601(latest_entry.start.not_nil!)
            return {true, clock_in_time}
          rescue
            return {false, nil}
          end
        end
      end

      return {true, nil} # Successfully determined not clocked in
    end

    def get_daily_total(date : String) : {Bool, Int32}
      success, entries = get_timesheet_entries(date, date)

      if success && entries
        total_seconds = 0

        entries.each do |entry|
          if start_str = entry.start
            begin
              start_time = Time.parse_iso8601(start_str)

              if end_str = entry.end
                end_time = Time.parse_iso8601(end_str)
                total_seconds += (end_time - start_time).total_seconds.to_i
              else
                # Active session - calculate time until now
                total_seconds += (Time.local - start_time).total_seconds.to_i
              end
            rescue
              # Skip entries with invalid time formats
            end
          end
        end

        return {true, total_seconds}
      else
        return {false, 0}
      end
    end

    def get_last_response_status : Int32?
      @last_response_status
    end

    def get_last_response_body : String?
      @last_response_body
    end

    private def make_request(method : String, path : String, body : Hash(String, JSON::Any)? = nil) : HTTP::Client::Response
      headers = HTTP::Headers{
        "Authorization" => @auth_header,
        "Accept"        => "application/json",
        "Content-Type"  => "application/json",
      }

      # Use the proper BambooHR API base URL
      client = HTTP::Client.new("#{@company_domain}.bamboohr.com", tls: true)
      client.connect_timeout = 10.seconds
      client.read_timeout = 30.seconds

      begin
        response = case method
                   when "GET"
                     client.get(path, headers: headers)
                   when "POST"
                     body_json = body ? body.to_json : "{}"
                     client.post(path, headers: headers, body: body_json)
                   else
                     raise "Unsupported HTTP method: #{method}"
                   end

        # Store response details for debugging
        @last_response_status = response.status_code
        @last_response_body = response.body

        response
      rescue ex : IO::TimeoutError
        HTTP::Client::Response.new(408, "Request Timeout")
      rescue ex : Socket::ConnectError
        HTTP::Client::Response.new(503, "Service Unavailable")
      rescue ex
        HTTP::Client::Response.new(500, "Network Error: #{ex.message}")
      ensure
        client.close
      end
    end

    @last_response_status : Int32?
    @last_response_body : String?
  end
end

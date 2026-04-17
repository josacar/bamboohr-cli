require "spec"
require "../src/bamboohr_cli/api"

private def make_time_off_request(id : String, unit : String, status : String, dates : Hash(String, String)) : BambooHRCLI::TimeOffRequest
  total = dates.values.sum(&.to_f).to_s
  json_dates = dates.map { |k, v| %("#{k}": "#{v}") }.join(", ")
  start_d = dates.keys.min
  end_d = dates.keys.max
  BambooHRCLI::TimeOffRequest.from_json(%({
    "id": "#{id}", "start": "#{start_d}", "end": "#{end_d}",
    "amount": {"unit": "#{unit}", "amount": "#{total}"},
    "type": {"id": "1", "name": "Vacation", "icon": "airplane"},
    "status": {"status": "#{status}"},
    "dates": {#{json_dates}}
  }))
end

private def sum_time_off(requests : Array(BambooHRCLI::TimeOffRequest), monday_str : String, today_str : String, hours_per_day : Int32 = 8) : Float32
  total = 0.0_f32
  requests.each do |request|
    status = request.status.status
    next unless status == "approved" || status == "requested"
    unit = request.amount.unit
    request.dates.each do |date_str, value_str|
      next unless date_str >= monday_str && date_str <= today_str
      value = value_str.to_f32?
      next unless value
      case unit
      when "days"  then total += value * hours_per_day
      when "hours" then total += value
      end
    end
  end
  total
end

describe "BambooHR API Models" do
  describe "TimesheetEntry" do
    it "can be created with required parameters" do
      entry = BambooHRCLI::TimesheetEntry.new(
        id: 123,
        employeeId: 456,
        type: "clock_in",
        date: "2024-12-12"
      )

      entry.id.should eq(123)
      entry.employeeId.should eq(456)
      entry.type.should eq("clock_in")
      entry.date.should eq("2024-12-12")
    end

    it "can be created with optional parameters" do
      entry = BambooHRCLI::TimesheetEntry.new(
        id: 123,
        employeeId: 456,
        type: "clock_in",
        date: "2024-12-12",
        start: "2024-12-12T09:00:00Z",
        timezone: "America/Denver",
        note: "Starting work"
      )

      entry.start.should eq("2024-12-12T09:00:00Z")
      entry.timezone.should eq("America/Denver")
      entry.note.should eq("Starting work")
    end

    it "can be serialized to JSON" do
      entry = BambooHRCLI::TimesheetEntry.new(
        id: 123,
        employeeId: 456,
        type: "clock_in",
        date: "2024-12-12",
        note: "Test note"
      )

      json = entry.to_json
      json.should contain("123")
      json.should contain("456")
      json.should contain("clock_in")
      json.should contain("Test note")
    end

  describe "TimeOffRequest" do
    it "can be deserialized from JSON" do
      json = %({
        "id": "114040",
        "start": "2026-02-16",
        "end": "2026-02-16",
        "amount": {
          "unit": "days",
          "amount": "0.5"
        },
        "type": {
          "id": "104",
          "name": "FlyBetter Days",
          "icon": "medal"
        },
        "status": {
          "status": "approved"
        },
        "dates": {
          "2026-02-16": "0.5"
        }
      })

      request = BambooHRCLI::TimeOffRequest.from_json(json)
      request.id.should eq("114040")
      request.start.should eq("2026-02-16")
      request.end.should eq("2026-02-16")
      request.amount.unit.should eq("days")
      request.amount.amount.should eq("0.5")
      request.type.name.should eq("FlyBetter Days")
      request.status.status.should eq("approved")
    end

    it "can deserialize a collection from JSON" do
      json = %([{
        "id": "114040",
        "start": "2026-02-16",
        "end": "2026-02-16",
        "amount": {"unit": "days", "amount": "0.5"},
        "type": {"id": "104", "name": "Vacation", "icon": "airplane"},
        "status": {"status": "approved"},
        "dates": {"2026-02-16": "0.5"}
      }])

      requests = BambooHRCLI::TimeOffRequestCollection.from_json(json)
      requests.size.should eq(1)
      requests[0].id.should eq("114040")
    end

    it "exposes dates hash with per-day amounts" do
      json = %({
        "id": "200",
        "start": "2026-04-14",
        "end": "2026-04-16",
        "amount": {"unit": "days", "amount": "3"},
        "type": {"id": "1", "name": "Vacation", "icon": "airplane"},
        "status": {"status": "approved"},
        "dates": {"2026-04-14": "1", "2026-04-15": "1", "2026-04-16": "1"}
      })

      request = BambooHRCLI::TimeOffRequest.from_json(json)
      request.dates.size.should eq(3)
      request.dates["2026-04-14"].should eq("1")
      request.dates["2026-04-15"].should eq("1")
      request.dates["2026-04-16"].should eq("1")
    end

    it "can have hours as unit" do
      json = %({
        "id": "201",
        "start": "2026-04-14",
        "end": "2026-04-14",
        "amount": {"unit": "hours", "amount": "4"},
        "type": {"id": "1", "name": "Sick", "icon": "health"},
        "status": {"status": "approved"},
        "dates": {"2026-04-14": "4"}
      })

      request = BambooHRCLI::TimeOffRequest.from_json(json)
      request.amount.unit.should eq("hours")
      request.dates["2026-04-14"].should eq("4")
    end

    describe "weekly time off summing logic" do
      it "counts Monday day-unit approved request" do
        requests = [make_time_off_request("1", "days", "approved", {"2026-04-13" => "1"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(8.0_f32)
      end

      it "counts Monday hour-unit approved request" do
        requests = [make_time_off_request("1", "hours", "approved", {"2026-04-13" => "4"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(4.0_f32)
      end

      it "counts pending (requested) time off" do
        requests = [make_time_off_request("1", "days", "requested", {"2026-04-14" => "1"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(8.0_f32)
      end

      it "excludes denied requests" do
        requests = [make_time_off_request("1", "days", "denied", {"2026-04-14" => "1"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(0.0_f32)
      end

      it "excludes dates outside the monday-today window" do
        requests = [make_time_off_request("1", "days", "approved", {"2026-04-12" => "1", "2026-04-13" => "1"})]
        # Only 2026-04-13 (Monday) is inside window; 2026-04-12 (Sunday) is excluded
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(8.0_f32)
      end

      it "only counts dates up to today in multi-day request spanning into future" do
        requests = [make_time_off_request("1", "days", "approved", {
          "2026-04-14" => "1", "2026-04-15" => "1", "2026-04-16" => "1", "2026-04-17" => "1", "2026-04-18" => "1",
        })]
        # today_str = "2026-04-16" so only Mon-Wed count (3 days)
        sum_time_off(requests, "2026-04-13", "2026-04-16").should eq(24.0_f32)
      end

      it "counts partial days (0.5 days)" do
        requests = [make_time_off_request("1", "days", "approved", {"2026-04-14" => "0.5"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(4.0_f32)
      end

      it "respects custom hours_per_day" do
        requests = [make_time_off_request("1", "days", "approved", {"2026-04-14" => "1"})]
        sum_time_off(requests, "2026-04-13", "2026-04-17", hours_per_day: 7).should eq(7.0_f32)
      end

      it "sums multiple requests in the same week" do
        requests = [
          make_time_off_request("1", "days", "approved", {"2026-04-14" => "1"}),
          make_time_off_request("2", "hours", "approved", {"2026-04-15" => "4"}),
        ]
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(12.0_f32)
      end

      it "returns zero when no requests in window" do
        requests = [] of BambooHRCLI::TimeOffRequest
        sum_time_off(requests, "2026-04-13", "2026-04-17").should eq(0.0_f32)
      end
    end
  end


    it "can be deserialized from JSON" do
      json_str = {
        "id"         => 123,
        "employeeId" => 456,
        "type"       => "clock_in",
        "date"       => "2024-12-12",
        "start"      => "2024-12-12T09:00:00Z",
        "timezone"   => "America/Denver",
      }.to_json

      entry = BambooHRCLI::TimesheetEntry.from_json(json_str)
      entry.id.should eq(123)
      entry.employeeId.should eq(456)
      entry.type.should eq("clock_in")
      entry.date.should eq("2024-12-12")
      entry.start.should eq("2024-12-12T09:00:00Z")
      entry.timezone.should eq("America/Denver")
    end
  end

  describe "EmployeeTimesheetEntry" do
    it "can be created with all parameters" do
      entry = BambooHRCLI::EmployeeTimesheetEntry.new(
        id: 123,
        employeeId: 456,
        date: "2024-12-12",
        start: "2024-12-12T09:00:00Z",
        end: "2024-12-12T17:00:00Z",
        timezone: "America/Denver",
        hours: 8.0_f32,
        note: "Full work day",
        projectId: 10,
        taskId: 25
      )

      entry.id.should eq(123)
      entry.employeeId.should eq(456)
      entry.date.should eq("2024-12-12")
      entry.start.should eq("2024-12-12T09:00:00Z")
      entry.end.should eq("2024-12-12T17:00:00Z")
      entry.timezone.should eq("America/Denver")
      entry.hours.should eq(8.0_f32)
      entry.note.should eq("Full work day")
      entry.projectId.should eq(10)
      entry.taskId.should eq(25)
    end

    it "handles nil values correctly" do
      entry = BambooHRCLI::EmployeeTimesheetEntry.new(
        id: 123,
        employeeId: 456,
        date: "2024-12-12",
        start: "2024-12-12T09:00:00Z",
        end: nil,
        hours: nil,
        note: nil,
        projectId: nil,
        taskId: nil
      )

      entry.start.should eq("2024-12-12T09:00:00Z")
      entry.end.should be_nil
      entry.hours.should be_nil
      entry.note.should be_nil
      entry.projectId.should be_nil
      entry.taskId.should be_nil
    end

    it "can be deserialized from JSON" do
      json_str = {
        "id"         => 123,
        "employeeId" => 456,
        "date"       => "2024-12-12",
        "start"      => "2024-12-12T09:00:00Z",
        "end"        => "2024-12-12T17:00:00Z",
        "timezone"   => "America/Denver",
        "hours"      => 8.0,
        "note"       => "Work day",
        "projectId"  => 10,
        "taskId"     => 25,
      }.to_json

      entry = BambooHRCLI::EmployeeTimesheetEntry.from_json(json_str)
      entry.id.should eq(123)
      entry.employeeId.should eq(456)
      entry.date.should eq("2024-12-12")
      entry.start.should eq("2024-12-12T09:00:00Z")
      entry.end.should eq("2024-12-12T17:00:00Z")
      entry.timezone.should eq("America/Denver")
      entry.hours.should eq(8.0_f32)
      entry.note.should eq("Work day")
      entry.projectId.should eq(10)
      entry.taskId.should eq(25)
    end
  end

  describe "EmployeeTimesheetEntryCollection" do
    it "can parse array response with multiple entries" do
      json_str = [
        {
          "id"         => 123,
          "employeeId" => 456,
          "date"       => "2024-12-12",
          "start"      => "2024-12-12T09:00:00Z",
          "end"        => "2024-12-12T17:00:00Z",
          "hours"      => 8.0,
        },
        {
          "id"         => 124,
          "employeeId" => 456,
          "date"       => "2024-12-12",
          "start"      => "2024-12-12T18:00:00Z",
          "end"        => nil,
          "hours"      => nil,
        },
      ].to_json

      entries = BambooHRCLI::EmployeeTimesheetEntryCollection.from_json(json_str)
      entries.should be_a(Array(BambooHRCLI::EmployeeTimesheetEntry))
      entries.size.should eq(2)
      entries[0].hours.should eq(8.0_f32)
      entries[1].end.should be_nil
    end

    it "handles empty array" do
      json_str = "[]"

      entries = BambooHRCLI::EmployeeTimesheetEntryCollection.from_json(json_str)
      entries.should be_a(Array(BambooHRCLI::EmployeeTimesheetEntry))
      entries.size.should eq(0)
    end
  end
end

describe "API" do
  describe "initialization" do
    it "creates a new API client with correct parameters" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")
      api.should be_a(BambooHRCLI::API)
    end
  end

  describe "API methods return proper tuples" do
    it "clock_in returns success boolean and optional entry" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")

      # This will fail with test credentials, but we can verify the return type
      success, entry = api.clock_in
      success.should be_a(Bool)
      entry.should be_a(BambooHRCLI::TimesheetEntry?) # Can be nil
    end

    it "clock_out returns success boolean and optional entry" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")

      success, entry = api.clock_out
      success.should be_a(Bool)
      entry.should be_a(BambooHRCLI::TimesheetEntry?)
    end

    it "get_current_status returns success boolean and optional time" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")

      success, time = api.get_current_status
      success.should be_a(Bool)
      time.should be_a(Time?)
    end

    it "get_daily_total returns success boolean and integer seconds" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")

      success, seconds = api.get_daily_total("2024-01-01")
      success.should be_a(Bool)
      seconds.should be_a(Int32)
    end

    it "get_timesheet_entries returns success boolean and optional collection" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")
      
      success, entries = api.get_timesheet_entries("2024-01-01", "2024-01-31")
      success.should be_a(Bool)
      entries.should be_a(BambooHRCLI::EmployeeTimesheetEntryCollection?)
    end

    it "get_time_off_requests returns success boolean and optional collection" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")
      
      success, requests = api.get_time_off_requests("2026-02-16", "2026-02-19")
      success.should be_a(Bool)
      requests.should be_a(BambooHRCLI::TimeOffRequestCollection?)
    end
  end

  describe "response tracking" do
    it "tracks last response status and body" do
      api = BambooHRCLI::API.new("testcompany", "test_api_key", "123")

      # Make a request (will fail with test credentials)
      api.clock_in

      # Should have response details
      status = api.get_last_response_status
      body = api.get_last_response_body

      status.should be_a(Int32?)
      body.should be_a(String?)
    end
  end
end

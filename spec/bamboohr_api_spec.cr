require "spec"
require "../src/bamboohr_cli/api"

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

describe "BambooHRAPI" do
  describe "initialization" do
    it "creates a new API client with correct parameters" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")
      api.should be_a(BambooHRCLI::BambooHRAPI)
    end
  end

  describe "API methods return proper tuples" do
    it "clock_in returns success boolean and optional entry" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

      # This will fail with test credentials, but we can verify the return type
      success, entry = api.clock_in
      success.should be_a(Bool)
      entry.should be_a(BambooHRCLI::TimesheetEntry?) # Can be nil
    end

    it "clock_out returns success boolean and optional entry" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

      success, entry = api.clock_out
      success.should be_a(Bool)
      entry.should be_a(BambooHRCLI::TimesheetEntry?)
    end

    it "get_current_status returns success boolean and optional time" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

      success, time = api.get_current_status
      success.should be_a(Bool)
      time.should be_a(Time?)
    end

    it "get_daily_total returns success boolean and integer seconds" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

      success, seconds = api.get_daily_total("2024-01-01")
      success.should be_a(Bool)
      seconds.should be_a(Int32)
    end

    it "get_timesheet_entries returns success boolean and optional collection" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

      success, entries = api.get_timesheet_entries("2024-01-01", "2024-01-01")
      success.should be_a(Bool)
      entries.should be_a(BambooHRCLI::EmployeeTimesheetEntryCollection?)
    end
  end

  describe "response tracking" do
    it "tracks last response status and body" do
      api = BambooHRCLI::BambooHRAPI.new("testcompany", "test_api_key", "123")

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

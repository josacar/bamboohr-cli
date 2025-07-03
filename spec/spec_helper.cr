require "spec"

# Configure spec environment
Spec.before_suite do
  # Setup any global test configuration here
end

Spec.after_suite do
  # Cleanup after all tests
end

# Helper methods for tests
module SpecHelper
  def self.sample_timesheet_entry_json
    {
      "id"         => 12345,
      "employeeId" => 123,
      "type"       => "clock_in",
      "date"       => "2024-12-12",
      "start"      => "2024-12-12T09:00:00Z",
      "end"        => nil,
      "timezone"   => "America/Denver",
      "hours"      => nil,
      "note"       => "Starting work",
    }.to_json
  end

  def self.sample_clock_entries_json
    {
      "clockEntries" => [
        {
          "clockInDateTime"  => "2024-12-12T09:00:00Z",
          "clockOutDateTime" => "2024-12-12T17:00:00Z",
          "hours"            => 8.0,
        },
        {
          "clockInDateTime"  => "2024-12-12T18:00:00Z",
          "clockOutDateTime" => nil,
          "hours"            => nil,
        },
      ],
    }.to_json
  end

  def self.create_mock_response(status_code : Int32, body : String)
    HTTP::Client::Response.new(status_code, body)
  end
end

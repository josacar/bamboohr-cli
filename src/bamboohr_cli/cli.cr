require "colorize"
require "time"
require "./api"

module BambooHRCLI
  class CLI
    @api : API
    @current_session_start : Time?
    @daily_total_seconds : Int32
    @io : IO
    @update_channel : Channel(Bool)?
    @last_daily_refresh : Time

    def initialize(@company_domain : String, @api_key : String, @employee_id : String, @io : IO = STDOUT)
      @api = API.new(@company_domain, @api_key, @employee_id)
      @current_session_start = nil
      @daily_total_seconds = 0
      @update_channel = nil
      @last_daily_refresh = Time.local
    end

    def run_interactive
      @io.puts "🎯 BambooHR Time Tracker".colorize(:magenta).bold
      @io.puts "Company: #{@company_domain}".colorize(:light_gray)
      @io.puts "Employee ID: #{@employee_id}".colorize(:light_gray)
      @io.puts "─" * 50

      # Check initial status
      refresh_status

      # Start real-time updates if already clocked in
      if @current_session_start
        start_real_time_updates
      end

      loop do
        display_status

        # Wait for user input
        gets

        if @current_session_start
          # Don't stop updates until we successfully clock out
          success = clock_out
          if !success
            # Clock out failed, restart real-time updates
            start_real_time_updates
          end
        else
          if clock_in
            start_real_time_updates
          end
        end

        @io.puts
      end
    end

    def clock_in(note : String? = nil, project_id : Int32? = nil, task_id : Int32? = nil) : Bool
      @io.puts "🕐 Clocking in...".colorize(:yellow)

      success, entry = @api.clock_in(note, project_id, task_id)

      if success
        @current_session_start = Time.local
        if entry
          @io.puts "✅ Successfully clocked in at #{format_time(Time.local)} (Entry ID: #{entry.id})".colorize(:green)
        else
          @io.puts "✅ Successfully clocked in at #{format_time(Time.local)}".colorize(:green)
        end
        refresh_daily_total
        true
      else
        handle_api_error("clock in")
        false
      end
    end

    def clock_out : Bool
      @io.puts "🕐 Clocking out...".colorize(:yellow)

      success, entry = @api.clock_out

      if success
        if start_time = @current_session_start
          session_duration = Time.local - start_time
          if entry
            @io.puts "✅ Successfully clocked out at #{format_time(Time.local)} (Entry ID: #{entry.id})".colorize(:green)
          else
            @io.puts "✅ Successfully clocked out at #{format_time(Time.local)}".colorize(:green)
          end
          @io.puts "⏱️  Session duration: #{format_duration(session_duration.total_seconds.to_i)}".colorize(:cyan)
        else
          @io.puts "✅ Successfully clocked out at #{format_time(Time.local)}".colorize(:green)
        end

        # Only clear session and stop updates on successful clock out
        @current_session_start = nil
        stop_real_time_updates
        refresh_daily_total
        true
      else
        handle_api_error("clock out")
        # Don't clear session or stop updates on failure
        false
      end
    end

    def refresh_status
      success, session_start = @api.get_current_status

      if success
        @current_session_start = session_start
      else
        @io.puts "⚠️  Could not fetch clock status".colorize(:yellow)
      end

      refresh_daily_total
    end

    def refresh_daily_total
      today_str = Time.local.at_beginning_of_day.to_s("%Y-%m-%d")
      success, total_seconds = @api.get_daily_total(today_str)

      if success
        # Subtract current session time to avoid double counting
        if start_time = @current_session_start
          current_session_seconds = (Time.local - start_time).total_seconds.to_i
          @daily_total_seconds = total_seconds - current_session_seconds
        else
          @daily_total_seconds = total_seconds
        end
      end
    end

    def start_real_time_updates
      @update_channel = Channel(Bool).new(1)
      @last_daily_refresh = Time.local

      if channel = @update_channel
        spawn do
          loop do
            select
            when channel.receive?
              # Exit the refresh loop
              break
            when timeout(1.second)
              # Update display every second when clocked in
              if @current_session_start
                display_status_inline

                # Refresh daily total every 30 seconds
                if (Time.local - @last_daily_refresh).total_seconds > 30
                  refresh_daily_total
                  @last_daily_refresh = Time.local
                end
              end
            end
          end
        end
      end
    end

    def stop_real_time_updates
      if channel = @update_channel
        channel.send(true)
        @update_channel = nil
      end
    end

    def display_status
      unless @current_session_start
        status = "🔴 CLOCKED OUT"
        daily_info = "Daily total: #{format_duration(@daily_total_seconds)}"

        @io.puts "#{status.colorize(:red)} | #{daily_info.colorize(:blue)}"
      end

      @io.print "Press ENTER to #{@current_session_start ? "clock out" : "clock in"} (Ctrl+C to exit): "
    end

    def display_status_inline
      # Clear the current line and move cursor to beginning
      @io.print "\r\033[K"

      if start_time = @current_session_start
        current_session = (Time.local - start_time).total_seconds.to_i
        status = "🟢 CLOCKED IN"
        session_info = "Current session: #{format_duration(current_session)}"
        daily_info = "Daily total: #{format_duration(@daily_total_seconds + current_session)}"

        @io.print "#{status.colorize(:green)} | #{session_info.colorize(:cyan)} | #{daily_info.colorize(:blue)}"
        @io.print " | Press ENTER to clock out (Ctrl+C to exit): "
      else
        status = "🔴 CLOCKED OUT"
        daily_info = "Daily total: #{format_duration(@daily_total_seconds)}"

        @io.print "#{status.colorize(:red)} | #{daily_info.colorize(:blue)}"
        @io.print " | Press ENTER to clock in (Ctrl+C to exit): "
      end

      @io.flush
    end

    # Public accessors for testing
    def current_session_start
      @current_session_start
    end

    def daily_total_seconds
      @daily_total_seconds
    end

    def api
      @api
    end

    def cleanup
      stop_real_time_updates
    end

    private def handle_api_error(action : String)
      status_code = @api.get_last_response_status
      response_body = @api.get_last_response_body

      case status_code
      when 400
        @io.puts "❌ Bad request for #{action}: Invalid parameters".colorize(:red)
      when 401
        @io.puts "❌ Failed to #{action}: Invalid API credentials".colorize(:red)
      when 403
        @io.puts "❌ Failed to #{action}: Insufficient permissions or API access disabled".colorize(:red)
      when 406
        @io.puts "❌ Failed to #{action}: Request not acceptable".colorize(:red)
      when 409
        @io.puts "❌ Failed to #{action}: Conflict with current state".colorize(:red)
      when 500
        @io.puts "❌ Failed to #{action}: Server error".colorize(:red)
      else
        @io.puts "❌ Failed to #{action}: #{status_code} - #{response_body}".colorize(:red)
      end
    end

    private def format_time(time : Time) : String
      time.to_s("%H:%M:%S")
    end

    private def format_duration(seconds : Int32) : String
      hours = seconds // 3600
      minutes = (seconds % 3600) // 60

      if hours > 0
        "#{hours}h #{minutes}m"
      elsif minutes > 0
        "#{minutes}m"
      else
        "0m"
      end
    end
  end
end

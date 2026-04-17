require "colorize"
require "time"
require "./api"

module BambooHRCLI
  class CLI
    @api : API
    @current_session_start : Time?
    @daily_total_seconds : Int32
    @weekly_total_seconds : Int32
    @weekly_time_off_hours : Float32
    @hours_per_day : Int32
    @io : IO
    @update_channel : Channel(Bool)?
    @last_daily_refresh : Time

    # Caching properties to reduce API calls
    @cached_session_start : Time?
    @cached_daily_sessions : Int32
    @cached_weekly_sessions : Int32
    @cache_date : String?
    @last_status_check : Time?

    def initialize(@company_domain : String, @api_key : String, @employee_id : String, @hours_per_day : Int32 = 8, @io : IO = STDOUT)
      @api = API.new(@company_domain, @api_key, @employee_id)
      @current_session_start = nil
      @daily_total_seconds = 0
      @weekly_total_seconds = 0
      @weekly_time_off_hours = 0.0
      @update_channel = nil
      @last_daily_refresh = Time.local

      # Initialize cache
      @cached_session_start = nil
      @cached_daily_sessions = 0
      @cached_weekly_sessions = 0
      @cache_date = nil
      @last_status_check = nil
    end

    def run_interactive
      @io.puts "🎯 BambooHR Time Tracker".colorize(:magenta).bold
      @io.puts "Company: #{@company_domain}".colorize(:light_gray)
      @io.puts "Employee ID: #{@employee_id}".colorize(:light_gray)
      @io.puts "─" * 50

      # Force immediate refresh on startup (bypass cache)
      @io.puts "🔄 Fetching current status...".colorize(:cyan)
      force_refresh_status

      # Start real-time updates if already clocked in
      if @current_session_start
        start_real_time_updates
      end

      loop do
        display_status

        # Wait for user input
        input = gets

        # Skip any input that isn't exactly Enter (empty line)
        # Ctrl+C is handled separately by the Signal::INT trap
        # Ctrl+D and other inputs will be ignored
        if input.nil? || !input.strip.empty?
          # Either Ctrl+D was pressed or user entered text
          # Just continue the loop without taking any action
          next
        end

        if @current_session_start
          # Don't stop updates until we successfully clock out
          success = clock_out
          if !success
            # Clock out failed, restart real-time updates
            start_real_time_updates
          end
        else
          if clock_in
            # Force immediate refresh after clocking in
            force_immediate_refresh
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
        current_time = Time.local
        today_str = current_time.at_beginning_of_day.to_s("%Y-%m-%d")

        # Cache the session start time
        @current_session_start = current_time
        @cached_session_start = current_time
        @cache_date = today_str
        @last_status_check = current_time

        if entry
          @io.puts "✅ Successfully clocked in at #{format_time(current_time)} (Entry ID: #{entry.id})".colorize(:green)
        else
          @io.puts "✅ Successfully clocked in at #{format_time(current_time)}".colorize(:green)
        end

        # Use cached daily sessions if available, otherwise fetch fresh data
        if @cache_date == today_str && @cached_daily_sessions >= 0
          @io.puts "📋 Using cached daily sessions data".colorize(:cyan)
          @daily_total_seconds = @cached_daily_sessions
          @weekly_total_seconds = @cached_weekly_sessions
        else
          refresh_daily_total_with_cache
          refresh_weekly_total_with_cache
        end

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
        @cached_session_start = nil
        stop_real_time_updates

        # Force fresh daily total refresh to include the completed session
        @io.puts "🔄 Updating daily total...".colorize(:cyan)
        force_refresh_daily_total

        # Show updated daily total
        @io.puts "📊 Updated daily total: #{format_duration(@daily_total_seconds)}".colorize(:blue)

        true
      else
        handle_api_error("clock out")
        # Don't clear session or stop updates on failure
        false
      end
    end

    def force_refresh_status
      # Force fresh data from API, bypassing cache
      success, session_start = @api.get_current_status

      if success
        current_time = Time.local
        today_str = current_time.at_beginning_of_day.to_s("%Y-%m-%d")

        @current_session_start = session_start
        @cached_session_start = session_start
        @cache_date = today_str
        @last_status_check = current_time

        # Force refresh daily and weekly totals
        refresh_daily_total_with_cache
        refresh_weekly_total_with_cache
      else
        @io.puts "⚠️  Could not fetch clock status".colorize(:yellow)
        # Fall back to cached data if available
        if @cached_session_start && is_cache_valid_for_today?
          @io.puts "📋 Using cached session data due to API error".colorize(:yellow)
          @current_session_start = @cached_session_start
          @daily_total_seconds = @cached_daily_sessions
          @weekly_total_seconds = @cached_weekly_sessions
        end
      end
    end

    def force_immediate_refresh
      # Force an immediate display update after clock-in
      @io.puts "🔄 Refreshing status...".colorize(:cyan)

      # Update the last refresh time to force immediate refresh in real-time updates
      @last_daily_refresh = Time.local - 31.seconds

      # Display current status immediately
      if @current_session_start
        display_status_inline
        @io.puts # Add newline after inline display
      end
    end

    def refresh_status
      current_time = Time.local
      today_str = current_time.at_beginning_of_day.to_s("%Y-%m-%d")

      # Use cached data if available and recent (within 5 minutes)
      if @last_status_check && @cache_date == today_str &&
         (current_time - @last_status_check.not_nil!).total_minutes < 5
        @io.puts "📋 Using cached session data".colorize(:cyan)
        @current_session_start = @cached_session_start
        @daily_total_seconds = @cached_daily_sessions
        @weekly_total_seconds = @cached_weekly_sessions
        return
      end

      # Fetch fresh data from API
      success, session_start = @api.get_current_status

      if success
        @current_session_start = session_start
        @cached_session_start = session_start
        @cache_date = today_str
        @last_status_check = current_time

        # Cache the daily and weekly sessions
        refresh_daily_total_with_cache
        refresh_weekly_total_with_cache
      else
        @io.puts "⚠️  Could not fetch clock status".colorize(:yellow)
        # Fall back to cached data if available
        if @cached_session_start && @cache_date == today_str
          @io.puts "📋 Using cached session data due to API error".colorize(:yellow)
          @current_session_start = @cached_session_start
          @daily_total_seconds = @cached_daily_sessions
          @weekly_total_seconds = @cached_weekly_sessions
        end
      end
    end

    def force_refresh_daily_total
      # Force fresh daily total from API, bypassing cache
      today_str = Time.local.at_beginning_of_day.to_s("%Y-%m-%d")
      success, total_seconds = @api.get_daily_total(today_str)

      if success
        # Update both current and cached daily total
        @daily_total_seconds = total_seconds
        @cached_daily_sessions = total_seconds
        @cache_date = today_str
        @last_status_check = Time.local
      else
        @io.puts "⚠️  Could not fetch updated daily total".colorize(:yellow)
      end

      # Also refresh weekly total
      success_weekly, weekly_seconds = @api.get_weekly_total

      if success_weekly
        @weekly_total_seconds = weekly_seconds
        @cached_weekly_sessions = weekly_seconds
      end
    end

    def refresh_daily_total_with_cache
      today_str = Time.local.at_beginning_of_day.to_s("%Y-%m-%d")
      success, total_seconds = @api.get_daily_total(today_str)

      if success
        # Cache the completed daily sessions (excluding current session)
        if start_time = @current_session_start
          current_session_seconds = (Time.local - start_time).total_seconds.to_i
          @daily_total_seconds = total_seconds - current_session_seconds
          @cached_daily_sessions = @daily_total_seconds
        else
          @daily_total_seconds = total_seconds
          @cached_daily_sessions = total_seconds
        end
      end
    end

    def refresh_weekly_total_with_cache
      success, total_seconds = @api.get_weekly_total

      if success
        if start_time = @current_session_start
          current_session_seconds = (Time.local - start_time).total_seconds.to_i
          @weekly_total_seconds = total_seconds - current_session_seconds
          @cached_weekly_sessions = @weekly_total_seconds
        else
          @weekly_total_seconds = total_seconds
          @cached_weekly_sessions = total_seconds
        end
      end

      # Fetch time off for the week
      refresh_weekly_time_off
    end

    def refresh_weekly_time_off
      today = Time.local
      monday = today.at_beginning_of_week
      monday_str = monday.to_s("%Y-%m-%d")
      today_str = today.to_s("%Y-%m-%d")

      total_hours = 0.0_f32

      success, requests = @api.get_time_off_requests(monday_str, today_str)
      if success && requests
        requests.each do |request|
          status = request.status.status
          next unless status == "approved" || status == "requested"

          unit = request.amount.unit
          request.dates.each do |date_str, value_str|
            next unless date_str >= monday_str && date_str <= today_str
            value = value_str.to_f32?
            next unless value

            case unit
            when "days"  then total_hours += value * @hours_per_day
            when "hours" then total_hours += value
            end
          end
        end
      end

      _, holiday_dates = @api.get_holidays(monday_str, today_str)
      holiday_dates.each do |date_str|
        next unless date_str >= monday_str && date_str <= today_str
        total_hours += @hours_per_day
      end

      @weekly_time_off_hours = total_hours
    end

    def refresh_daily_total
      today_str = Time.local.at_beginning_of_day.to_s("%Y-%m-%d")

      # Use cached data if available and cache is for today
      if @cache_date == today_str && @cached_daily_sessions >= 0
        @daily_total_seconds = @cached_daily_sessions
        return
      end

      # Fetch fresh data if no cache available
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
          # Force immediate first update when starting real-time updates
          if @current_session_start
            @io.puts "🔄 Starting real-time updates...".colorize(:cyan)
            display_status_inline
            @io.puts # Add newline after inline display

            # Force refresh daily total on first update
            refresh_daily_total_with_cache
            @last_daily_refresh = Time.local
          end

          loop do
            select
            when channel.receive?
              # Exit the refresh loop
              break
            when timeout(30.seconds)
              # Real-time updates every 30 seconds when clocked in
              if @current_session_start
                display_status_inline

                # Refresh daily total every 30 seconds, but use cache when possible
                if (Time.local - @last_daily_refresh).total_seconds > 30
                  # Only fetch fresh data if cache is invalid or stale
                  if !is_cache_valid_for_today? ||
                     (@last_status_check && (Time.local - @last_status_check.not_nil!).total_minutes > 10)
                    refresh_daily_total_with_cache
                  else
                    # Use cached data for display
                    refresh_daily_total
                  end
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
        daily_info = "Daily: #{format_duration(@daily_total_seconds)}"
        weekly_info = "Weekly: #{format_duration(@weekly_total_seconds)}"
        time_off_info = @weekly_time_off_hours > 0 ? " | Time off: #{@weekly_time_off_hours}h" : ""

        @io.puts "#{status.colorize(:red)} | #{daily_info.colorize(:blue)} | #{weekly_info.colorize(:magenta)}#{time_off_info.colorize(:yellow)}"
      end

      @io.print "Press ENTER to #{@current_session_start ? "clock out" : "clock in"} (Ctrl+C to exit): "
    end

    def display_status_inline
      # Clear the current line and move cursor to beginning
      @io.print "\r\033[K"

      if start_time = @current_session_start
        current_session = (Time.local - start_time).total_seconds.to_i
        status = "🟢 CLOCKED IN"
        session_info = "Session: #{format_duration(current_session)}"
        daily_info = "Daily: #{format_duration(@daily_total_seconds + current_session)}"
        weekly_info = "Weekly: #{format_duration(@weekly_total_seconds + current_session)}"
        time_off_info = @weekly_time_off_hours > 0 ? " | Time off: #{@weekly_time_off_hours}h" : ""

        @io.print "#{status.colorize(:green)} | #{session_info.colorize(:cyan)} | #{daily_info.colorize(:blue)} | #{weekly_info.colorize(:magenta)}#{time_off_info.colorize(:yellow)}"
        @io.print " | Press ENTER to clock out (Ctrl+C to exit): "
      else
        status = "🔴 CLOCKED OUT"
        daily_info = "Daily: #{format_duration(@daily_total_seconds)}"
        weekly_info = "Weekly: #{format_duration(@weekly_total_seconds)}"
        time_off_info = @weekly_time_off_hours > 0 ? " | Time off: #{@weekly_time_off_hours}h" : ""

        @io.print "#{status.colorize(:red)} | #{daily_info.colorize(:blue)} | #{weekly_info.colorize(:magenta)}#{time_off_info.colorize(:yellow)}"
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

    def weekly_time_off_hours
      @weekly_time_off_hours
    end

    def api
      @api
    end

    # Cache status methods for testing and debugging
    def cached_session_start
      @cached_session_start
    end

    def cached_daily_sessions
      @cached_daily_sessions
    end

    def cache_date
      @cache_date
    end

    def is_cache_valid?
      is_cache_valid_for_today?
    end

    def cleanup
      stop_real_time_updates
      clear_cache
    end

    private def clear_cache
      @cached_session_start = nil
      @cached_daily_sessions = 0
      @cached_weekly_sessions = 0
      @cache_date = nil
      @last_status_check = nil
    end

    private def is_cache_valid_for_today? : Bool
      today_str = Time.local.at_beginning_of_day.to_s("%Y-%m-%d")
      @cache_date == today_str
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

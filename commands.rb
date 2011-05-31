require './show.rb'
require './random.rb'
require 'date'
require 'chronic_duration'
require 'ri_cal'

$domain = "http://5by5.tv"
$drphil = ["There's a genie for that.",
 "Everything's a bear.",
 "A beret will be fine.",
 "If you want to find the treasure you gotta buy the chest!",
 "You don't win at tennis by buying a bowling ball.",
 "If you live in a tree, don't be surprised that you're living with monkeys.",
 "Crush the Bunny.",
 "Doesn't matter how many Fords you buy, they're never gonna be a Dodge. You can repaint the Ford but... let's go to a break.",
 "You're not gonna get Black Lung from an excel spreadsheet.",
 "I'm not gonna euthanize this dog, I'm just gonna put it over here where I can't see it.",
 "Failure is the equivalent of existential sit-ups."]
$ical = "http://www.google.com/calendar/ical/fivebyfivestudios%40gmail.com/public/basic.ics"

# Class to define the possible irc commands
class Commands
  @@command_usage = {
    about: 'Who made this?',
    show: '!show show_name [episode_number]',
    links: '!links show_name episode_number',
    description: '!description show_name episode_number',
    suggest: '!suggest title_suggestion',
    suggestions: 'List all suggestions',
    next: '!next [show_name]'
  }

  def initialize(message, shows)
    @@admin_key ||= (0...8).map{65.+(rand(25)).chr}.join
    puts "Admin key is #{@@admin_key}"
    # IRC message object from cinch
    @message = message
    # Shows is a class variable since it shouldn't change while the bot is running
    @@shows ||= shows
    @@suggested_titles ||= []

    @@refresh_thread ||= Thread.new do 
      until false
        puts "Refreshing calendar cache"
        @@calendar_cache = RiCal.parse(open($ical))
        puts "Sleeping 10 minutes until next refresh"
        sleep 600
      end
    end
  end

  def get_show(show_string)
    if show_string
      @@shows.each do |show|
        if show.url.downcase == show_string.downcase
          return show
        elsif show.title.downcase.include? show_string.downcase
          return show
        end
      end
    end
    return nil
  end

  def usage(command="")
    if command
      return "Usage: #{@@command_usage[command.to_sym]}"
    end
  end
  #
  # Prints text without replying to user who issued command
  def chat(text)
    if text and text.strip != ""
      if @message
        #@message.user.send text
        @message.reply text
      else
        # Debug mode
        puts text
      end
    end
  end

  # Prints text and replies to user who issued the command
  def reply(text)
    if text and text.strip != ""
      if @message
        @message.user.send text
      else
        # Debug mode
        chat("Reply: #{text}")
      end
    end
  end


  def run(command, args)
    real_command = "command_#{command}"
    if self.respond_to? real_command
      self.send(real_command, args)
    else
      puts "Unrecognized command #{command}"
    end
  end

  def show_error(show, show_number)
    if show_number == 1
      reply("#{show.title} only has #{show.show_count} episode.")
    else
      reply("#{show.title} only has #{show.show_count} episodes.")
    end
  end

  def admin_key
    return @@admin_key
  end
  
  # --------------
  # Regular Commands
  # --------------
  
  def command_commands(args = [])
    reply("Available commands:")
    @@command_usage.each_pair do |command, usage|
      reply("  !#{command} - #{usage}")
    end
  end

  def command_about(args = [])
    reply("Showbot was created by Jeremy Mack (@mutewinter) and some awesome contributors on github. The project page is located at https://github.com/mutewinter/Showbot")
    reply("Type !commands for showbot's commands")
  end

  # Alias for the about command
  def command_showbot(args = [])
    command_about(args)
  end

  def command_next(args = [])
    # Just in case the thread above hasn't run yet
    @@calendar_cache ||= RiCal.parse(open($ical))
    show = get_show(args.first) if args.length > 0

    nearest_event = nil
    nearest_seconds_until = nil
    @@calendar_cache.first.events.each do |event|
      # Grab the next occurrence for the event
      event = (event.occurrences({:starting => Date.today, :count => 1})).first
      
      if event and event.start_time > DateTime.now
        seconds_until = ((event.start_time - DateTime.now) * 24 * 60 * 60).to_i
        summary = event.summary
        if show and get_show(summary.downcase) == show
          if !nearest_seconds_until
            nearest_seconds_until = seconds_until
            nearest_event = event
          elsif seconds_until < nearest_seconds_until
            nearest_seconds_until = seconds_until
            nearest_event = event
          end
        elsif !show
          if !nearest_seconds_until
            nearest_seconds_until = seconds_until
            nearest_event = event
          elsif seconds_until < nearest_seconds_until
            nearest_seconds_until = seconds_until
            nearest_event = event
          end
        end
      end
    end

    if nearest_event
      date_string = nearest_event.start_time.strftime("%m/%d/%Y")
      if show
        reply("The next #{nearest_event.summary} is in #{ChronicDuration.output(nearest_seconds_until, :format => :long)} (#{date_string})")
      else 
        reply("Next show is #{nearest_event.summary} in #{ChronicDuration.output(nearest_seconds_until, :format => :long)} (#{date_string})")
      end
    else
      reply("No upcoming show found for #{show.title}")
    end

  end

  def command_exit(args = [])
    if args.first == @@admin_key
      reply("Showbot is shutting down. Good bye :(")
      Process.exit
    else
      puts "Invalid admin key #{args.first}, should be #{@@admin_key}"
    end
  end

  # --------------
  # Show Commands
  # --------------
  
  def command_show(args = [])
    show = get_show(args.first)

    if show
      show_number = args[1] if args.length > 1
      if show_number != "next" and !show.valid_show?(show_number)
        show_error(show, show_number)
      elsif show_number
        reply("#{$domain}/#{show.url}/#{show_number}")
      else
        reply("#{$domain}/#{show.url}")
      end
    else
      reply("No show by name \"#{args.first}\". You dissappoint.")
      reply(usage("show"))
    end
  end

  def command_links(args = [])
    if args.length < 2
      reply(usage("links"))
    else
      show = get_show(args.first)
      show_number = args[1]

      if show and show_number and show_number.strip != ""
        if show.valid_show?(show_number)
          reply(show.links(show_number).join("\n"))
        else
          show_error(show, show_number)
        end
      else
        reply(usage("links"))
      end
    end
  end

  def command_description(args = [])
    if args.length < 2
      reply(usage("description"))
    else
      show = get_show(args.first)
      show_number = args[1].strip

      if show
        if show_number and show.valid_show?(show_number)
          reply(show.description(show_number))
        elsif show_number and show_number != ""
          show_error(show, show_number)
        end
      else
        reply(usage("description"))
      end
    end
  end
    
  # --------------
  # Suggestion Commands
  # --------------

  def command_suggest(args = [])
    suggestion = args.first.strip if args.length > 0
    if suggestion and suggestion != ""
      if @message
        @@suggested_titles.push "#{suggestion} (#{@message.user.nick})"
      else
        @@suggested_titles.push suggestion
      end
      reply("Added title suggestion \"#{suggestion}\"")
    else
      reply(usage("suggest"))
    end
  end

  def command_suggestions(args = [])
    if @@suggested_titles.length == 0
      reply('There are no suggestions. You should add some by using "!suggest title_suggestion".')
    else
      reply("#{@@suggested_titles.length} titles so far:\n")
      reply(@@suggested_titles.join("\n"))
    end
  end

  def command_clear(args = [])
    if args.first == @@admin_key
      if @@suggested_titles.length == 1
        reply("Clearing 1 title suggestion.")
      elsif @@suggested_titles.length == 0
        reply("There are no suggestions to clear. You can start adding some by using \"!suggest title_suggestion\".")
      else
        # Printing current suggestions so they aren't lost due to a malicious !clear
        reply("Clearing #{@@suggested_titles.length} title suggestions.")
      end
      @@suggested_titles.clear
    else
      puts "Invalid admin key #{args.first}, should be #{@@admin_key}"
    end
  end

  # --------------
  # Fun commands
  # --------------

  def command_stopfailing(args = [])
    chat("no.")
  end

  def command_merlin(args = [])
    chat("SO angry.")
  end

  def command_drphil(args = [])
    chat("From the wise Mr. Mann: \"#{$drphil.random}\".")
  end

end

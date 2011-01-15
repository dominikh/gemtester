require "cinch"
require "json"
require "open-uri"

class GemResults
  Version = Struct.new(:number, :failed, :successful)

  def initialize(name)
    @name = name
  end

  def versions
    return @versions if @versions

    reports = json["rubygem"]

    versions = []
    reports["versions"].each { |version|
      results = version["test_results"].map {|result| result["result"]}
      versions << Version.new(version["number"], results.count(false), results.count(true))
    }

    @versions = versions
  end

  def json
    @json ||= open("http://www.gem-testers.org/gems/#{@name}.json") { |f| JSON.load(f.read) }
  end

  def found?
    !json.empty?
  end
end

class GemTester
  include Cinch::Plugin
  AnnounceMessage = "In the last 60 minutes, %d passing and %d failing test results for ? different gems have been submitted."

  match "announce", method: :announce_new_tests
  timer 60*60, method: :announce_new_tests
  def announce_new_tests(m = nil)
    open("http://www.gem-testers.org/test_results.json") do |f|
      json = JSON.load(f.read)
      return if json["pass_count"] + json["fail_count"] == 0 && m.nil?
      Channel(config[:channel]).send AnnounceMessage % [json["pass_count"], json["fail_count"]]
      # TODO infos on how many different games
    end
  end

  match(/check (.+)/, method: :check_tests)
  def check_tests(m, name)
    # TODO use total_successes and total_fails as soon as available
    gem = GemResults.new(name)
    if !gem.found?
      m.reply "No gem named '#{name}' found."
      return
    end

    versions = gem.versions.sort_by {|v| v.number}.reverse
    s = versions[0..2].map { |version| "[%s %s] %d failed / %d successful" % [name, version.number, version.failed, version.successful] }

    remaining = versions.size - 3
    s << "[#{name}] #{remaining} more versions..." if remaining > 0

    m.reply s.join("\n")
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.freenode.net"
    c.nick = "gemtester"
    c.channels = ["#gem-testers"]
    c.plugins.plugins = [GemTester]
    c.plugins.options[GemTester][:channel] = "#gem-testers"
  end
end

trap("INT") do
  bot.quit "Bot has been killed."
end

bot.start

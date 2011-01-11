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

  timer 60, method: :announce_new_tests
  def announce_new_tests
    # - get new tests
    # - announce them
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
    c.channels = ["#dominikh"]
    c.plugins.plugins = [GemTester]
  end

  # TODO remove this, it's only for testing
  on(:message, /^!join (.+)/) do |m, channel|
    if m.user.authname == "DominikH"
      Channel(channel).join
    end
  end
end


bot.start

require "heroku/command"
require "rest_client"

# devcenter documentation
class Heroku::Command::Man < Heroku::Command::Base

  # man TOPIC
  #
  # get devcenter documentation on a TOPIC
  #
  # -k, --keyword KEYWORD  # search the devcenter for KEYWORD
  #
  def index
    if topic = options[:keyword]
      display "Articles matching #{topic}:"
      display
      search(options[:keyword])
      return
    end

    raise Heroku::Command::CommandFailed, "usage: heroku man TOPIC" unless topic = args.first

    groff = "groff -Wall -mtty-char -mandoc -Tascii"
    pager = ENV['MANPAGER'] || ENV['PAGER'] || 'more'

    article = devcenter["/articles/#{topic}.man"].get.to_s

    rd, wr = IO.pipe

    if pid = fork
      rd.close
      wr.puts article
      wr.close
      Process.wait
    else
      wr.close
      STDIN.reopen rd
      exec "#{groff} | #{pager}"
    end
  rescue RestClient::ResourceNotFound
    display "No article found named #{topic}. Perhaps try one of these?"
    display
    search(topic)
  end

private

  def devcenter
    RestClient::Resource.new("http://devcenter.heroku.com")
  end

  def search(topic)
    results = json_decode(devcenter["/articles.json?q=#{topic}"].get.to_s)["devcenter"]
    results.reject! { |r| r["article"]["slug"].length > 20 }
    if results.length == 0
      display "No articles found."
    else
      longest = results.map { |r| r["article"]["slug"].length }.sort.last
      results.sort_by { |r| r["article"]["slug"] }.each do |result|
        display "%-#{longest}s  # %s" % [ result["article"]["slug"], result["article"]["title"] ]
      end
    end
  end

end

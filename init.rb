begin
  require "rest_client"
  require "ronn/document"
  require "tmpdir"
rescue LoadError
  puts " !  heroku-man requires the 'ronn' gem. Please install it to activate this plugin."
end

# devcenter documentation
class Heroku::Command::Man < Heroku::Command::Base

  # man TOPIC
  #
  # get devcenter documentation on a TOPIC
  #
  def index
    raise CommandFailed, "usage: heroku man TOPIC" unless topic = args.first

    response = devcenter["/articles/#{topic}.md"].get
    article = response.to_s

    article.gsub!(/:::.+\n/, '')

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p dir
      File.open("#{dir}/#{topic}.md", "w") { |f| f.puts article }

      groff = "groff -Wall -mtty-char -mandoc -Tascii"
      pager = ENV['MANPAGER'] || ENV['PAGER'] || 'more'

      ronn_options = options = {
        "styles" => %w( man ),
        "date" => Date.parse(response.headers[:last_modified])
      }

      doc = Ronn::Document.new("#{dir}/#{topic}.md", ronn_options)
      man = doc.convert("roff")

      rd, wr = IO.pipe

      if pid = fork
        rd.close
        wr.puts man
        wr.close
        Process.wait
      else
        wr.close
        STDIN.reopen rd
        exec "#{groff} | #{pager}"
      end
    end
  rescue RestClient::ResourceNotFound
    results = json_decode(devcenter["/articles.json?q=#{topic}"].get.to_s)["devcenter"]
    results.reject! { |r| r["article"]["slug"].length > 20 }
    display "No article found named #{topic}. Perhaps try one of these?"
    display
    longest = results.map { |r| r["article"]["slug"].length }.sort.last
    results.sort_by { |r| r["article"]["slug"] }.each do |result|
      display "%-#{longest}s  # %s" % [ result["article"]["slug"], result["article"]["title"] ]
    end
  end

private

  def devcenter
    RestClient::Resource.new("http://devcenter.heroku.com")
  end

end

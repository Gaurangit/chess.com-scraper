require "chess_com/version"
require 'virtus'
require 'nokogiri'
require 'faraday'

module ChessCom

  def select_if_match(links, match)
    # http://www.chess.com/members/view/sergioK#games
    links.select { |l| l.attribute('href').to_s =~ match }
    .map { |link| yield link.attribute('href'), "" }
  end

  module_function :select_if_match

  class DefaultClient
    def initialize 
      @conn = Faraday.new
    end
    def get url
      (@conn.get url).body
    end
  end

  class Game
    include Virtus
    attribute :game_id, String
    def pgn_url
      "echess/download_pgn?lid=#{game_id}"
    end
  end

  class GameListing
    include Virtus
    attribute :games, Array[Game], default: []
    attribute :pages, Array[Integer], default: []
    attribute :players, Array[String], default: []
    attr_reader :username
    attr_reader :page

    def initialize (username: (raise ArgumentError, "username must be provided"),
                    page: 1, client: DefaultClient.new)
      @username = username
      @page = page
      html = client.get(listing_url username, page)
      doc = Nokogiri::HTML html
      links = doc.css 'a'
      @games = links
      .select { |link| link.attribute('href').to_s =~ /game\?id=/ }
      .map do |link| 
        href = link.attribute('href').to_s
        game_id = /game\?id=(?<game_id>\d+)/.match(href)[:game_id]
        Game.new(game_id: game_id)
      end
      @pages = links
      .select { |l| l.attribute('href').to_s =~ /game_archive\?.+&page=\d+/}
      .map do |link|
        href = link.attribute('href').to_s
        page_number = /game_archive\?.+\&page=(?<page>\d+)/.match(href)[:page]
        page_number.to_i
      end.reject { |x| x == page }
      .uniq.reject { |p| p == page}
      @players = ChessCom.select_if_match links,
        /members\/view\/.+#games$/ do |href, text|
        # or just use text here
        /members\/view\/(?<user>.+)#games$/.match(href)[:user]
      end.uniq.reject {|x| x == @username}
    end

    def listing_url user, page
      "http://www.chess.com/home/game_archive?" + 
        "sortby=&show=live&member=#{user}&page=#{page}"
    end
  end
end

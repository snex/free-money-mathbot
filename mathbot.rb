require 'slack-ruby-bot'

class Player
  attr_accessor :buy_in, :cash_out

  def initialize buy_in
    @buy_in = buy_in
    @cash_out = 0
  end

  def add_on amount
    @buy_in += amount
  end

  def cash_out cash_out
    @cash_out = cash_out
  end

  def profit
    @cash_out - @buy_in
  end
end

class Settlement
  attr_accessor :from, :to, :amount

  def initialize from, to, amount
  end
end

class Game
  attr_accessor :players, :settlements

  def initialize
    @players = {}
    @settlements = {}
    @players_to_settle = []
  end

  def add_player name, amount
    if @players.has_key?(name)
      @players[name].add_on(amount)
    else
      @players[name] = Player.new(amount)
    end
  end

  def cashout name, amount
    player = @players.fetch(name)
    player.cash_out(amount)
    profit = player.profit
    @players_to_settle << { 'player' => name, 'amount' => profit }
    @players.delete(name)
    return profit
  end

  def can_end?
    @players.map {|k,v| v.profit}.inject(0) { |sum, p| sum + p } == 0
  end

  def end_game
  end
end

class MathBot < SlackRubyBot::Bot

  attr_accessor :game

  command 'start' do |client, data, match|
    if !@game.nil?
      client.say(text: 'game has already started', channel: data.channel)
    else
      client.say(text: 'new game started. have players set their amounts with the add command.', channel: data.channel)
      @game = Game.new
    end
  end

  command 'end' do |client, data, match|
    if @game.nil?
      client.say(text: 'no game in progress', channel: data.channel)
    else
      if @game.can_end?
        client.say(text: 'game ended', channel: data.channel)
        @game.end_game
        @game = nil
      else
        client.say(text: 'game cannot end, buy ins dont match cash outs', channel: data.channel)
      end
    end
  end

  match /^(?<bot>\w*):\sadd (?<amount>\d+)$/ do |client, data, match|
    user = "<@#{data.user}>"
    if @game.nil?
      client.say(text: 'no game in progress', channel: data.channel)
    else
      @game.add_player(user, match[:amount].to_i)
      client.say(text: "#{match[:amount]} added to #{user}'s amount, total is #{@game.players[user].buy_in}",
                 channel: data.channel)
    end
  end

  match /^(?<bot>\w*):\scashout (?<amount>\d+)$/ do |client, data, match|
    user = "<@#{data.user}>"
    if @game.nil?
      client.say(text: 'no game in progress', channel: data.channel)
    else
      begin
        profit = @game.cashout(user, match[:amount].to_i)
        client.say(text: "#{user} cashes out with #{match[:amount]} for a profit of #{profit}",
                   channel: data.channel)
      rescue KeyError => e
        client.say(text: "#{user}, you have to buy in first with the add command", channel: data.channel)
      end
    end
  end
end

MathBot.run

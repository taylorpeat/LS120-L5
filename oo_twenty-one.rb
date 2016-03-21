module BlackjackConstants
  BLACKJACK = 21
  MID_SCREEN = 45
  MINIMUM_TOTAL = 17
  HIGH_ACE = 11
  REDUCE_ACE = 10

end

module Hand
  include BlackjackConstants
  attr_accessor :cards, :hand_lines, :active, :result, :hand_value

  def initialize
    @cards = []
    @hand_lines = ['','','','','','','','','']
    @active = true
    @hand_value = 0
    @result = nil
  end

  def add_cards(new_cards)
    cards.unshift(new_cards).flatten!
    calculate_hand_value
  end

  def calculate_hand_value
    self.hand_value = cards.reduce(0) {|sum, card| sum + card.value }
    self.hand_value -= REDUCE_ACE if reduce_ace_card_value_attribute
    self.active = false if hand_value >= BLACKJACK
  end

  def reduce_ace_card_value_attribute
    ace = cards.select { |card| card.value == HIGH_ACE }
    ace[0].value -= REDUCE_ACE if ace[0] && hand_value > BLACKJACK
  end

  def compile_hand_lines(player_hands, dealer_hand, sliding_status, hide_dealer_card)
    hand_lines.map! { |line| line = '' }
    cards.each_with_index do |current_card, idx|
      if current_card == dealer_hand.cards[0] && hide_dealer_card
        add_card_lines_to_hand_lines(Dealer::BLANK_CARD, idx, sliding_status)
      else
        add_card_lines_to_hand_lines(current_card.card_lines, idx, sliding_status)
      end
    end
  end

  def add_card_lines_to_hand_lines(card_lines, idx, sliding_status)
    9.times do |i|
      if sliding_status
        if idx == 0
          hand_lines[i].insert(0, card_lines[i])
        elsif idx == 1
          hand_lines[i].insert(0, card_lines[i].slice(0..sliding_status))
        else
          hand_lines[i].insert(0, card_lines[i].slice(0..2))
        end
      else
        hand_lines[i].insert(0, idx < 2 ? card_lines[i] : card_lines[i].slice(0..2))
      end
    end
  end

  alias reset initialize

end


class Card
  attr_reader :suit, :card_lines
  attr_accessor :value, :card_name

  def initialize(card_values)
    @suit = card_values[0]
    @card_name = card_values[1]
    @value = card_values[2]
    @card_lines = compile_card_lines
  end

  def compile_card_lines
    symbols = update_card_symbols
    c_lines = []
    c_lines << " _________ "
    c_lines << "|#{card_name}#{symbols[8]}#{symbols[5]}   #{symbols[5]}  |"
    c_lines << "|#{symbols[0]} #{symbols[3]} #{symbols[7]} #{symbols[3]}  |"
    c_lines << "|  #{symbols[2]} #{symbols[4]} #{symbols[2]}  |"
    c_lines << "|  #{symbols[3]} #{symbols[6]} #{symbols[3]}  |"
    c_lines << "|  #{symbols[2]} #{symbols[1]} #{symbols[2]}  |"
    c_lines << "|  #{symbols[3]} #{symbols[7]} #{symbols[3]} #{symbols[0]}|"
    c_lines << "|  #{symbols[5]}   #{symbols[5]}#{symbols[8]}#{card_name}|"
    c_lines << " --------- "
    c_lines
  end

  def update_card_symbols
    suit_symbol = determine_suit_symbol
    case card_name
    when "2" then c2 = c7 = suit_symbol
    when "3" then c9 = c10 = suit_symbol
    when "4" then c4 = suit_symbol
    when "5" then c4 = c9 = suit_symbol
    when "6" then c6 = suit_symbol
    when "7" then c6 = c7 = suit_symbol
    when "8" then c4 = c8 = suit_symbol
    when "9" then c4 = c8 = c9 = suit_symbol
    when "10"
      c4 = c8 = c10 = suit_symbol
      n10 = ""
    when "J", "Q", "K", "A" then c9 = suit_symbol
    end
    [suit_symbol, c2, c4, c6, c7, c8, c9, c10, n10].map! { |symbol| symbol ||= " " }
  end

  def determine_suit_symbol
    case suit
    when :spades then "\u2660"
    when :clubs then "\u2663"
    when :hearts then "\u2665"
    when :diamonds then "\u2666"
    end
  end

end


class Deck
  SUITS = %i(spades clubs hearts diamonds)
  VALUES = [["2", 2], ["3", 3], ["4", 4], ["5", 5], ["6", 6], ["7", 7], ["8", 8], ["9", 9],
          ["10", 10], ["J", 10], ["Q", 10], ["K", 10], ["A", 11]]
  
  attr_reader :cards

  def initialize
    @cards = create_deck
  end

  def create_deck
    deck = SUITS.product(VALUES).each { |card| card.flatten! }.map!\
           { |card_values| Card.new(card_values) }
    deck.shuffle!
  end

  def deal_cards(num_cards)
    @cards.pop(num_cards)
  end

  def reset
    initialize
  end

end


class Player
  include Hand

  attr_reader :name
  attr_accessor :balance, :wager

  def initialize(player_name)
    @name = player_name
    @balance = 100
    @wager = 0
    super()
  end

end


class SplitHand
  include Hand
  
  attr_accessor :wager

  def initialize(wager)
    @wager = wager
    super()
  end
end


class Dealer
  include Hand
  
  BLANK_CARD = [
                " _________ ", 
                "|/ / / / /|",
                "| / / / / |",
                "|/ / / / /|",
                "| / / / / |",
                "|/ / / / /|",
                "| / / / / |",
                "|/ / / / /|",
                " --------- "]

end


class Game
  include BlackjackConstants

  attr_reader :player, :dealer, :deck
  attr_accessor :current_player, :player_hands, :sliding_status

  def initialize
    @player = Player.new(get_name)
    @current_player = nil
    @player_hands = [player]
    @dealer = Dealer.new
    @deck = Deck.new
    @sliding_status = false
  end

  def get_name
    loop do 
      clear_screen
      puts "Welcome to Tealeaf Blackjack"
      print "\nPlease enter your name: "
      new_name = gets.chomp
      return new_name unless new_name == ""
    end
  end

  def play
    loop do
      initial_game_setup
      players_turn
      dealers_turn
      results_message
      update_balance
      break unless replay?
      setup_new_round
    end
    final_message
  end

  def initial_game_setup
    get_wager
    deal_initial_cards
    update_display
  end

  def deal_initial_cards
    player.add_cards(deck.deal_cards(2))
    dealer.add_cards(deck.deal_cards(2))
  end

  def get_wager
    clear_screen
    display_top_line   
    print "\nHow much would you like to wager: "
    receive_wager_input
  end

  def receive_wager_input
    player.wager = gets.chomp.to_i
    loop do  
      if valid_wager?
        player.balance -= player.wager
        break
      end
      print "\nThat wager is invalid. Please re-enter a valid wager:"
      player.wager = gets.chomp.to_i
    end
  end

  def valid_wager?
    (1..player.balance).include?(player.wager)
  end

  def players_turn
    loop do  
      break if hands_completed?
      update_each_player_hand
    end
  end

  def hands_completed?
    if dealer.hand_value == BLACKJACK || 
       player_hands.all? { |hand| !hand.active || hand.hand_value >= BLACKJACK }
       player_hands.each { |hand| hand.active = false }
       self.current_player = nil
       true
    end     
  end

  def update_each_player_hand
    player_hands.select {|hand| hand.active }.each do |current_player_object|
      self.current_player = current_player_object
      update_display
      update_player_hand
    end
  end

  def update_player_hand
    valid_plays = determine_valid_plays
    print "\nPlease select an option"
    print player_hands.size > 1 ? " for hand ##{player_hands.index(current_player) + 1}: " : ": "
    valid_plays.each {|choice| print choice + " " }
    puts
    send get_valid_decision(valid_plays)
  end

  def determine_valid_plays
    valid_plays = %w(Hit Stand)
    if current_player.cards.length == 2 &&
       current_player.cards.all? do |card|
         card.card_name == current_player.cards.first.card_name
       end &&
       player.balance > current_player.wager && player_hands.size < 4
      valid_plays << "Split"
    end
    if current_player.cards.length == 2 && player.balance > current_player.wager
      valid_plays << "Double" 
    end
    valid_plays
  end

  def get_valid_decision(valid_plays)
    decision = gets.chomp
    loop do
      if valid_plays.include?(decision.capitalize)
        return decision.downcase
      else
        print "\nThat is not a valid option. Please re-enter your selection: "
        decision = gets.chomp
      end
    end
  end

  def stand
    current_player.active = false
  end

  def hit(player_to_hit = current_player)
    slide_card_over
    player_to_hit.add_cards(deck.deal_cards(1))
    update_display
  end

  def slide_card_over
    (2..11).reverse_each do |x|
      self.sliding_status = x
      sleep 1.0 / 15
      update_display
    end
    self.sliding_status = false
  end

  def double
    hit
    stand
    player.balance -= current_player.wager
    current_player.wager *= 2
  end

  def split
    player_hands << SplitHand.new(current_player.wager)
    player_hands.last.cards << current_player.cards.pop
    current_player.cards.first.value = HIGH_ACE if current_player.cards.first.value == 1
    hit
    sleep 1.0 / 2
    player.balance -= current_player.wager
    self.current_player = player_hands.last
    hit
    sleep 1.0 /2
  end

  def dealers_turn
    loop do
      update_display
      break if never_reveal_dealer_card? 
      sleep 1
      hit(dealer)
    end
  end

  def never_reveal_dealer_card?
    player_hands.all? { |hand| hand.hand_value > BLACKJACK } ||
    player_hands.all? { |hand| hand.hand_value == BLACKJACK && hand.cards.length == 2} &&
    dealer.hand_value < BLACKJACK || dealer.hand_value >= MINIMUM_TOTAL
  end

  def results_message
    sleep 1
    assign_results_to_hands
    display_results_message
  end

  def assign_results_to_hands
    player_hands.each do |hand|
      if hand.hand_value <= BLACKJACK && dealer.hand_value < hand.hand_value ||
         dealer.hand_value > BLACKJACK && hand.hand_value <= BLACKJACK ||
         hand.hand_value == BLACKJACK && hand.cards.size == 2 && dealer.cards.size > 2
        hand.result = :won
      elsif hand.hand_value == dealer.hand_value &&
            !(hand.cards.size > 2 && dealer.cards.size == 2 && dealer.hand_value == BLACKJACK)
        hand.result = :tie
      else
        hand.result = :lost
      end
    end
  end

  def display_results_message
    print "\n\n"
    if player_hands.size == 1
      puts select_results_message(player) + "."
      display_balance_change(player)
    else
      player_hands.each_with_index do |hand, hand_num|
        print select_results_message(hand)
        puts " on hand ##{hand_num + 1}."
        display_balance_change(hand)
        puts
        sleep 1
      end
    end
  end

  def select_results_message(hand)
    if hand.result == :won
      winning_message(hand)
    elsif hand.result == :lost
      losing_message(hand)
    else
      "It's a push. You tied the dealer with #{hand.hand_value}"
    end
  end

  def winning_message(hand)
    if hand.hand_value == BLACKJACK && hand.cards.size == 2
      "Congratulations #{player.name}! You got blackjack"
    elsif dealer.hand_value <= BLACKJACK
      "Congratulations #{player.name}! You beat the dealer #{hand.hand_value}"\
      " to #{dealer.hand_value}"
    else
      "Congratulations #{player.name}! The dealer busted"
    end
  end

  def losing_message(hand)
    if hand.hand_value > BLACKJACK
      "You busted"
    else
      "Sorry. You lost to the dealer #{dealer.hand_value} to #{hand.hand_value}"
    end
  end

  def display_balance_change(hand)
    sleep 1
    puts
    if hand.hand_value == BLACKJACK && hand.result == :won && hand.cards.size == 2
      puts "You won $#{(hand.wager * 1.5).to_i}!!"
    elsif hand.result == :won
      puts "You won $#{hand.wager}!"
    elsif hand.result == :lost
      puts "You lost $#{hand.wager}."
    end
  end

  def update_balance
    player_hands.each do |hand|
      if hand.result == :won && hand.hand_value == BLACKJACK && hand.cards.length == 2
        player.balance += (hand.wager * 2.5).to_i
      elsif hand.result == :won
        player.balance += hand.wager * 2
      elsif hand.result == :tie
        player.balance += hand.wager
      end
    end
  end

  def replay?
    sleep 1
    return false if player.balance == 0 || !(1..999).include?(player.balance) 
    puts "\nEnter 'y' if you would like to play another hand."
    gets.chomp.downcase == 'y'
  end

  def setup_new_round
    player.send(:reset)
    dealer.send(:reset)
    deck.reset
    self.player_hands = [player]
  end

  def update_display
    clear_screen
    display_top_line
    player_hands.each_with_index do |hand, hand_num|
      display_card_labels(hand, hand_num)
      display_cards(hand)
      display_card_totals(hand, hand_num)
    end
  end

  def display_top_line
    puts "Balance: $#{player.balance}" + " " * (MID_SCREEN - "Balance: $#{player.balance}".length\
         - "--TEALEAF BLACKJACK--".length / 2) + "--TEALEAF BLACKJACK--"
  end

  def display_card_labels(hand, hand_num)
    puts "-" * MID_SCREEN * 2
    puts "Wager:   $#{hand.wager}"
    label_line = player_hands.size == 1 ? "\nPlayer Cards:" : "\nHand ##{hand_num + 1} Cards:"
    label_line += " <---" if hand == current_player
    label_line += hand == player ? " " * (MID_SCREEN - label_line.length + 1) + "Dealer Cards:" : ""
    puts label_line
  end
 
  def display_cards(hand)
    compile_hand_lines(hand)
    player_hand_width = hand.hand_lines[1].length
    9.times do |i|
      print hand.hand_lines[i]
      puts hand == player ? " " * (MID_SCREEN - player_hand_width) + dealer.hand_lines[i] : ""
    end
  end

  def display_card_totals(hand, hand_num)
    total_line = player_card_totals(hand, hand_num)
    total_line += " " * (MID_SCREEN - total_line.length + 1)
    total_line += hand == player ? dealer_card_totals : ""
    puts total_line
  end

  def player_card_totals(hand, hand_num)
    if player_hands.size == 1
      "\nPlayer Total: #{hand.hand_value}"
    else
      "\nHand ##{hand_num + 1} Total: #{hand.hand_value}"
    end
  end

  def dealer_card_totals
    if hide_dealer_card?
      "Dealer Total: #{dealer.cards[1].value}"
    else
      "Dealer Total: #{dealer.hand_value}"
    end
  end

  def compile_hand_lines(hand)
    player_sliding = dealer_sliding = false
    if hand.active && hand == current_player && hand.cards.size > 1
      player_sliding = sliding_status
    elsif player_hands.all? { |each_hand| !each_hand.active } && !hide_dealer_card?
      dealer_sliding = sliding_status
    end
    hand.compile_hand_lines(player_hands, dealer, player_sliding, false)
    if hand == player
      dealer.compile_hand_lines(player_hands, dealer, dealer_sliding, hide_dealer_card?)
    end
  end

  def hide_dealer_card?
    player_hands.any? { |hand| hand.active } ||
    player_hands.all? { |hand| hand.hand_value > BLACKJACK } || 
    player_hands.all? { |hand| hand.hand_value == BLACKJACK && hand.cards.length == 2} &&
    dealer.cards[1].value < 10
  end

  def clear_screen
    system 'clear' or system 'cls'
  end

   def final_message
    sleep 1
    if player.balance >= 1000
      puts "\nYour balance has reached $1000! You have been banned from Tealeaf Casinos."
    elsif player.balance == 0
      puts "\nYou have lost all of your money."
    else
      puts "\nYou have finished with $#{player.balance}"
    end
    sleep 1
    puts "\nGoodbye.\n\n\n"
    sleep 1
  end

end

Game.new.play


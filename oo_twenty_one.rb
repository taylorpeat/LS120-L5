module BlackjackConstants
  MAX_TOTAL = 21
  MIN_TOTAL = 17
  HIGH_ACE = 11
end

module Displayable # Displays current statistics and card images
  MID_SCREEN = 45

  private

  attr_accessor :slide_position

  def update_display
    clear_screen
    display_top_line
    player.hands.each_with_index do |hand, hand_num|
      display_card_labels(hand, hand_num)
      display_cards(hand)
      display_card_totals(hand, hand_num)
    end
  end

  def display_top_line
    puts "Balance: $#{player.balance}" + ' ' * (MID_SCREEN - "Balance: $#{player.balance}".length\
         - '--LAUNCH SCHOOL BLACKJACK--'.length / 2) + '--LAUNCH SCHOOL BLACKJACK--'
  end

  def slide_card_over
    (2..11).reverse_each do |i|
      self.slide_position = i
      sleep 1.0 / 15
      update_display
    end
    self.slide_position = nil
  end

  def display_card_labels(hand, hand_num)
    puts '-' * MID_SCREEN * 2
    puts "Wager:   $#{hand.wager}"
    label_line = player.hands.size == 1 ? "\nPlayer Cards:" : "\nHand ##{hand_num + 1} Cards:"
    label_line += ' <---' if hand == current_hand
    label_line += hand == player.hands.first ? ' ' * (MID_SCREEN - label_line.length + 1) + 'Dealer Cards:' : ''
    puts label_line
  end

  def display_cards(hand)
    update_hand_images(hand)
    player_hand_width = hand.image[1].length
    9.times do |i|
      print hand.image[i]
      puts hand == player.hands.first ? ' ' * (MID_SCREEN - player_hand_width) + dealer_hand.image[i] : ''
    end
  end

  def update_hand_images(hand)
    if hand.active && hand == current_hand && hand.cards.size > 1
      player_sliding = slide_position
    elsif player.hands.all? { |each_hand| !each_hand.active } && !hide_dealer_card?
      dealer_sliding = slide_position
    end
    hand.update_image(dealer_hand, player_sliding, false)
    if hand == player.hands.first
      dealer_hand.update_image(dealer_hand, dealer_sliding, hide_dealer_card?)
    end
  end

  def display_card_totals(hand, hand_num)
    total_line = player_card_totals(hand, hand_num)
    total_line += ' ' * (MID_SCREEN - total_line.length + 1)
    total_line += hand == player.hands.first ? dealer_card_totals : ''
    puts total_line
  end

  def player_card_totals(hand, hand_num)
    if player.hands.size == 1
      "\nPlayer Total: #{hand.value}"
    else
      "\nHand ##{hand_num + 1} Total: #{hand.value}"
    end
  end

  def dealer_card_totals
    if hide_dealer_card?
      "Dealer Total: #{dealer_hand.cards[1].value}"
    else
      "Dealer Total: #{dealer_hand.value}"
    end
  end
end

module GameLogic # Implements game rules
  include BlackjackConstants

  private

  def determine_valid_plays
    valid_plays = %w(Hit Stand)
    if current_hand.cards.length == 2 &&
       current_hand.cards.last.value == current_hand.cards.first.value &&
       player.balance > current_hand.wager && player.hands.size < 4
      valid_plays << 'Split'
    end
    if current_hand.cards.length == 2 && player.balance > current_hand.wager
      valid_plays << 'Double'
    end
    valid_plays
  end

  def stand
    current_hand.active = false
  end

  def hit(hand_to_hit = current_hand)
    slide_card_over
    hand_to_hit.add_cards(deck.deal_cards(1))
    update_display
  end

  def double
    hit
    stand
    player.balance -= current_hand.wager
    current_hand.wager *= 2
  end

  def split
    player.hands << PlayerHand.new
    player.hands.last.wager = current_hand.wager
    player.hands.last.cards << current_hand.cards.pop
    current_hand.cards.first.value = HIGH_ACE if current_hand.cards.first.value == 1
    player.balance -= current_hand.wager
    hit
    sleep 1.0 / 2
    self.current_hand = player.hands.last
    hit
    sleep 1.0 / 2
  end

  def hands_finalized?
    if dealer_hand.value == MAX_TOTAL ||
       player.hands.all? { |hand| !hand.active || hand.value >= MAX_TOTAL }
      player.hands.each { |hand| hand.active = false }
      self.current_hand = nil
      true
    end
  end

  def hide_dealer_card?
    player.hands.any?(&:active) ||
      player.hands.all? { |hand| hand.value > MAX_TOTAL } ||
      player.hands.all? { |hand| hand.value == MAX_TOTAL && hand.cards.length == 2 } &&
        dealer_hand.cards[1].value < 10
  end

  def never_reveal_dealer_card?
    player.hands.all? { |hand| hand.value > MAX_TOTAL } ||
      player.hands.all? { |hand| hand.value == MAX_TOTAL && hand.cards.length == 2 } &&
        dealer_hand.value < MAX_TOTAL || dealer_hand.value >= MIN_TOTAL
  end

  def winning_hand?(hand)
    hand.value <= MAX_TOTAL && dealer_hand.value < hand.value ||
      dealer_hand.value > MAX_TOTAL && hand.value <= MAX_TOTAL ||
      hand.value == MAX_TOTAL && hand.cards.size == 2 && dealer_hand.cards.size > 2
  end

  def tying_hand?(hand)
    hand.value <= MAX_TOTAL && hand.value == dealer_hand.value &&
      !(hand.cards.size > 2 && dealer_hand.cards.size == 2 && dealer_hand.value == MAX_TOTAL)
  end
end

module Messageable # Displays messages to player based on game outcome.
  include BlackjackConstants

  private

  def display_results_message
    print "\n\n"
    if player.hands.size == 1
      puts select_results_message(player.hands.first) + '.'
      display_balance_change(player.hands.first)
    else
      player.hands.each_with_index do |hand, hand_num|
        print select_results_message(hand)
        puts " on hand ##{hand_num + 1}."
        display_balance_change(hand)
        puts
        sleep 1
      end
    end
  end

  def select_results_message(hand)
    if hand.game_outcome == :won
      winning_message(hand)
    elsif hand.game_outcome == :lost
      losing_message(hand)
    else
      "It's a push. You tied the dealer with #{hand.value}"
    end
  end

  def winning_message(hand)
    if hand.value == MAX_TOTAL && hand.cards.size == 2
      "Congratulations #{player.name}! You got blackjack"
    elsif dealer_hand.value <= MAX_TOTAL
      "Congratulations #{player.name}! You beat the dealer #{hand.value}"\
      " to #{dealer_hand.value}"
    else
      "Congratulations #{player.name}! The dealer busted"
    end
  end

  def losing_message(hand)
    if hand.value > MAX_TOTAL
      'You busted'
    else
      "Sorry. You lost to the dealer #{dealer_hand.value} to #{hand.value}"
    end
  end

  def display_balance_change(hand)
    sleep 1
    puts
    if hand.value == MAX_TOTAL && hand.game_outcome == :won && hand.cards.size == 2
      puts "You won $#{(hand.wager * 1.5).to_i}!!"
    elsif hand.game_outcome == :won
      puts "You won $#{hand.wager}!"
    elsif hand.game_outcome == :lost
      puts "You lost $#{hand.wager}."
    end
  end

  def final_message
    sleep 1
    if player.balance >= 1000
      puts "\nYour balance has reached $1000! You have been banned from Launch School Casinos."
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

class Hand
  include BlackjackConstants
  REDUCE_ACE_VALUE = 10
  attr_accessor :active, :game_outcome, :value
  attr_reader :cards, :image

  def initialize
    @cards = []
    @image = [].fill('', 0..8)
    @active = true
    @value = 0
    @game_outcome = nil
  end

  def add_cards(new_cards)
    cards.unshift(new_cards).flatten!
    calculate_value
  end

  def update_image(dealer_hand, slide_position, hide_dealer_card)
    image.map! { '' }
    cards.each_with_index do |current_card, idx|
      if current_card == dealer_hand.cards[0] && hide_dealer_card
        add_card_image_to_hand_image(DealerHand::BLANK_CARD, idx, slide_position)
      else
        add_card_image_to_hand_image(current_card.image, idx, slide_position)
      end
    end
  end

  private

  def calculate_value
    self.value = cards.inject(0) { |sum, card| sum + card.value }
    self.value -= REDUCE_ACE_VALUE if reduce_ace_card_value_attribute
    self.active = false if value >= MAX_TOTAL
  end

  def reduce_ace_card_value_attribute
    ace = cards.select { |card| card.value == HIGH_ACE }
    ace[0].value -= REDUCE_ACE_VALUE if ace[0] && value > MAX_TOTAL
  end

  def add_card_image_to_hand_image(card_image, card_position, slide_position)
    9.times do |i|
      card_line_to_add =
        case card_position
        when 0 then card_image[i]
        when 1 then slide_position ? card_image[i].slice(0..slide_position) : card_image[i]
        else card_image[i].slice(0..2)
        end
      image[i].insert(0, card_line_to_add)
    end
  end
end

class Card
  attr_reader :suit, :image, :name
  attr_accessor :value

  def initialize(card_values)
    @suit = card_values[0]
    @name = card_values[1]
    @value = card_values[2]
    @image = create_card_image
  end

  private

  def create_card_image
    symbols = update_card_symbols
    c_lines = []
    c_lines << ' _________ '
    c_lines << "|#{name}#{symbols[8]}#{symbols[5]}   #{symbols[5]}  |"
    c_lines << "|#{symbols[0]} #{symbols[3]} #{symbols[7]} #{symbols[3]}  |"
    c_lines << "|  #{symbols[2]} #{symbols[4]} #{symbols[2]}  |"
    c_lines << "|  #{symbols[3]} #{symbols[6]} #{symbols[3]}  |"
    c_lines << "|  #{symbols[2]} #{symbols[1]} #{symbols[2]}  |"
    c_lines << "|  #{symbols[3]} #{symbols[7]} #{symbols[3]} #{symbols[0]}|"
    c_lines << "|  #{symbols[5]}   #{symbols[5]}#{symbols[8]}#{name}|"
    c_lines << ' --------- '
    c_lines
  end

  def update_card_symbols
    suit_symbol = determine_suit_symbol
    case name
    when '2' then c2 = c7 = suit_symbol
    when '3' then c9 = c10 = suit_symbol
    when '4' then c4 = suit_symbol
    when '5' then c4 = c9 = suit_symbol
    when '6' then c6 = suit_symbol
    when '7' then c6 = c7 = suit_symbol
    when '8' then c4 = c8 = suit_symbol
    when '9' then c4 = c8 = c9 = suit_symbol
    when '10'
      c4 = c8 = c10 = suit_symbol
      n10 = ''
    when 'J', 'Q', 'K', 'A' then c9 = suit_symbol
    end
    [suit_symbol, c2, c4, c6, c7, c8, c9, c10, n10].map! { |symbol| symbol || ' ' }
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
  SUITS = %i(spades clubs hearts diamonds).freeze
  VALUES = [['2', 2], ['3', 3], ['4', 4], ['5', 5], ['6', 6], ['7', 7], ['8', 8],
            ['9', 9], ['10', 10], ['J', 10], ['Q', 10], ['K', 10], ['A', 11]].freeze

  attr_accessor :cards

  def initialize
    @cards = shuffled_deck
  end

  def deal_cards(num_cards)
    @cards.pop(num_cards)
  end

  def reshuffle
    self.cards = shuffled_deck
  end

  private

  def shuffled_deck
    deck = SUITS.product(VALUES).map! { |card_values| Card.new(card_values.flatten) }
    deck.shuffle!
  end
end

class Player
  attr_reader :name
  attr_accessor :balance, :hands

  def initialize(player_name)
    @name = player_name
    @balance = 100
    @hands = [PlayerHand.new]
  end
end

class PlayerHand < Hand
  attr_accessor :wager
end

class DealerHand < Hand
  BLANK_CARD = [' _________ ',
                '|/ / / / /|',
                '| / / / / |',
                '|/ / / / /|',
                '| / / / / |',
                '|/ / / / /|',
                '| / / / / |',
                '|/ / / / /|',
                ' --------- '].freeze
end

class Game
  include BlackjackConstants
  include Displayable
  include GameLogic
  include Messageable

  attr_reader :player, :deck
  attr_accessor :current_hand, :dealer_hand

  def initialize
    @player = Player.new(set_name)
    @dealer_hand = DealerHand.new
    @deck = Deck.new
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

  private

  def set_name
    loop do
      clear_screen
      puts 'Welcome to Launch School Blackjack'
      print "\nPlease enter your name: "
      new_name = gets.chomp
      return new_name unless new_name == ''
    end
  end

  def initial_game_setup
    set_wager
    deal_initial_cards
    update_display
  end

  def set_wager
    clear_screen
    display_top_line
    print "\nHow much would you like to wager: "
    receive_wager_input
  end

  def deal_initial_cards
    player.hands.first.add_cards(deck.deal_cards(2))
    dealer_hand.add_cards(deck.deal_cards(2))
  end

  def receive_wager_input
    player.hands.first.wager = gets.chomp.to_i
    loop do
      if valid_wager?
        player.balance -= player.hands.first.wager
        break
      end
      print "\nThat wager is invalid. Please re-enter a valid wager:"
      player.hands.first.wager = gets.chomp.to_i
    end
  end

  def valid_wager?
    (1..player.balance).cover?(player.hands.first.wager)
  end

  def players_turn
    loop do
      break if hands_finalized?
      update_each_player_hand
    end
  end

  def dealers_turn
    loop do
      update_display
      break if never_reveal_dealer_card?
      sleep 1
      hit(dealer_hand)
    end
  end

  def update_each_player_hand
    player.hands.select(&:active).each do |current_hand_object|
      self.current_hand = current_hand_object
      update_display
      update_player_hand
    end
  end

  def update_player_hand
    valid_plays = determine_valid_plays
    print "\nPlease select an option"
    print player.hands.size > 1 ? " for hand ##{player.hands.index(current_hand) + 1}: " : ': '
    valid_plays.each { |choice| print choice + ' ' }
    puts
    send get_valid_decision(valid_plays)
  end

  def get_valid_decision(valid_plays)
    decision = gets.chomp
    loop do
      return decision.downcase if valid_plays.include?(decision.capitalize)
      print "\nThat is not a valid option. Please re-enter your selection: "
      decision = gets.chomp
    end
  end

  def results_message
    sleep 1
    assign_results_to_hands
    display_results_message
  end

  def assign_results_to_hands
    player.hands.each do |hand|
      hand.game_outcome = if winning_hand?(hand)
                            :won
                          elsif tying_hand?(hand)
                            :tie
                          else
                            :lost
                          end
    end
  end

  def update_balance
    player.hands.each do |hand|
      player.balance += (hand.wager *
                        case hand.game_outcome
                        when :won
                          (hand.value == MAX_TOTAL && hand.cards.length == 2) ? 2.5 : 2
                        when :tie then 1
                        else 0
                        end).to_i
    end
  end

  def replay?
    return false if player.balance == 0 || !(1..999).cover?(player.balance)
    puts "\nEnter 'y' if you would like to play another hand."
    gets.chomp.downcase == 'y'
  end

  def setup_new_round
    player.hands = [PlayerHand.new]
    self.dealer_hand = DealerHand.new
    deck.reshuffle
  end

  def clear_screen
    system 'clear' or system 'cls'
  end
end

Game.new.play

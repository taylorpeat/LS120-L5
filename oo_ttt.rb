module BoardEvaluatable
  WINNING_COMBOS = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6],
                    [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]].freeze

  def moves_for(current_board, marker)
    current_board.each_index.select { |idx| current_board[idx] == marker }
  end
end

class Board
  include BoardEvaluatable

  DISPLAY_TEMPLATE = { x:          ['   .   .   ',
                                    '    \ /    ',
                                    '     /     ',
                                    '    / \    ',
                                    '   .   .   '],
                       o:          ['   .--.    ',
                                    '  :    :   ',
                                    '  |    |   ',
                                    '  :    ;   ',
                                    '   `--\'    '],
                       diagonals:  ['\ \ \ \ \ \\',
                                    ' \ \ \ \ \ ',
                                    '\ \ \ \ \ \\',
                                    ' \ \ \ \ \ ',
                                    '\ \ \ \ \ \\'],
                       minimalist: [' ' * 11,
                                    ' ' * 11,
                                    '     .     ',
                                    ' ' * 11,
                                    ' ' * 11],
                       blank:          [].fill(' ' * 11, 0..4)
                     }.freeze

  attr_reader :current_board

  def initialize
    @current_board = initialize_board
  end

  def initialize_board
    starting_board = []
    (0..8).each { |position| starting_board[position] = :blank }
    starting_board
  end

  def update_current_board(selected_square, marker)
    current_board[selected_square] = marker
  end

  def draw
    puts
    printing_array = [current_board.values_at(0..2),
                      current_board.values_at(3..5),
                      current_board.values_at(6..8)]
    printing_array.each_with_index do |row_array, row_index|
      print_row(row_array)
      puts '    -----------+-----------+-----------' unless row_index == 2
    end
    puts
  end

  def print_row(row_array)
    5.times do |i|
      row_array.each_with_index do |square_value, square_index|
        print ' ' * 4 if square_index == 0
        print DISPLAY_TEMPLATE[square_value][i]
        print square_index == 2 ? "\n" : '|'
      end
    end
  end

  def draw_legend
    spacer = ' ' * 16
    current_board.each_with_index do |square_value, square_index|
      print spacer if [0, 3, 6].include?(square_index)
      print square_value == :blank ? " #{(square_index + 1)} " : '   '
      print [2, 5, 8].include?(square_index) ? "\n" : '|'
      print spacer + "---+---+---\n" if [2, 5].include?(square_index)
    end
  end

  def check_winner(marker)
    player_squares = moves_for(current_board, marker)
    WINNING_COMBOS.any? do |combo|
      return marker if combo.all? { |combo_num| player_squares.include?(combo_num) }
    end
    :tie unless current_board.any? { |square_value| square_value == :blank }
  end
end

class Human
  attr_reader :marker

  def initialize
    @marker = select_marker
  end

  def select_square(current_board)
    loop do
      square_selection = gets.chomp.to_i
      return (square_selection - 1) if (1..9).cover?(square_selection) &&
                                       current_board[square_selection - 1] == :blank
      if (1..9).cover?(square_selection)
        puts "\nThat square has been taken. Please select another square"
      else
        puts "\nThat is not a valid selection. Please select a number between 1 and 9."
      end
    end
  end

  def select_marker
    system 'clear' or system 'cls'
    loop do
      puts 'Please select a marker: (x, o, diagonals or minimalist)'
      loop do
        marker_selection = gets.chomp.to_sym
        return marker_selection if Board::DISPLAY_TEMPLATE.keys.include?(marker_selection)
        puts 'That is not a valid selection.'
      end
    end
  end
end

class Computer
  include BoardEvaluatable

  attr_reader :difficulty, :opponent_marker, :marker

  def initialize(opp_marker)
    @difficulty = set_difficulty
    @opponent_marker = opp_marker
    @marker = Board::DISPLAY_TEMPLATE.keys
                                     .select { |symbol| ![:blank, opponent_marker].include?(symbol) }
                                     .sample
  end

  def set_difficulty
    loop do
      system 'clear' or system 'cls'
      puts 'Please select a difficulty level: (easy/hard)'
      difficulty_input = gets.chomp.downcase
      difficulty_input = nil unless %w(easy hard).include?(difficulty_input)
      return difficulty_input if difficulty_input
    end
  end

  def select_square(current_board)
    sleep 1
    empty_squares = moves_for(current_board, :blank)
    human_squares = moves_for(current_board, opponent_marker)
    computer_squares = moves_for(current_board, marker)
    return empty_squares.sample if difficulty == 'easy'
    ai_square_selection(empty_squares, human_squares, computer_squares)
  end

  def ai_square_selection(empty_squares, human_squares, computer_squares)
    ai_selection = find_winning_square(computer_squares, human_squares)
    ai_selection ||= find_winning_square(human_squares, computer_squares)
    ai_selection ||= find_best_square(human_squares, computer_squares)
    ai_selection ||= 4 if empty_squares.include?(4)
    ai_selection ||= empty_squares.select { |num| [0, 2, 6, 8].include?(num) }.sample
    ai_selection ||  empty_squares.sample
  end

  def find_winning_square(p1_squares, p2_squares)
    WINNING_COMBOS.each do |combo|
      player_squares_in_combo = combo.count { |sq| p1_squares.include?(sq) }
      return (combo - p1_squares)[0] if player_squares_in_combo == 2 &&
                                        (combo - p2_squares) == combo
    end
    nil
  end

  def find_best_square(human_squares, computer_squares)
    humans_winning_combos = determine_winning_combos(human_squares, computer_squares)
    computers_winning_combos = determine_winning_combos(computer_squares, human_squares)
    fork_opportunities = find_fork_opportunities(humans_winning_combos, human_squares)
    best_square_based_on_forks(computer_squares, computers_winning_combos, fork_opportunities)
  end

  def determine_winning_combos(p1_squares, p2_squares)
    WINNING_COMBOS.select do |combo|
      combo.all? { |combo_sq| !p2_squares.include?(combo_sq) } &&
        combo.any? { |combo_sq| p1_squares.include?(combo_sq) }
    end
  end

  def best_square_based_on_forks(computer_squares, computers_winning_combos, fork_opportunities)
    if fork_opportunities.length == 2
      computers_winning_combos.flatten
                              .select do |combo_sq|
                                !(computer_squares + fork_opportunities).include?(combo_sq)
                              end.sample
    elsif fork_opportunities.length > 1
      fork_opportunities.select { |fork_sq| computers_winning_combos.flatten.include?(fork_sq) }
                        .sample
    else
      fork_opportunities[0]
    end
  end

  def find_fork_opportunities(humans_winning_combos, human_squares)
    fork_opportunities = []
    humans_winning_combos.each do |combo|
      combo.each do |sq|
        if winning_combos_overlap_at_square?(humans_winning_combos, human_squares,
                                             sq, fork_opportunities)
          fork_opportunities << sq
        end
      end
    end
    fork_opportunities
  end

  def winning_combos_overlap_at_square?(humans_winning_combos, human_squares, sq, fork_opportunities)
    combos_with_sq = 0
    humans_winning_combos.each do |combo_reference|
      combos_with_sq += 1 if (combo_reference - human_squares).include?(sq)
    end
    return true if combos_with_sq > 1 && !fork_opportunities.include?(sq)
    false
  end
end

class Game
  WINNING_SCORE = 3
  attr_accessor :winner_marker
  attr_reader :human, :computer, :game_board, :score

  def initialize
    @score ||= [0, 0, 0]
    @human = Human.new
    @computer = Computer.new(human.marker)
    @game_board = Board.new
    @winner_marker = nil
    update_display
  end

  def play
    loop do
      player_turns
      update_score
      display_winner_message
      break if overall_winner? || replay?
      initialize
    end
    goodbye_message
  end

  def player_turns
    loop do
      [human, computer].each do |player|
        player_turn(player)
        return if determine_winner_marker(player.marker)
      end
    end
  end

  def player_turn(player)
    selected_square = player.select_square(game_board.current_board)
    game_board.update_current_board(selected_square, player.marker)
    update_display
  end

  def determine_winner_marker(marker)
    self.winner_marker = game_board.check_winner(marker)
  end

  def replay?
    puts "Enter 'y' if you would like to play again"
    gets.chomp.downcase != 'y'
  end

  def overall_winner?
    score[0] == WINNING_SCORE || score[1] == WINNING_SCORE
  end

  def update_display
    display_score
    game_board.draw
    puts "Select an available location between 1 and 9\n\n"
    game_board.draw_legend
  end

  def display_winner_message
    puts
    sleep 1
    if winner_marker == human.marker
      puts 'Congratulations! You won!'
      sleep 1
      puts "\nOn easy...\n\n"
    elsif winner_marker == computer.marker
      puts "You lost at tic-tac-toe... that's embarrasing.\n\n"
    else
      puts "Tied. Try it on easy if you feel like winning...\n\n"
      if computer.difficulty == 'easy'
        sleep 1
        puts "Oh wait... you were playing on easy... ouch\n\n"
      end
    end
    sleep 1
  end

  def update_score
    case winner_marker
    when human.marker then score[0] += 1
    when computer.marker then score[1] += 1
    else score[2] += 1
    end
    update_display
  end

  def display_score
    system 'clear' or system 'cls'
    puts " CURRENT SCORE: #{score[0]} Wins / #{score[1]} Losses / #{score[2]} Ties\n\n"
  end

  def goodbye_message
    if score[0] == WINNING_SCORE
      puts "Congratulations! You beat the computer #{score[0]} games to #{score[1]}."
    elsif score[1] == WINNING_SCORE
      puts "Sorry. You lost to the computer #{score[1]} games to #{score[0]}."
    end
    sleep 1
    puts "\nThanks for playing!\n\n"
  end
end

Game.new.play

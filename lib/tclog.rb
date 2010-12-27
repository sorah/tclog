# = TCLog
# Author:: Shota Fukumori (sora_h)
# Copyright:: (c) Shota Fukumori (sora_h) 2010 w/ mit license
# License:: MIT License; License terms written in README.mkd
#
# This library helps TC:E stats parsing.
# 
module TCLog
  class Game
    class PlayerArray < Hash
      def initialize(*args) # :nodoc:
        @ary = []
        super *args
      end

      # [x]
      #   String or Integer.
      #   String finds player from name, Integer finds player from index.
      #
      # Get Player object.
      def [](x)
        if x.kind_of?(Integer)
          self[@ary[x]] if @ary[x]
        else
          super x
        end
      end

      # [a]
      #    Player's name.
      # [b]
      #    TCLog::Player object.
      #
      #  Add Player with name.
      def []=(a,b)
        @ary << a
        super a,b
      end

      # [player]
      #   TCLog::Player object.
      #
      # Add Player.
      def <<(player)
        @ary << player.name
        self[player.name] = player
        self
      end

      # yield each player
      def each # :yield: player
        @ary.each do |name|
          yield self[name]
        end
      end
      
      def inspect # :nodoc:
        @ary.map do |name|
          self[name]
        end
      end
    end
    def initialize(orders = [], gametype = :obj) # :nodoc:
      @orders = orders
      @gametype = gametype
      @rounds = []
      @round_n = -1
      @round_r = -1
      @players = PlayerArray.new
    end


    def add_map(map_name) # :nodoc:
      @round_r += 1
      @rounds << Round.new(self, nil, @round_r, :map, true, map_name); self
    end

    def add_round(specops,terrorists,won) # :nodoc:
      @round_n += 1
      @round_r += 1
      r = Round.new(self, @round_n, @round_r, won)
      r.specops = specops.dup
      r.terrorists = terrorists.dup
      @rounds << r
      self
    end

    def add_player(name) # :nodoc:
      @players << Player.new(name)
      if 0 <= @round_r
        @players[name].push_result(@round_r)
      end
      self
    end
    

    def round; @round_n; end # :nodoc:
    attr_reader :round_r # :nodoc:

    # Has same mean as game.rounds[i]
    def [](i); @rounds[i]; end

    # Logged rounds.
    attr_reader :rounds

    # All players.
    attr_reader :players

    # Parser VM call stacks.
    attr_reader :orders

    # Gametype. obj, bc, ctf.
    attr_reader :gametype
  end
  class Round
    def initialize(game, n, rn, win, map_changing = false, map_name = nil) # :nodoc
      @game = game
      @won = win
      @round_number = n
      @real_round_number = rn
      @map_changing = map_changing
      @specops = {}
      @terrorists = {}
      @map_name = map_name
    end


    # Players which joined at this round.
    def players
      @game.players.map do |g|
        g if @round_number && g.results[@real_round_number]
      end.compact
    end

    # Players result which joined at this round.
    def player_results
      @game.players.map do |g|
        g.results[@real_round_number] if @round_number
      end.compact
    end

    # Is this round changing map?
    def map_changing?; @map_changing;        end

    def map_changing=(x); @map_changing = x; end # :nodoc:

    # Next map name if this round changing map.
    attr_accessor :map_name

    # specops total scores.
    attr_accessor :specops

    # terrorists total scores.
    attr_accessor :terrorists

    # Team which won this round.
    attr_accessor :won

    # Round number at game. (Counted without map changing)
    attr_reader :round_number
  end
  class Player
    def initialize(name) # :nodoc:
      @name = name
      @results = []
    end

    def add_result(n, score) # :nodoc:
      @results[n] = score.merge(:round => n); self
    end

    # Returns this player's total score.
    def total
      a = @results.compact.inject({
        :name  => @name,
        :kill  => 0,
        :death => 0,
        :sui   => 0,
        :tk    => 0,
        :eff   => 0,
        :dg    => 0,
        :dr    => 0,
        :td    => 0,
        :score => 0,
        :rate  => 0
      }) do |r,i|
        [:kill,:death,:sui,:tk,:eff,:dg,:dr,:td,:score].each do |l|
          r[l] += i[l]
        end
        r
      end
      a[:rate] = (a[:dg].to_i-a[:dr].to_i)/100.0
      a[:kd] = a[:kill].to_f / a[:death].to_f
      a
    end

    def push_result(i) # :nodoc:
      @results[i] = nil
    end
    
    # This player's name.
    attr_reader :name

    # This player's round results.
    # Use compact method to use Round#round_number.
    attr_reader :results
  end


  # [logfile]
  #   String or IO. String is filename.
  #
  # [gametype]
  #   :obj => "Objective"
  #   :ctf => "Capture The Flag"
  #   :bc  => "BodyCount"
  #
  # Parses TC:E etconsole.log.
  # You can catch etconsole.log by /set logfile 2 at tc:e console.
  def self.analyze(logfile, gametype = :obj)
    # Load file
    log = case logfile
          when File, IO
            logfile.readlines.map(&:chomp)
          when String
            File.readlines(logfile).map(&:chomp)
          else
            raise ArgumentError, "logfile must be kind of String, File or IO"
          end
    # Drop waste lines / Drop waste message
    renames = {}
    orders = log.map do |x|
      next unless /^(\[skipnotify\])(\^.)?(.+renamed|Timelimit hit)/ =~ x ||
                  /^(\[skipnotify\])?(\^.)?(Specops|Terrorists)/     =~ x ||
                  /^(\[skipnotify\])?(\^.)?(Planted|Defused)/        =~ x ||
                  /^The .+ have completed the objective!/            =~ x ||
                  /^(\[skipnotify\])(\^.)(Overall stats for: |)/     =~ x ||
                  /^(LOADING\.\.\. maps|Match starting)/             =~ x
      x.gsub!(/\[skipnotify\]/,"") 
      # Player Score
      r = x.scan(/\^.(Terrorists|Specops)\^. *\^.(.+?)\^. *([\d\-]+) +([\d\-]+) +([\d\-]+) +([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)/).flatten
      if r.empty? # If the line not player's score
        case x
        when /^LOADING\.\.\. maps\/(.+?)\.bsp$/ # Map Changing?
          m = $~.captures
          ["Map",m[0]]
        when /^Match starting/ # Match starting
          ["Match"]
        when /^(Planted) at (.+?) \[(.)\]/, /^The Terrorists have completed the objective!/ # TeroWin
          m = $~.captures
          m[0] = "TerroristsWin"
          m
        when /^(Defused) at (.+?) \[(.)\]/, /^The Specops have completed the objective!/ # Specops Win
          m = $~.captures
          m[0] = "SpecopsWin"
          m
        when /Timelimit hit/
          if gametype == :obj
            ["SpecopsWin"]
          else
            ["UnknownWin"]
          end
        when /^\^7Overall stats for:/ # /^(\[skipnotify\])(\^.)(Overall stats for: |)/
          if [:bc, :obj].include?(gametype) 
            ["UnknownWin"]
          else
            nil
          end
        when /\^.(.+?)\^. \^.(Totals) *([\d\-]+) +([\d\-]+) +([\d\-]+) +([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)\^. *([\d\-]+)/ # Team total score?
          r = $~.captures
          r[0] << "Total"
          m = [r[0]]
          m << {
            :name  => r[1],
            :kill  => r[2].to_i,
            :death => r[3].to_i,
            :sui   => r[4].to_i,
            :tk    => r[5].to_i,
            :eff   => r[6].to_i,
            :aa    => r[7].to_i,
            :dg    => r[8].to_i,
            :dr    => r[9].to_i,
            :td    => r[10].to_i,
            :score => r[11].to_i,
            :rate  => (r[8].to_i-r[9].to_i)/100.0,
          }
        when /^(.+) renamed to (.+)/ # nick renamed?
          m = $~.captures
          m.map!{|n|n.gsub(/ +$/,"")[0..14]}
          renames[m[1]] = renames[m[0]] || m[0]
          nil
        end
      else
        # Process player's score
        if r[1].kind_of?(String)
          r[1].gsub!(/ +$/,"")
          r[1] = r[1][0..14]
          r[1] = renames[r[1]] || r[1]
        end
        m = [r[0]]
        m << {
          :name  => r[1],
          :kill  => r[2].to_i,
          :death => r[3].to_i,
          :sui   => r[4].to_i,
          :tk    => r[5].to_i,
          :eff   => r[6].to_i,
          :aa    => r[7].to_i,
          :dg    => r[8].to_i,
          :dr    => r[9].to_i,
          :td    => r[10].to_i,
          :score => r[11].to_i,
          :rate  => (r[8].to_i-r[9].to_i)/100.0,
        }
      end
    end.compact

    #pp orders

    match_flag = false
    game = Game.new(orders, gametype)
    match = [""]
    match_wins = nil
    terrorists_total = nil
    specops_total = nil
    vm = Proc.new do |o|
      case o[0]
      when "Match"
        if match_flag
          if specops_total && match_wins
            game.add_round specops_total, terrorists_total, match_wins
            match_wins = nil
            terrorists_total = nil
            specops_total = nil
          end
        else
          match_flag = true
        end
        if match[-1][0] == "Map"
          game.add_map match[-1][1]
        end
      when "UnknownWin"
        match_wins = :unknown if match_flag
      when "TerroristsWin"
        match_wins = :terrorists if match_flag
      when "SpecopsWin"
        match_wins = :specops if match_flag
      when "Terrorists", "Specops"
        if match_flag
          unless game.players[o[1][:name]]
            game.add_player(o[1][:name])
          end
          game.players[o[1][:name]].add_result(game.round_r+1,o[1])
        end
      when "TerroristsTotal"
        terrorists_total = o[1] if match_flag
      when "SpecopsTotal"
       if match_flag
         specops_total = o[1]
         match_wins = compare_score(terrorists_total, specops_total) if match_wins == :unknown
       end
      end
      match << o
    end
    orders.each(&vm)

    vm.call(["Match"]) if match_flag
    game
  end

  def self.compare_score(terrorists, specops) # :nodoc:
    if terrorists[:score] > specops[:score]
      :terrorists
    else
      :specops
    end
  end
end



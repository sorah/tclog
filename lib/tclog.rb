module TCLog
  class Game
    def initialize(orders = [], gametype = :obj)
      @orders = orders
      @gametype = gametype
      @rounds = []
      @round_n = -1
      @players = {}
      class << @players
        def [](x)
          if x.kind_of?(Integer)
            self.map{|v|v}[x]
          else
            super x
          end
        end
        
        def each
          super &(Proc.new{|k,v| yield v })
        end
      end
    end


    def add_map(map_name)
      @rounds << Round.new(self, nil, :map, true, map_name); self
    end

    def add_round(specops,terrorists,won)
      @round_n += 1
      r = Round.new(self, @round_n, won)
      r.specops = specops.dup
      r.terrorists = terrorists.dup
      @rounds << r
      self
    end

    def add_player(name)
      @players[name] = Player.new(name)
      self
    end
    

    def round; @round_n; end
    def [](i); @rounds[i]; end
    attr_reader :rounds, :players, :orders, :gametype
  end
  class Round
    def initialize(game, n, win, map_changing = false, map_name = nil)
      @game = game
      @won = win
      @round_number = n
      @map_changing = map_changing
      @specops = {}
      @terrorists = {}
      @map_name = map_name
    end

    def players
      @game.players.map do |g|
        g if @round_number && g.results[@round_number]
      end.compact
    end

    def player_results
      @game.players.map do |g|
        g.results[@round_number] if @round_number
      end.compact
    end

    def map_changing?; @map_changing;        end
    def map_changing=(x); @map_changing = x; end
    attr_accessor :map_name, :specops, :terrorists, :won
    attr_reader :round_number
  end
  class Player
    def initialize(name)
      @name = name
      @results = []
    end

    def add_result(n, score)
      @results << score.merge(:round => n); self
    end

    def total
      a = @results.inject({
        :name=>@name,
        :kill=>0,
        :death=>0,
        :sui=>0,
        :tk=>0,
        :eff=>0,
        :aa=>0,
        :dg=>0,
        :dr=>0,
        :td=>0,
        :score=>0,
        :rate=>0
      }).inject do |r,i|
        [:kill,:death,:sui,:tk,:eff,:aa,:dg,:dr,:td,:score].each do |l|
          r[l] += i[l]
        end
        r
      end
      a[:rate] = (a[:dg].to_i-a[:dr].to_i)/100.0
      a[:kd] = a[:kill].to_f / a[:death].to_f
      a
    end
    attr_reader :name, :results
  end

  # logfile  = String: filename
  #            IO:     io
  #
  # gametype = :obj => "Objective"
  #            :ctf => "Capture The Flag"
  #            :bc  => "BodyCount"
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
    match = []
    match_wins = nil
    map_change = nil
    terrorists_total = nil
    specops_total = nil
    vm = Proc.new do |o|
      if match_flag && o[0] == "Map"
        map_change = o
      end
      if o[0] == "Match"
        if match_flag
          if map_change && (specops_total || !match_wins)
            game.add_map map_change[1]
            match_flag = false
            map_change = nil
            match_flag = true
          end
          if specops_total && match_wins
            match_flag = false
            game.add_round(specops_total,terrorists_total, match_wins)
            match = []
            match_wins = nil
            map_change = nil
            terrorists_total = nil
            specops_total = nil
            match_flag = true
          end
        else
          match_flag = true
        end
      end
      if o[0] == "UnknownWin"
        match_wins = :unknown unless match_wins
      end
      if o[0] == "TerroristsWin"
        match_wins = :terrorists
      end
      if o[0] == "SpecopsWin"
        match_wins = :specops
      end
      if match_flag && ["Terrorists","Specops"].include?(o[0])
        unless game.players[o[1][:name]]
          game.add_player(o[1][:name])
        end
        game.players[o[1][:name]].add_result(game.round, o[1])
      end
      if match_flag && "TerroristsTotal" == o[0]
        terrorists_total = o[1]
      end
      if match_flag && "SpecopsTotal" == o[0]
        specops_total = o[1]
        match_wins = compare_score(terrorists_total, specops_total) if match_wins == :unknown
      end
      if match_flag && "TerroristsWin" == o[0]
        match_wins = :terrorists
      end
      if match_flag && "SpecopsWin" == o[0]
        match_wins = :specops
      end
      if map_change && match_wins.nil?
        map_change = nil
        match_wins = nil
        match = []
        match_flag = false
        terrorists_total = nil
        specops_total = nil
      end
    end
    orders.each(&vm)

    vm.call(["Match"]) if match_flag
    game
  end

  def self.compare_score(terrorists, specops)
    if terrorists[:score] > specops[:score]
      :terrorists
    else
      :specops
    end
  end
end



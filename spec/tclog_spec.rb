require "#{File.dirname(__FILE__)}/../lib/tclog.rb"
require 'rspec'

describe TCLog do
  TESTLOG  = "#{File.dirname(__FILE__)}/../misc"
  OBJTEST  = "#{TESTLOG}/objtest.log"
  CTFTEST  = "#{TESTLOG}/ctftest.log"
  BCTEST   = "#{TESTLOG}/bctest.log"
  MISCTEST = "#{TESTLOG}/test.log"
  describe ".analyze" do
    it "should return TCLog::Game" do
      TCLog.analyze(OBJTEST).should be_a_kind_of(TCLog::Game)
    end

    it "accepts IO and String for log" do
      TCLog.analyze(OBJTEST).should be_a_kind_of(TCLog::Game)
      TCLog.analyze(open(OBJTEST)).should be_a_kind_of(TCLog::Game)
    end

    it "accepts gametype" do
      TCLog.analyze(BCTEST, :bc).should be_a_kind_of(TCLog::Game)
    end
  end

  describe "::Game" do
    describe "when gametype objective," do
      before :all do
        @game = TCLog.analyze(OBJTEST)
      end

      it "map changing is recorded" do
        round = @game.rounds[0]
        round.map_changing?.should be_true
        round.map_name.should == "obj_northport"
      end

      it "terrorists win by terrorists killed all of specops" do
        round = @game.rounds[1]
        round.specops[:sui].should > 0
        round.specops[:score].should < 0
        round.won.should == :terrorists
      end

      it "specops win by specops killed all of terrorists" do
        round = @game.rounds[2]
        round.terrorists[:sui].should > 0
        round.terrorists[:score].should < 0
        round.won.should == :specops
      end

      it "specops win by timelimit hitting" do
        round = @game.rounds[3]
        round.won.should == :specops
      end

      it "terrorists win by planting" do
        round = @game.rounds[4]
        round.won.should == :terrorists
      end

      it "specops win by defusing" do
        round = @game.rounds[5]
        round.won.should == :specops
      end

      it "map changing is recorded" do
        round = @game.rounds[6]
        round.map_changing?.should be_true
        round.map_name.should == "obj_railhouse"
      end
    end

    describe "when gametype capture the flag," do
      before :all do
        @game = TCLog.analyze(CTFTEST, :ctf)
      end

      it "terrorists win by completing flags" do
        @game.rounds[0].won.should == :terrorists
      end

      it "specops win by completing flags" do
        @game.rounds[1].won.should == :specops
      end

      it "terrorists win by killing specops and getting high score" do
        @game.rounds[2].terrorists[:score].should > @game.rounds[2].specops[:score]
        @game.rounds[2].won.should == :terrorists
      end
    end

    describe "when gametype bodycount," do
      before :all do
        @game = TCLog.analyze(BCTEST, :bc)
      end

      it "map changing is recorded" do
        @game.rounds[1].map_changing?.should be_true
        @game.rounds[1].map_name.should == "obj_railhouse"
        @game.rounds[2].map_changing?.should be_true
        @game.rounds[2].map_name.should == "obj_northport"
      end

      it "specops win by killing terrorists and getting high score" do
        @game.rounds[3].specops[:score].should > @game.rounds[3].terrorists[:score]
        @game.rounds[3].won = :specops
      end

      it "terrorists win by getting 20p" do
        @game.rounds[4].terrorists[:score].should >= 20
        @game.rounds[4].won = :terrorists
      end
    end

    describe "misc feature:" do
      before :all do
        @game = TCLog.analyze(MISCTEST)
      end
      it "rounds" do
        @game.rounds.should be_a_kind_of(Array)
        @game.rounds.each do |r|
          r.should be_a_kind_of(TCLog::Round)
        end
      end

      it "players" do
        @game.players.should be_a_kind_of(Hash)
        @game.players.each do |r|
          r.should be_a_kind_of(TCLog::Player)
        end
      end

      describe "round" do
        before :all do
          @round = @game.rounds[1]
        end

        it "players" do
          @round.players.should be_a_kind_of(Array)
          @round.players.each do |x|
            x.should be_a_kind_of(TCLog::Player)
          end

          r = @game.rounds[2]
          r.players.map(&:name).should_not be_include("*Pasra* sora_h")
        end

        it "player_results" do
          @round.player_results.should be_a_kind_of(Array)
          @round.player_results.each do |x|
            x.should be_a_kind_of(Hash)
          end
        end

        it "map_changing" do
          r = @game.rounds[0]
          r.map_changing?.should be_true
          r.map_name.should == "obj_northport"
          r.players.should be_empty
          r.player_results.should be_empty
        end
      end

      describe "player" do
        before :all do
          @player = @game.players[0]
        end
        
        it "results" do
          @player.results.each do |x|
            x.should be_a_kind_of(Hash) unless x.nil?
          end
          @game.rounds.each_with_index do |v,i|
            if v.map_changing? || !v.players.include?(@player)
              @player.results[i].should be_nil
            end
          end
        end
      end
    end
  end

end

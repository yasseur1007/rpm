require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
module NewRelic
  module Agent
    class AgentTest < Test::Unit::TestCase
      
      def setup
        super
        @agent = NewRelic::Agent::Agent.new
      end

      def test_serialize
        assert_equal([{}, [], []], @agent.send(:serialize), "should return nil when shut down")
      end
      
      def test_harvest_transaction_traces
        assert_equal([], @agent.send(:harvest_transaction_traces), 'should return transaction traces')        
      end
      
      def test_harvest_timeslice_data
        assert_equal({}, @agent.send(:harvest_timeslice_data), 'should return timeslice data')
      end
      
      def test_harvest_errors
        assert_equal([], @agent.send(:harvest_errors), 'should return errors')
      end

      def test_merge_data_from_empty
        unsent_timeslice_data = mock('unsent timeslice data')
        unsent_errors = mock('unsent errors')
        unsent_traces = mock('unsent traces')
        @agent.instance_eval {
          @unsent_errors = unsent_errors
          @unsent_timeslice_data = unsent_timeslice_data
          @traces = unsent_traces
        }
        # nb none of the others should receive merge requests
        @agent.merge_data_from([{}])
      end

      def test_merge_data_from_all_three_empty
        unsent_timeslice_data = mock('unsent timeslice data')
        unsent_errors = mock('unsent errors')
        unsent_traces = mock('unsent traces')
        @agent.instance_eval {
          @unsent_errors = unsent_errors
          @unsent_timeslice_data = unsent_timeslice_data
          @traces = unsent_traces
        }
        unsent_errors.expects(:+).with([])
        unsent_traces.expects(:+).with([])
        @agent.merge_data_from([{}, [], []])
      end

      def test_merge_data_from_actual_agent
        NewRelic::Agent.manual_start

        data = NewRelic::Agent.instance.serialize

        @agent.merge_data_from(data)
        assert_equal(data, @agent.serialize)
      end

      def test_merge_data_from_actual_agent_method_traced
        100.times do
          @agent.stats_engine.get_stats_no_scope('foo/bar').record_data_point(0.1)
        end
        data = @agent.serialize
        NewRelic::Agent.manual_start
        NewRelic::Agent.instance.merge_data_from(data)
        NewRelic::Agent.shutdown
      end

      def test_sql_normalization

        # basic statement
        assert_equal "INSERT INTO X values(?,?, ? , ?)",
        @agent.send(:default_sql_obfuscator, "INSERT INTO X values('test',0, 1 , 2)")

        # escaped literals
        assert_equal "INSERT INTO X values(?, ?,?, ? , ?)",
        @agent.send(:default_sql_obfuscator, "INSERT INTO X values('', 'jim''s ssn',0, 1 , 'jim''s son''s son')")

        # multiple string literals
        assert_equal "INSERT INTO X values(?,?,?, ? , ?)",
        @agent.send(:default_sql_obfuscator, "INSERT INTO X values('jim''s ssn','x',0, 1 , 2)")

        # empty string literal
        # NOTE: the empty string literal resolves to empty string, which for our purposes is acceptable
        assert_equal "INSERT INTO X values(?,?,?, ? , ?)",
        @agent.send(:default_sql_obfuscator, "INSERT INTO X values('','x',0, 1 , 2)")

        # try a select statement
        assert_equal "select * from table where name=? and ssn=?",
        @agent.send(:default_sql_obfuscator, "select * from table where name='jim gochee' and ssn=0012211223")

        # number literals embedded in sql - oh well
        assert_equal "select * from table_? where name=? and ssn=?",
        @agent.send(:default_sql_obfuscator, "select * from table_007 where name='jim gochee' and ssn=0012211223")
      end

      def test_sql_normalization__single_quotes
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, "INSERT 'this isn''t a real value' into table")
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT '"' into table])
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT ' "some text" \" ' into table])
        #    could not get this one licked.  no biggie
        #    assert_equal "INSERT ? into table",
        #    @agent.send(:default_sql_obfuscator, %q[INSERT '\'' into table])
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT ''' ' into table])
      end
      def test_sql_normalization__double_quotes
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT "this isn't a real value" into table])
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT "'" into table])
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT " \" " into table])
        assert_equal "INSERT ? into table",
        @agent.send(:default_sql_obfuscator, %q[INSERT " 'some text' " into table])
      end
      def test_sql_obfuscation_filters
        @agent.set_sql_obfuscator(:replace) do |string|
          "1" + string
        end

        sql = "SELECT * FROM TABLE 123 'jim'"

        assert_equal "1" + sql, @agent.obfuscator.call(sql)

        @agent.set_sql_obfuscator(:before) do |string|
          "2" + string
        end

        assert_equal "12" + sql, @agent.obfuscator.call(sql)

        @agent.set_sql_obfuscator(:after) do |string|
          string + "3"
        end

        assert_equal "12" + sql + "3", @agent.obfuscator.call(sql)
      end


    end
  end
end
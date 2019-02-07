require 'helper.rb'

require_relative '../lib/redisgraph.rb'

describe RedisGraph do
  # TODO it would be nice to have something like DisposableRedis
  # Connect to a Redis server on localhost:6379
  before(:all) do
    begin
      @r = RedisGraph.new("rubytest")
    rescue Redis::BaseError => e
      puts e
      puts "RedisGraph tests require that a Redis server with the graph module loaded be running on localhost:6379"
      exit 1
    end
  end

  # Ensure that the graph "rubytest" does not exist
  after(:all) do
    @r.delete
  end

  # Test functions - each validates one or more EXPLAIN and QUERY calls

  context "nodes" do
    it "should create nodes properly" do
      query_str = """CREATE (t:node {name: 'src'})"""
      x = @r.query(query_str)
      plan = @r.explain(query_str)
      expect(plan).to include("Create")
      expect(x.resultset).to be_nil
      expect(x.stats[:labels_added]).to eq(1)
      expect(x.stats[:nodes_created]).to eq(1)
      expect(x.stats[:properties_set]).to eq(1)
    end

    it "should delete nodes properly" do
      query_str = """MATCH (t:node) WHERE t.name = 'src' DELETE t"""
      plan = @r.explain(query_str)
      expect(plan).to include("Delete")
      x = @r.query(query_str)
      expect(x.resultset).to be_nil
      expect(x.stats[:nodes_deleted]).to eq(1)
    end
  end

  context "edges" do
    it "should create edges properly" do
      query_str = """CREATE (p:node {name: 'src1'})-[:edge]->(:node {name: 'dest1'}), (:node {name: 'src2'})-[:edge]->(q:node_type_2 {name: 'dest2'})"""
      plan = @r.explain(query_str)
      expect(plan).to include("Create")
      x = @r.query(query_str)
      expect(x.resultset).to be_nil
      expect(x.stats[:nodes_created]).to eq(4)
      expect(x.stats[:properties_set]).to eq(4)
      expect(x.stats[:relationships_created]).to eq(2)
    end

    it "should traverse edges properly" do
      query_str = """MATCH (a)-[:edge]->(b:node) RETURN a, b"""
      plan = @r.explain(query_str)
      expect(plan).to include("Traverse")
      x = @r.query(query_str)
      expect(x.resultset).to be_instance_of(Array)
      expect(x.columns.length).to eq(2)
      expect(x.resultset.length).to eq(1)
      expect(x.resultset[0]).to eq(["src1", "dest1"])
    end
  end
end
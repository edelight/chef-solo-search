#
# Copyright 2011, edelight GmbH
#
# Authors:
#       Markus Korn <markus.korn@edelight.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "test/unit"
require "chef"

# mocking chef such that it thinks it's running as chef-solo and knows about
# the location of the data_bag
Chef::Config[:solo] = true
Chef::Config[:data_bag_path] = "tests/data/data_bags"

# load the extension
require File.expand_path('../../libraries/search', __FILE__)

def search(*args, &block)
  # wrapper around creating a new Recipe instance and calling search on it
  node = Chef::Node.new()
  cookbooks = Chef::CookbookCollection.new()
  run_context = Chef::RunContext.new(node, cookbooks)
  return Chef::Recipe.new("test_cookbook", "test_recipe", run_context).search(*args, &block)
end

class TestSearchDB < Test::Unit::TestCase
  
  def test_search_all
    # try to get data of all users
    nodes = search(:users, "*:*")
    assert_equal nodes.length, 4
    nodes = search(:users)
    assert_equal nodes.length, 4
    nodes = search(:users, nil)
    assert_equal nodes.length, 4
  end
  
  def test_search_exact_match
    nodes = search(:users, "username:speedy")
    assert_equal nodes.length, 1
    assert_equal nodes[0]["username"], "speedy"
  end
  
  def test_get_all_with_field
    nodes = search(:users, "username:*")
    assert nodes.length > 0
    assert nodes.all?{|x| !x["username"].nil?}
  end
  
  def test_get_all_without_field
    nodes = search(:users, "(NOT username:*)")
    assert nodes.length == 0
    nodes = search(:users, "(NOT color:*)")
    assert nodes.length == 3
    assert nodes.all?{|x| x["color"].nil?}
  end
  
  def test_get_all_but_speedy
    nodes = search(:users, "NOT username:speedy")
    assert nodes.length > 0
    assert nodes.all?{|x| x["username"] != "speedy"}
  end
  
  def test_array_includes
    nodes = search(:users, "children:tom")
    assert nodes.length == 2
    assert nodes.all?{ |x| x["children"].include?("tom") }
    nodes = search(:users, "children:jerry")
    assert nodes.length == 1
    assert nodes.all?{ |x| x["children"].include?("jerry") }
  end
  
  def test_boolean
    nodes = search(:users, "married:true")
    assert nodes.length == 3
    assert nodes.all?{ |x| x["married"] == true }
    nodes = search(:users, "married:false")
    assert nodes.length == 1
    assert nodes[0]["married"] == false
  end
  
  def test_integer
    nodes = search(:users, "age:35")
    assert nodes.length == 1
    assert nodes[0]["age"] == 35
  end
  
  def test_AND_condition
    nodes = search(:users, "married:true AND age:35")
    assert nodes.length == 1
    assert nodes[0]["username"] == "lea"
  end
  
  def test_OR_condition
    nodes = search(:users, "age:42 OR age:22")
    assert nodes.length == 2
  end
  
  def test_NOT_condition
    nodes = search(:users, "children:tom AND (NOT gender:female)")
    assert nodes.length == 1
    nodes = search(:users, "children:tom AND (NOT gender:female) AND age:42")
    assert nodes.length == 1
    nodes = search(:users, "children:tom AND (NOT gender:female) AND (NOT age:42)")
    assert nodes.length == 0
  end
  
  def test_any_value
    nodes = search(:users, "children:*")
    assert nodes.length == 2
  end
  
  def test_any_value_lucene_range
    nodes = search(:users, "address:[* TO *]")
    assert nodes.length == 2
  end
  
  def test_general_lucene_range_fails
    assert_raises RuntimeError do
      nodes = search(:users, "children:[aaa TO zzz]")
    end
  end
  
  def test_block_usage
    # bracket syntax
    result = []
    search(:users, "*:*") {|x| result << x["id"]}
    assert result.length == 4
    
    # do...end syntax
    result = []
    search(:users) do |x|
      result << x["id"]
    end
    assert result.length == 4
  end
  
  def test_check_escaped_chars
    nodes = search(:users, 'tag:tag\:\:test')
    assert nodes.length == 1
    nodes = search(:users, "tag:tag\\:\\:test")
    assert nodes.length == 1
    nodes = search(:users, 'tags:tag\:\:first')
    assert nodes.length == 1
    nodes = search(:users, "tags:tag\\:\\:first")
    assert nodes.length == 1
    nodes = search(:users, 'tags:tag\:\:*')
    assert nodes.length == 1
    nodes = search(:users, "tags:tag\\:\\:*")
    assert nodes.length == 1
  end
  
  def test_wildcards
    nodes = search(:users, "gender:f??ale")
    assert nodes.length == 1
    nodes = search(:users, "username:spee?y")
    assert nodes.length == 1
    nodes = search(:users, "username:spee*")
    assert nodes.length == 1
  end
  
  def test_empty_field_value
    assert_raise(RuntimeError) {
      search(:users, "gender:#{nil} AND age:35")
    }
    assert_raise(RuntimeError) {
      search(:users, "gender: AND age:35")
    }
    assert_raise(RuntimeError) {
      search(:users, "gender:\"\" AND age:35")
    }
  end
  
  def test_OR_group
    nodes = search(:users, "id:(mike OR tom)")
    assert nodes.length == 2
  end
  
  def test_nested_fieldnames
    nodes = search(:users, "address_street:wilhelmsstrasse")
    assert nodes.length == 1
    nodes = search(:users, "address_street_floor:1")
    assert nodes.length == 1
  end
end

class TestSearchNode < Test::Unit::TestCase
  def test_list_nodes
    nodes = search(:node)
    assert_equal Chef::Node, nodes.first.class
    assert_equal 2, nodes.length
  end

  def test_search_node_with_wide_filter
    nodes = search(:node, "role:test_server AND chef_environment:default")
    assert_equal 2, nodes.length
  end

  def test_search_node_with_narrow_filter
    nodes = search(:node, "role:beta_server")
    assert_equal 1, nodes.length
  end

  def test_search_node_with_attr_filter
    nodes = search(:node, "hostname:beta.example.com")
    assert_equal 1, nodes.length
  end
end

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

def data_bag_item(bag, item)
  # wrapper around creating a new Recipe instance and calling data_bag on it
  node = Chef::Node.new()
  events = Chef::EventDispatch::Dispatcher.new
  cookbooks = Chef::CookbookCollection.new()
  run_context = Chef::RunContext.new(node, cookbooks, events)
  return Chef::Recipe.new("test_cookbook", "test_recipe", run_context).data_bag_item(bag, item)
end

class TestDataBags < Test::Unit::TestCase

  def test_data_bag
    item = data_bag_item("users", "mike")
    assert_equal item["age"], 42
    assert_equal item[:age], nil    #upstream code for chef-solo does not use mashes
  end

end

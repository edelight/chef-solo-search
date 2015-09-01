#
# Copyright 2011, edelight GmbH
#
# Authors:
#       Markus Korn <markus.korn@edelight.de>
#       Seth Chisamore <schisamo@opscode.com>
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

unless defined?(Chef::EncryptedDataBagItem::UnacceptableEncryptedDataBagItemFormat)
  class Chef::EncryptedDataBagItem::UnacceptableEncryptedDataBagItemFormat < StandardError
  end
end

module Search
  module Overrides
    # Overwrite the search method of recipes to operate locally by using
    # data found in data_bags.
    # Only very basic lucene syntax is supported and also sorting the result
    # is not implemented, if this search method does not support a given query
    # an exception is raised.
    # This search() method returns a block iterator or an Array, depending
    # on how this method is called.
    def search(obj, query=nil, sort=nil, start=0, rows=1000, &block)
      if !sort.nil? and sort.keys != [:filter_result]
        raise "Sorting search results is not supported"
      end
      _query = Query.parse(query)
      if _query.nil?
        raise "Query #{query} is not supported"
      end
      _result = []

      case obj
      when :node
        nodes = search_nodes(_query, start, rows, &block)
        _result += nodes
      when :role
        roles = search_roles(_query, start, rows, &block)
         _result += roles
      else
        bags = search_data_bag(_query, obj, start, rows, &block)
        _result += bags
      end

      if sort.respond_to?(:has_key?) and sort.has_key?(:filter_result)
        _result.map! { |r| apply_filter_result(r, sort[:filter_result]) }
      end

      if block_given?
        pos = 0
        while (pos >= start and pos < (start + rows) and pos < _result.size)
          yield _result[pos]
          pos += 1
        end
      else
        return _result.slice(start, rows)
      end
    end

    def apply_filter_result(result, filter)
      filtered = {}
      filter.each_pair do |k, path|
        filtered[k.to_s] = hash_path(result, path)
      end
      filtered
    end

    def hash_path(value, path)
      path.each do |k|
        value = value[k]
      end
      value
    rescue
      nil
    end

    def search_nodes(_query, start, rows, &block)
      _result = []
      node_path = Chef::Config[:nodes_path] || File.join(Chef::Config[:data_bag_path], "node")
      Dir.glob(File.join(node_path, "*.json")).map do |f|
        # parse and hashify the node
        node = Chef::JSONCompat.from_json(IO.read(f))
        if _query.match(node.to_hash)
          _result << node
        end
      end
      return _result
    end

    def search_roles(_query, start, rows, &block)
      _result = []
      Dir.glob(File.join(Chef::Config[:role_path], "{*.json,*.rb}")).map do |f|
        if f.end_with? '.json'
          # parse and hashify the role
          role = Chef::JSONCompat.from_json(IO.read(f))
          if _query.match(role.to_hash)
            _result << role
          end
        elsif f.end_with? '.rb'
          # This assumes the filename matches the role name, there may be a better way
          role = Chef::Role.from_disk(File.basename(f).split('.')[0..-2].join('.'))
          if _query.match(role.to_hash)
            _result << role
          end
        end

      end
      _result
    end

    def load_data_bag(bag_name, bag_item_id)
      if Chef::Config[:encrypted_data_bag_secret]
        begin
          bag_item = Chef::EncryptedDataBagItem.load(bag_name, bag_item_id).to_hash
        rescue Chef::EncryptedDataBagItem::DecryptionFailure,Chef::EncryptedDataBagItem::UnacceptableEncryptedDataBagItemFormat
          bag_item = nil
        rescue NoMethodError => e
          raise e unless e.message =~ /undefined method `unpack' for/
          bag_item = nil
        rescue ArgumentError => e
          raise e unless e.message =~ /data must not be empty/
          bag_item = nil
        rescue NameError => e
          raise e unless e.message =~ /`format_version' for Chef::EncryptedDataBagItem::Decryptor:Module/
          bag_item = nil
        end

      end

      bag_item ||= data_bag_item(bag_name.to_s, bag_item_id)
    end

    def search_data_bag(_query, bag_name, start, rows, &block)
      _result = []
      data_bag(bag_name.to_s).each do |bag_item_id|
        bag_item = load_data_bag(bag_name, bag_item_id)

        if _query.match(bag_item)
          _result << bag_item
        end
      end
      return _result
    end
  end
end

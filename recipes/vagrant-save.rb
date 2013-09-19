# This recipe saves node data to the vagrant path
# This allows saved nodes to automatically appear in searches

directory "/vagrant/data_bags/node" do
	mode 00755
end

template "/vagrant/data_bags/node/#{node.hostname}.json" do
	mode 00644
	source 'vagrant.json.erb'
end

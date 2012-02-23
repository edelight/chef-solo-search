maintainer       "edelight GmbH"
maintainer_email "markus.korn@edelight.de"
license          "Apache 2.0"
description      "Data bag search for Chef Solo"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.4.0"

%w{ ubuntu debian redhat centos fedora freebsd}.each do |os|
  supports os
end

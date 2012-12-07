require 'rubygems'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
if ENV['ECETUNNEL']
  DataMapper.setup(:default, 'mysql://jacob:whatever@localhost/group4')
else
  DataMapper.setup(:default, 'mysql://group4:YQupPp9E@mysqlsrv.ece.ualberta.ca:13010/group4')
end


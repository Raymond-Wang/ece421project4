require 'rubygems'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
if ENV['ECETUNNEL']
  DataMapper.setup(:default, 'mysql://group4:group4_M547f3es@posterevent.com:3306/group4')
else
  DataMapper.setup(:default, 'mysql://group4:YQupPp9E@mysqlsrv.ece.ualberta.ca:13010/group4')
end


require 'rubygems'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'mysql://group4:YQupPp9E@mysqlsrv.ece.ualberta.ca:13010/group4')


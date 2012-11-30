require 'rubygems'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default,'mysql://group4:group4_M547f3es@posterevent.com/group4')


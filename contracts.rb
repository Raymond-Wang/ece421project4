# Author: Jacob Straszynski
#
# A simple DBC module.
# Use the environment variable RUBY_CONTRACTS to enable.
# Optionally, if the `pry' gem is available, you can jump into an interactive
# interpretter.
#
# Disable contracts in production. Enable them during testing and also enable
# pry for root cause analysis.
class ContractError < StandardError; end
class PreconditionError < ContractError; end
class PostconditionError < ContractError; end
class InvariantError < ContractError; end

module Contracts
  def precondition
    if ENV["RUBY_CONTRACTS"]
      begin
        yield
      rescue Exception => e
        check_pry
        raise PreconditionError, "Precondition Failed:" + e.message, e.backtrace
      end
    end
  end
  def postcondition
    if ENV["RUBY_CONTRACTS"]
      begin
        yield
      rescue Exception => e
        check_pry
        raise PostconditionError, "Postcondition Failed:" + e.message, e.backtrace 
      end
    end
  end
  def invariant
    if ENV["RUBY_CONTRACTS"]
      begin
        yield
      rescue Exception => e
        check_pry
        raise InvariantError, "Invariant Failed:" + e.message, e.backtrace 
      end
    end
  end
  def check_pry
    if ENV["RUBY_CONTRACTS_PRY"]
      binding.pry
    end
  end
end

class Object
  include Contracts
end

require "test/unit"
require "./contracts"

class TestClass
  def initialize(val=nil,other=nil)
    precondition do
      if val.nil?
        raise "Failed."
      end
    end
    postcondition do
      if other.nil?
        raise "Failed."
      end
    end
  end
end

class ContractsTest < Test::Unit::TestCase
  def test_precon_raise_type
    assert_raise PreconditionError do
      test = TestClass.new nil
    end
  end
  def test_postcondition_raise_type
    assert_raise PostconditionError do
      test = TestClass.new nil
    end
  end
end

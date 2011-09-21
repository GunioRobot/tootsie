# encoding: utf-8

require 'spec_helper'

describe Tootsie::CommandRunner do

  it 'run simple commands' do
    Tootsie::CommandRunner.new('ls').run.should == true
  end

  it 'replace arguments in command lines' do
    lines = []
    Tootsie::CommandRunner.new('echo :text').run(:text => "test") do |line|
      lines << line.strip
    end
    lines.should == ["test"]
  end

  it 'throw exceptions on failure' do
    lambda { Tootsie::CommandRunner.new('exit 1').run }.should raise_error(
      Tootsie::CommandExecutionFailed)
  end

  it 'not throw exceptions on failure with option' do
    lambda { Tootsie::CommandRunner.new('exit 1', :ignore_exit_code => true).run }.should_not raise_error
    Tootsie::CommandRunner.new('exit 1', :ignore_exit_code => true).run.should == false
  end

end

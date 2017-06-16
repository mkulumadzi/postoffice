require_relative '../../spec_helper'

describe 'get certificate files from aws if necessary' do

  before do
    if File.exists?('tmp/test.txt')
      File.delete('tmp/test.txt')
    end
  end

  it 'must get the file and save it in the directory' do
    get_certificate_file_from_aws_if_neccessary 'test.txt', 'tmp'
    File.exists?('tmp/test.txt').must_equal true
  end

  it 'must have saved the contents of the file' do
    get_certificate_file_from_aws_if_neccessary 'test.txt', 'tmp'
    f = File.open('tmp/test.txt', 'r')
    contents = f.read
    f.close
    contents.must_include "Hello world"
  end

end

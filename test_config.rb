require 'test/unit'
require_relative 'configParser'
include Config


#unit tests for load_config
class TestConfig < Test::Unit::TestCase

  # Verify empty or bad input path error is raised.
  def test_invalid_path
    e = assert_raise(RuntimeError) { load_config('bad file path') }
    assert_equal('Provide valid file path ', e.message)
  end

  # Verify config values when no overrides are provided
  def test_no_overrides
    config = load_config('test_files/valid_test_case.conf')

    assert_equal(26214400, config.common.basic_size_limit)
    assert_equal(52428800, config.common.student_size_limit)
    assert_equal(2147483648, config.common.paid_users_size_limit)
    assert_equal('/srv/var/tmp/', config.common.path)
    assert_equal('hello there, ftp uploading', config.ftp.name)
    assert_equal('/tmp/', config.ftp.path)
    assert_equal('/tmp/', config.ftp[:path])
    assert_equal(false, config.ftp.enabled)
    assert_equal('http uploading', config.http.name)
    assert_equal('/tmp/', config.http.path)
    assert_equal(%w(array of values), config.http.params)
    assert_equal({:name => 'hello there, ftp uploading', :path => '/tmp/', :enabled => false}, config.ftp)
    assert_equal(nil, config.http[:'foo bar'])
    assert_nil(config.ftp.foo)
  end

  # Verify load_config loads the correct values when overrides are provided.
  def test_with_overrides
    config = load_config('test_files/valid_test_case.conf', ['ubuntu', :production])

    assert_equal(26214400, config.common.basic_size_limit)
    assert_equal(52428800, config.common.student_size_limit)
    assert_equal(2147483648, config.common.paid_users_size_limit)
    assert_equal('/srv/var/tmp/', config.common.path)
    assert_equal('hello there, ftp uploading', config.ftp.name)
    assert_equal('/etc/var/uploads', config.ftp.path)
    assert_equal('/etc/var/uploads', config.ftp[:path])
    assert_equal(true, config.ftp.enabled)
    assert_equal('http uploading', config.http.name)
    assert_equal('/srv/var/tmp/', config.http.path)
    assert_equal(%w(array of values), config.http.params)
    assert_equal({:name => 'hello there, ftp uploading', :path => '/etc/var/uploads', :enabled => true}, config.ftp)
    assert_equal(nil, config.http[:'foo bar'])
    assert_nil(config.ftp.foo)
  end

  # Verify load_config handles empty values.
  def test_empty_value_in_pair
    config = load_config('test_files/nil_value_in_pair.conf')

    assert_equal('', config.common.student_size_limit)
  end

  # Verify load_config blows up when a malformed config file is provided such that it
  # has an invalid override key.
  def test_invalid_override
    e = assert_raise(RuntimeError) { load_config('test_files/invalid_override.conf') }
    assert_equal('Invalid config file at line: path<> = /srv/var/tmp/', e.message)
  end

  # Verify load_config blows up when a malformed config file is provided such that it
  # has an invalid key.
  def test_invalid_key
    e = assert_raise(RuntimeError) { load_config('test_files/invalid_key.conf') }
    assert_equal('Invalid config file at line: = /srv/var/tmp/', e.message)
  end

  # Verify load_config blows up when a malformed config file is provided such that it
  # has a section with whitespace in the name.
  def test_invalid_group
    e = assert_raise(RuntimeError) { load_config('test_files/invalid_group_name.conf') }
    assert_equal('Invalid group name common ftp', e.message)
  end

  # Verify load_config blows up when a malformed config file is provided such that it
  # has duplicate sections.
  def test_repeated_section
    e = assert_raise(RuntimeError) { load_config('test_files/duplicate_group.conf') }
    assert_equal('Repeated group. Invalid config file. common', e.message)
  end

  # Verify load_config blows up when a malformed config file is provided such that it
  # has an invalid key-value assignment.
  def test_invalid_key_value_pair
    e = assert_raise(RuntimeError) { load_config('test_files/invalid_key_value_pair.conf') }
    assert_equal('Incorrectly formed config file at basic_size_limit: 26214400', e.message)
  end

end
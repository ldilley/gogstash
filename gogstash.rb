# GogStash - A gog.com downloader written in Ruby
# Copyright (C) 2017 Lloyd Dilley
# http://www.dilley.me/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

require 'io/console' # for password input with no echo

VERSION = '0.1a'
LOGIN_PAGE = 'https://login.gog.com/login'

def log_init
  begin
    directory_name = 'logs'
    Dir.mkdir(directory_name) unless File.exists?(directory_name) && File.writable?(directory_name)
  rescue => exception
    puts "Unable to create #{directory_name} directory: #{exception}"
    exit!
  end
end

def log_write(severity, text)
  # Below actually returns an array, so we check for emptiness and not nil/true/false
  Dir.mkdir('logs') if Dir['logs'].empty?
  case severity
  when 0
    level = 'DBUG'
  when 1
    level = 'AUTH'
  when 2
    level = 'INFO'
  when 3
    level = 'WARN'
  when 4
    level = 'CRIT'
  else
    level = 'DBUG'
  end
  log_file = File.open('logs/gogstash.log', 'a')
  log_file.puts "#{Time.now.asctime} #{level}: #{text}"
  log_file.close
  rescue => exception
    puts "Unable to write log file: #{exception}"
end

# Send output to both stdout and log
def duplex_write(severity, text)
  puts text
  log_write(severity, text)
end

# Enforce proper Ruby version
def version_check
  if RUBY_VERSION < '1.9'
    duplex_write(4, 'GogStash requires Ruby >=1.9!')
    exit!
  end
end

# Check if Mechanize is available
def dependency_check
  begin
    gem('mechanize', '>=2.7.5')
    require 'mechanize'
  rescue Gem::LoadError
    duplex_write(4, 'Mechanize gem not found!')
    exit!
  end
end

def web_login
  begin
    cookie_file = 'cookie.yml'
    mechanize = Mechanize.new
    #mechanize.verify_mode = OpenSSL::SSL::VERIFY_NONE # for testing with invalid/self-signed certificates

    if File.exists?(cookie_file)
      mechanize.cookie_jar.load cookie_file
    else
      email_address = nil
      password = nil

      while email_address.nil? || email_address.empty? do
        print 'Enter your gog.com e-mail address: '
        email_address = gets.chomp.strip
        puts 'Invalid e-mail address!' if email_address.nil? || email_address.empty?
      end

      while password.nil? || password.empty? do
        print 'Enter your gog.com password: '
        password = STDIN.noecho(&:gets).chomp.strip
        puts '' # fixes \r\n problem after using noecho
        puts 'Invalid password!' if password.nil? || password.empty?
      end

      login_page = mechanize.get LOGIN_PAGE
      web_form = login_page.forms.first
      if web_form.nil?
        duplex_write(4, "Unable to log into #{LOGIN_PAGE}: No form?")
        exit!
      end      
      web_form.field_with(id: 'login_username').value = email_address
      web_form.field_with(id: 'login_password').value = password
      web_form.submit
      mechanize.cookie_jar.save_as cookie_file
    end
    
# Temporary debug stuff
#results = mechanize.get("https://www.gog.com/account")
results = mechanize.get("https://www.gog.com/account/wishlist")
log_write(1, results.content)
# End temporary debug stuff

  rescue => exception
    duplex_write(4, "Unable to log into #{LOGIN_PAGE}: #{exception}")
    exit!
  end
end

# main()
puts "GogStash #{VERSION}"
puts 'Initializing logging...'
log_init
log_write(2, "GogStash #{VERSION}")
duplex_write(2, 'Checking Ruby version...')
version_check
duplex_write(2, 'Checking for dependencies...')
dependency_check
duplex_write(2, "Logging in to #{LOGIN_PAGE}...")
web_login
# ToDo: Allow downloading of films and games after authentication.

require "compass-twitter-bootstrap/version"

if defined?(::Rails) && ::Rails.version >= "3.1"
  require 'compass-twitter-bootstrap/engine'
end

require 'compass'
Compass::Frameworks.register("twitter-bootstrap", :path => "#{File.dirname(__FILE__)}/..")

module CompassTwitterBootstrap
  STYLESHEETS = File.expand_path("../stylesheets", __FILE__)
end

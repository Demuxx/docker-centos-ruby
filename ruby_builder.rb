#!/usr/bin/env ruby
require 'faraday'
require 'erb'
require 'fileutils'
require 'open3'
require 'logger'

@log = Logger.new("logs/ruby_builder.log")
@log.level = Logger::DEBUG

class Repo
  attr_accessor :versions

  def initialize(url="https://cache.ruby-lang.org/pub/ruby/index.txt")
    self.versions ||= []
    links = Faraday.get("https://cache.ruby-lang.org/pub/ruby/index.txt").body.split("\n")
    for link in links
      version = Version.parse(link)
      unless version.nil?
        self.versions << version
      end
    end
  end

  def gzs
    self.versions.select {|v| v.gz? }
  end

  def zips
    self.versions.select {|v| v.zip? }
  end

  def bz2s
    self.versions.select {|v| v.bz2? }
  end
end

class Version
  attr_accessor :name, :link, :shaone, :shatwo, :shafive

  def initialize(name, link, shaone, shatwo, shafive)
    @name = name
    @link = link
    @shaone = shaone
    @shatwo = shatwo
    @shafive = shafive
    return self
  end

  def self.parse(line)
    name, link, shaone, shatwo, shafive = line.split("\t")
    if link == "url"
      return nil
    else
      return self.new(name, link, shaone, shatwo, shafive)
    end
  end

  def compression
    if self.gz?
      return "gz"
    elsif self.zip?
      return "zip"
    elsif self.bz2?
      return "bz2"
    else
      return "unknown"
    end
  end

  def excluded?
    File.read("excludes.txt").split("\n").include?(self.release)
  end

  def gz?
    /gz$/.match(self.link)
  end

  def zip?
    /zip$/.match(self.link)
  end

  def bz2?
    /bz2$/.match(self.link)
  end

  def major
    /(-)([0-9]\.[0-9])/.match(self.name)[2].to_s
  end

  def release
    /(-)([0-9]\.[0-9].*)/.match(self.name)[2].to_s
  end
end

@log.debug "Pulling all ruby versions"
repo = Repo.new
@log.debug "Reading the Dockerfile template"
e = ERB.new(File.read("Dockerfile.erb"))
@log.debug "Iterating over release versions of ruby"
for @version in repo.gzs.select {|v| !v.excluded? }
  begin
    @log.debug "Creating version directory for: #{@version.release}"
    dir = Dir.mkdir(@version.release)
    @log.debug "Creating the Dockerfile for: #{@version.release}"
    file = File.new("#{@version.release}/Dockerfile", "w+")
    file << e.result
    file.close
    @log.debug "Copying ruby.conf and profile.d-ruby.sh to: #{@version.release}"
    FileUtils.cp("ruby.conf", @version.release)
    FileUtils.cp("profile.d-ruby.sh", @version.release)
  rescue
    @log.debug "Already created Dockerfile for: #{@version.release}"
  end

  @log.debug "Moving in to build directory for #{@version.release}"
  FileUtils.cd(@version.release) do
    command = "docker build --tag prandium/centos-ruby:#{@version.release} ."
    @log.debug "Running command: #{command}"
    stdout, stderr, status = Open3.capture3(command)
    unless stderr.empty?
      @log.error "BUILD FAILED FOR #{@version.release}"
      FileUtils.touch("broken")
      @log.debug "Removing the intermediate docker images"
      rm_command = "docker images | grep \"<none>\" | awk '{ print $3 }' | xargs docker rmi -f"
      stdout, stderr, status = Open3.capture3(rm_command)
    else
      @log.info "Build successful for #{@version.release}"
    end
  end
end 

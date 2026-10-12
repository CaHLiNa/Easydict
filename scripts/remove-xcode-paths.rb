#!/usr/bin/env ruby
# Removes the given files/directories from Easydict.xcodeproj.
# Usage: ruby scripts/remove-xcode-paths.rb <list-file>
# List file lines: repository-relative path, or "phase:<shell script phase name>".

require 'xcodeproj'

PROJECT = 'Easydict.xcodeproj'.freeze
root = File.expand_path('.')

entries = File.readlines(ARGV.fetch(0)).map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
targets = entries.reject { |entry| entry.start_with?('phase:') }.map { |path| File.expand_path(path, root) }
phase_names = entries.select { |entry| entry.start_with?('phase:') }.map { |entry| entry.sub('phase:', '') }

project = Xcodeproj::Project.open(PROJECT)

removed_refs = 0
project.files.dup.each do |file_ref|
  real = file_ref.real_path.to_s
  next unless targets.any? { |target| real == target || real.start_with?(target + '/') }

  file_ref.build_files.dup.each(&:remove_from_project)
  file_ref.remove_from_project
  removed_refs += 1
end

removed_phases = []
project.targets.each do |target|
  target.shell_script_build_phases.dup.each do |phase|
    next unless phase_names.include?(phase.name)

    phase.remove_from_project
    removed_phases << "#{target.name}/#{phase.name}"
  end
end

removed_groups = 0
loop do
  empty = project.main_group.recursive_children.select do |child|
    child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.children.empty? &&
      targets.any? { |target| child.real_path.to_s == target || child.real_path.to_s.start_with?(target + '/') }
  end
  break if empty.empty?

  empty.each do |group|
    group.remove_from_project
    removed_groups += 1
  end
end

project.save

verify = Xcodeproj::Project.open(PROJECT)
leftovers = verify.files.map { |file| file.real_path.to_s }.select do |real|
  targets.any? { |target| real == target || real.start_with?(target + '/') }
end

puts "removed file refs: #{removed_refs}"
puts "removed groups: #{removed_groups}"
puts "removed phases: #{removed_phases.inspect}"
puts "leftovers: #{leftovers.inspect}"
exit(leftovers.empty? ? 0 : 1)

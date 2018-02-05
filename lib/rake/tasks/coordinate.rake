# encoding: utf-8
require 'lib/utils/amap.rb'
namespace :coordinate do
  task geocode: :environment do
    User.where("coordinate is not null and coordinate_location is null").each do |record|
      next if record.coordinate.empty?

      coordinate_location = AMAP::Geocode.coordinate_location(record.coordinate, {key: Setting.amap.geocode_key})
      record.update_attributes!({coordinate_location: coordinate_location})
    end
    ActionLog.where("coordinate is not null and coordinate_location is null").each do |record|
      next if record.coordinate.empty?

      coordinate_location = AMAP::Geocode.coordinate_location(record.coordinate, {key: Setting.amap.geocode_key})
      record.update_attributes!({coordinate_location: coordinate_location})
    end
  end
end

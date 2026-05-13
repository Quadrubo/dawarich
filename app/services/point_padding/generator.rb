# frozen_string_literal: true

module PointPadding
  class Generator
    INTERPOLATIONS = %w[evenly].freeze
    DIRECTIONS = %w[before after].freeze

    MIN_COUNT = 1
    MAX_COUNT = 100
    MIN_DURATION_SECONDS = 1
    MAX_DURATION_SECONDS = 7 * 24 * 60 * 60

    SPATIAL_STEP_METERS = 10.0
    METERS_PER_DEGREE_LAT = 111_320.0

    class InvalidParams < StandardError; end

    def initialize(source_point:, direction:, count:, duration_seconds:, user:, interpolation: 'evenly')
      @source_point = source_point
      @direction = direction.to_s
      @count = count.to_i
      @duration_seconds = duration_seconds.to_i
      @interpolation = interpolation.to_s
      @user = user

      validate!
    end

    def build_points
      timestamps = generate_timestamps
      offsets = spatial_offsets

      timestamps.each_with_index.map do |ts, i|
        lon, lat = offsets[i]
        @user.points.new(lonlat: "POINT(#{lon} #{lat})", timestamp: ts, source: :inferred)
      end
    end

    private

    def validate!
      raise InvalidParams, "unknown direction: #{@direction}" unless DIRECTIONS.include?(@direction)
      raise InvalidParams, "unknown interpolation: #{@interpolation}" unless INTERPOLATIONS.include?(@interpolation)
      raise InvalidParams, 'count out of range' unless @count.between?(MIN_COUNT, MAX_COUNT)
      raise InvalidParams, 'duration out of range' unless @duration_seconds.between?(MIN_DURATION_SECONDS,
                                                                                     MAX_DURATION_SECONDS)
    end

    def generate_timestamps
      sign = @direction == 'before' ? -1 : 1
      step = @duration_seconds.to_f / @count

      (1..@count).map do |i|
        @source_point.timestamp + (sign * (i * step)).to_i
      end
    end

    def spatial_offsets
      sign = @direction == 'before' ? -1 : 1
      base_lon = @source_point.lon
      base_lat = @source_point.lat

      lon_per_meter = 1.0 / (METERS_PER_DEGREE_LAT * Math.cos(base_lat * Math::PI / 180.0))

      (1..@count).map do |i|
        offset_degrees = sign * i * SPATIAL_STEP_METERS * lon_per_meter
        [base_lon + offset_degrees, base_lat]
      end
    end
  end
end

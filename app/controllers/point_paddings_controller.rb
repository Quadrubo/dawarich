# frozen_string_literal: true

class PointPaddingsController < ApplicationController
  include FlashStreamable

  before_action :authenticate_user!
  before_action :load_source_point

  after_action :verify_authorized

  def create
    authorize :point_padding, :create?

    new_points = PointPadding::Generator.new(
      source_point: @source_point,
      direction: params[:direction],
      count: params[:count],
      duration_seconds: params[:duration_seconds],
      interpolation: params[:interpolation].presence || 'evenly',
      user: current_user
    ).build_points

    Point.transaction do
      import = current_user.imports.create!(
        name: padding_import_name,
        source: :geojson,
        status: :completed,
        skip_background_processing: true
      )

      import.file.attach(
        io: StringIO.new(import_payload(new_points)),
        filename: "point_padding_#{import.id}.geojson",
        content_type: 'application/json'
      )

      new_points.each do |point|
        point.import = import
        point.save!
      end

      import.update_columns(points_count: new_points.size, processed: new_points.size)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: stream_flash(:notice, "Added #{new_points.size} padding points")
      end
      format.html do
        redirect_to map_v2_path, notice: "Added #{new_points.size} padding points", status: :see_other
      end
    end
  rescue PointPadding::Generator::InvalidParams => e
    respond_to do |format|
      format.turbo_stream { render turbo_stream: stream_flash(:error, e.message) }
      format.html { redirect_to map_v2_path, alert: e.message, status: :see_other }
    end
  end

  private

  def load_source_point
    @source_point = current_user.points.find(params[:source_point_id])
  end

  def padding_import_name
    direction = params[:direction].to_s
    time = Time.zone.at(@source_point.timestamp).strftime('%Y-%m-%d %H:%M')
    "Point padding (#{direction}, #{time})"
  end

  def import_payload(points)
    {
      type: 'FeatureCollection',
      features: points.map do |p|
        {
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [p.lon, p.lat] },
          properties: { timestamp: p.timestamp, source_point_id: @source_point.id }
        }
      end
    }.to_json
  end
end

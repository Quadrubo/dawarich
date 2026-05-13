# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PointPadding::Generator do
  let(:user) { create(:user) }
  let(:source_point) do
    create(:point, user: user, lonlat: 'POINT(13.4050 52.5200)', timestamp: 1_700_000_000)
  end

  describe '#build_points' do
    context 'with valid params (after, 5 points over 1 hour)' do
      subject(:points) do
        described_class.new(
          source_point: source_point,
          direction: 'after',
          count: 5,
          duration_seconds: 3600,
          user: user
        ).build_points
      end

      it 'returns the requested number of points' do
        expect(points.size).to eq(5)
      end

      it 'spaces timestamps evenly inside the window after the source' do
        offsets = points.map { |p| p.timestamp - source_point.timestamp }
        expect(offsets).to eq([720, 1440, 2160, 2880, 3600])
      end

      it 'offsets longitude east of the source for each point' do
        lons = points.map(&:lon)
        expect(lons).to all(be > source_point.lon)
        expect(lons).to eq(lons.sort)
      end

      it 'keeps latitude equal to the source' do
        expect(points.map(&:lat)).to all(be_within(1e-9).of(source_point.lat))
      end

      it 'marks generated points as inferred' do
        expect(points.map(&:source)).to all(eq('inferred'))
      end
    end

    context 'with count: 1 (single-point edge case)' do
      subject(:points) do
        described_class.new(
          source_point: source_point,
          direction: 'after',
          count: 1,
          duration_seconds: 600,
          user: user
        ).build_points
      end

      it 'returns exactly one point' do
        expect(points.size).to eq(1)
      end

      it 'places it at the far end of the time window' do
        expect(points.first.timestamp - source_point.timestamp).to eq(600)
      end
    end

    context 'with count at MAX_COUNT' do
      it 'returns MAX_COUNT points' do
        result = described_class.new(
          source_point: source_point,
          direction: 'after',
          count: described_class::MAX_COUNT,
          duration_seconds: 3600,
          user: user
        ).build_points

        expect(result.size).to eq(described_class::MAX_COUNT)
      end
    end

    context 'with direction: before' do
      subject(:points) do
        described_class.new(
          source_point: source_point,
          direction: 'before',
          count: 3,
          duration_seconds: 600,
          user: user
        ).build_points
      end

      it 'places timestamps before the source' do
        expect(points.map(&:timestamp)).to all(be < source_point.timestamp)
      end

      it 'offsets longitude west of the source' do
        expect(points.map(&:lon)).to all(be < source_point.lon)
      end
    end

    describe 'parameter validation' do
      let(:base_params) do
        {
          source_point: source_point,
          direction: 'after',
          count: 5,
          duration_seconds: 60,
          user: user
        }
      end

      it 'rejects unknown direction' do
        expect { described_class.new(**base_params.merge(direction: 'sideways')) }
          .to raise_error(described_class::InvalidParams, /direction/)
      end

      it 'rejects count of 0' do
        expect { described_class.new(**base_params.merge(count: 0)) }
          .to raise_error(described_class::InvalidParams, /count/)
      end

      it 'rejects count above the cap' do
        expect { described_class.new(**base_params.merge(count: 101)) }
          .to raise_error(described_class::InvalidParams, /count/)
      end

      it 'rejects negative duration' do
        expect { described_class.new(**base_params.merge(duration_seconds: -1)) }
          .to raise_error(described_class::InvalidParams, /duration/)
      end

      it 'rejects unknown interpolation' do
        expect { described_class.new(**base_params.merge(interpolation: 'logarithmic')) }
          .to raise_error(described_class::InvalidParams, /interpolation/)
      end
    end
  end
end

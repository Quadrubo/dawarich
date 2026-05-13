# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gapfill::Router do
  subject(:router) { described_class.new(brouter_url: 'https://brouter.test/brouter') }

  let(:from) { { lon: 13.3888, lat: 52.5170 } }
  let(:to) { { lon: 13.4050, lat: 52.5200 } }

  let(:coords) { [[13.3888, 52.5170], [13.3950, 52.5180], [13.4050, 52.5200]] }

  let(:geojson_response) do
    {
      'type' => 'FeatureCollection',
      'features' => [
        {
          'type' => 'Feature',
          'geometry' => { 'type' => 'LineString', 'coordinates' => coords }
        }
      ]
    }.to_json
  end

  describe '#route' do
    context 'with a successful response' do
      before do
        stub_request(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(profile: 'car-vario', format: 'geojson'))
          .to_return(status: 200, body: geojson_response)
      end

      it 'returns an array of coordinate pairs' do
        result = router.route(from: from, to: to, mode: 'Car')
        expect(result).to eq(coords)
      end
    end

    context 'with an alternative index' do
      before do
        stub_request(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(alternativeidx: '2'))
          .to_return(status: 200, body: geojson_response)
      end

      it 'passes the alternative index to BRouter' do
        router.route(from: from, to: to, mode: 'Car', alternative: 2)

        expect(WebMock).to have_requested(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(alternativeidx: '2'))
      end
    end

    context 'with different transport modes' do
      described_class.modes.each do |label, profile|
        it "uses profile #{profile} for #{label}" do
          stub_request(:get, 'https://brouter.test/brouter')
            .with(query: hash_including(profile: profile))
            .to_return(status: 200, body: geojson_response)

          router.route(from: from, to: to, mode: label)
        end
      end
    end

    context 'with an unknown mode' do
      it 'raises RoutingError' do
        expect { router.route(from: from, to: to, mode: 'Helicopter') }
          .to raise_error(Gapfill::Router::RoutingError, /unknown mode/)
      end
    end

    context 'when BRouter returns an HTTP error' do
      before do
        stub_request(:get, /brouter\.test/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises RoutingError' do
        expect { router.route(from: from, to: to, mode: 'Car') }
          .to raise_error(Gapfill::Router::RoutingError, /No route found/)
      end
    end

    context 'when BRouter returns no features' do
      before do
        stub_request(:get, /brouter\.test/)
          .to_return(status: 200, body: { 'type' => 'FeatureCollection', 'features' => [] }.to_json)
      end

      it 'raises RoutingError' do
        expect { router.route(from: from, to: to, mode: 'Car') }
          .to raise_error(Gapfill::Router::RoutingError, /No route found/)
      end
    end

    context 'with via-points' do
      let(:via) { [{ lon: 13.3950, lat: 52.5180 }] }

      before do
        stub_request(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(
            lonlats: '13.3888,52.517|13.395,52.518|13.405,52.52',
            profile: 'car-vario'
          ))
          .to_return(status: 200, body: geojson_response)
      end

      it 'includes via-points in the lonlats parameter' do
        router.route(from: from, to: to, mode: 'Car', via: via)

        expect(WebMock).to have_requested(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(lonlats: '13.3888,52.517|13.395,52.518|13.405,52.52'))
      end
    end

    context 'with multiple via-points' do
      let(:via) do
        [
          { lon: 13.3920, lat: 52.5175 },
          { lon: 13.3980, lat: 52.5190 }
        ]
      end

      before do
        stub_request(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(
            lonlats: '13.3888,52.517|13.392,52.5175|13.398,52.519|13.405,52.52'
          ))
          .to_return(status: 200, body: geojson_response)
      end

      it 'preserves via-point ordering in the lonlats parameter' do
        router.route(from: from, to: to, mode: 'Car', via: via)

        expect(WebMock).to have_requested(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(
            lonlats: '13.3888,52.517|13.392,52.5175|13.398,52.519|13.405,52.52'
          ))
      end
    end

    context 'with empty via-points' do
      before do
        stub_request(:get, 'https://brouter.test/brouter')
          .with(query: hash_including(
            lonlats: '13.3888,52.517|13.405,52.52'
          ))
          .to_return(status: 200, body: geojson_response)
      end

      it 'works the same as without via-points' do
        result = router.route(from: from, to: to, mode: 'Car', via: [])
        expect(result).to eq(coords)
      end
    end

    context 'when the connection fails' do
      before do
        stub_request(:get, /brouter\.test/)
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'raises RoutingError' do
        expect { router.route(from: from, to: to, mode: 'Car') }
          .to raise_error(Gapfill::Router::RoutingError, /Could not connect/)
      end
    end
  end
end

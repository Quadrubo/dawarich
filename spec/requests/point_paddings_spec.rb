# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/point_paddings', type: :request do
  let(:user) { create(:user) }
  let(:source_point) do
    create(:point, user: user, lonlat: 'POINT(13.4050 52.5200)', timestamp: 1_700_000_000)
  end

  let(:valid_params) do
    {
      source_point_id: source_point.id,
      direction: 'after',
      count: 5,
      duration_seconds: 600,
      interpolation: 'evenly'
    }
  end

  context 'when unauthenticated' do
    it 'redirects to sign in' do
      post point_paddings_url, params: valid_params

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before do
      sign_in user
      source_point
    end

    it 'creates the requested number of points' do
      expect do
        post point_paddings_url, params: valid_params
      end.to change { user.points.count }.by(5)
    end

    it 'wraps the new points in an Import' do
      expect do
        post point_paddings_url, params: valid_params
      end.to change { user.imports.count }.by(1)

      import = user.imports.order(:created_at).last
      expect(import.points_count).to eq(5)
      expect(import.name).to match(/Point padding/)
    end

    it 'attaches the generated points as a GeoJSON file on the Import' do
      post point_paddings_url, params: valid_params

      import = user.imports.order(:created_at).last
      expect(import.file).to be_attached
      expect(import.file.content_type).to eq('application/json')

      payload = JSON.parse(import.file.download)
      expect(payload['type']).to eq('FeatureCollection')
      expect(payload['features'].size).to eq(5)
    end

    it 'rejects an unknown interpolation with an alert' do
      post point_paddings_url, params: valid_params.merge(interpolation: 'logarithmic')

      expect(flash[:alert]).to match(/interpolation/)
    end

    it 'redirects to the map with a notice' do
      post point_paddings_url, params: valid_params

      expect(flash[:notice]).to match(/Added 5 padding points/)
    end

    it 'rejects an unknown direction with an alert' do
      post point_paddings_url, params: valid_params.merge(direction: 'sideways')

      expect(flash[:alert]).to match(/direction/)
    end

    it '404s when the source point belongs to another user' do
      other_point = create(:point, user: create(:user))

      post point_paddings_url, params: valid_params.merge(source_point_id: other_point.id)

      expect(response).to have_http_status(:not_found)
    end
  end
end

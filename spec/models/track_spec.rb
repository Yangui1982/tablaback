require 'rails_helper'

RSpec.describe Track, type: :model do
  around { |ex| aggregate_failures(&ex) }
  let(:user)    { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project) }

  describe 'factory' do
    it 'crée un track valide via FactoryBot' do
      track = build(:track, score: score)
      expect(track).to be_valid, -> { "invalide: #{track.errors.full_messages.join(', ')}" }
    end
  end

  describe 'unicité (score_id, name)' do
    it 'refuse deux pistes avec le même nom dans la même partition' do
      create(:track, score: score, name: 'Lead')
      dup = build(:track, score: score, name: 'Lead')

      expect(dup).not_to be_valid
      expect(dup.errors.details[:name].any? { |e| e[:error] == :taken }).to be true
    end

    it 'autorise le même nom dans une autre partition' do
      other_score = create(:score, project: project)
      create(:track, score: score, name: 'Lead')

      same_name_other_score = build(:track, score: other_score, name: 'Lead')
      expect(same_name_other_score).to be_valid
    end
  end

  describe 'unicité (score_id, midi_channel)' do
    it 'refuse deux pistes avec le même canal MIDI dans la même partition' do
      create(:track, score: score, midi_channel: 1, name: 'Guitar 1')
      dup_channel = build(:track, score: score, midi_channel: 1, name: 'Guitar 2')

      expect(dup_channel).not_to be_valid
      expect(dup_channel.errors.details[:midi_channel].any? { |e| e[:error] == :taken }).to be true
    end

    it 'refuse d\'assigner un canal déjà pris lors d\'une mise à jour' do
      create(:track, score: score, midi_channel: 3, name: 'A')
      t2 = create(:track, score: score, midi_channel: 4, name: 'B')
      t2.midi_channel = 3
      expect(t2).to be_invalid
      t2.valid?
      expect(t2.errors.details[:midi_channel].any? { |e| e[:error] == :taken }).to be true
    end

    it 'autorise le même canal MIDI dans une autre partition' do
      other_score = create(:score, project: project)
      create(:track, score: score, midi_channel: 2)

      same_channel_other_score = build(:track, score: other_score, midi_channel: 2)
      expect(same_channel_other_score).to be_valid
    end

    it 'autorise plusieurs pistes sans canal MIDI (nil) dans la même partition' do
      create(:track, score: score, midi_channel: nil)
      second_nil = build(:track, score: score, midi_channel: nil)

      expect(second_nil).to be_valid
    end

    it 'accepte midi_channel nil' do
      t = build(:track, score: score, midi_channel: nil)
      expect(t).to be_valid
    end
  end

  describe 'counter_cache : tracks_count sur Score' do
    it 'incrémente tracks_count à la création' do
      expect {
        create(:track, score: score)
      }.to change { score.reload.tracks_count }.by(1)
    end

    it 'décrémente tracks_count à la suppression' do
      track = create(:track, score: score)
      expect {
        track.destroy
      }.to change { score.reload.tracks_count }.by(-1)
    end
  end

  describe 'plage midi_channel' do
    it 'refuse 0' do
      t = build(:track, score: score, midi_channel: 0)
      expect(t).not_to be_valid
    end

    it 'refuse 17' do
      t = build(:track, score: score, midi_channel: 17)
      expect(t).not_to be_valid
    end

    it 'accepte 1..16' do
      (1..16).each do |ch|
        t = build(:track, score: score, midi_channel: ch)
        expect(t).to be_valid, "attendu valide pour channel #{ch}"
      end
    end
  end

end

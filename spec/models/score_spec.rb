require 'rails_helper'

RSpec.describe Score, type: :model do
  let(:user)    { create(:user) }
  let(:project) { create(:project, user: user) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:tracks).dependent(:destroy) }

    it 'met à jour tracks_count via counter_cache' do
      score = create(:score, project: project)
      expect {
        create(:track, score: score)
      }.to change { score.reload.tracks_count }.by(1)
    end
  end

  describe 'validations' do
    subject { build(:score, project: project) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(200) }

    it 'remplit doc par défaut si nil' do
      s = build(:score, project: project, title: 'Etude', doc: nil)
      expect(s).to be_valid
      s.valid?
      expect(s.doc).to include('schema_version' => 1, 'title' => 'Etude')
    end

    it "valide l'unicité du titre au sein du projet" do
      create(:score, project: project, title: 'Etude')
      dup = build(:score, project: project, title: 'Etude')
      expect(dup).not_to be_valid
      expect(dup.errors.details[:title].any? { |e| e[:error] == :taken }).to be true
    end

    it 'autorise le même titre dans un autre projet' do
      other_project = create(:project, user: user)
      create(:score, project: project, title: 'Same Title')
      same_title_other = build(:score, project: other_project, title: 'Same Title')
      expect(same_title_other).to be_valid
    end

    it 'tempo est entier > 0 (ou nil)' do
      expect(build(:score, project: project, tempo: nil)).to be_valid
      expect(build(:score, project: project, tempo: 120)).to be_valid
      expect(build(:score, project: project, tempo: 0)).not_to be_valid
      expect(build(:score, project: project, tempo: -10)).not_to be_valid
    end
  end

  describe 'enum status' do
    it 'a le mapping entier attendu et la valeur par défaut' do
      expect(described_class.statuses).to eq(
        'draft' => 0, 'processing' => 1, 'ready' => 2, 'failed' => 3
      )
      s = create(:score, project: project)
      expect(s).to be_draft
    end

    it 'peut passer en ready/failed' do
      s = create(:score, project: project)
      s.ready!
      expect(s).to be_ready
      s.failed!
      expect(s).to be_failed
    end
  end

  describe 'attachments (sanity checks)' do
    it 'accepte un fichier source valide (type autorisé)' do
      s = create(:score, project: project)
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/dummy.musicxml'),
        'application/vnd.recordare.musicxml+xml'
      )
      s.source_file.attach(file)
      expect(s).to be_valid
      expect(s.source_file).to be_attached
    end

    it 'refuse un type non autorisé' do
      s = create(:score, project: project)
      bad = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/dummy.txt'),
        'text/plain'
      )
      s.source_file.attach(bad)
      expect(s).not_to be_valid
      expect(s.errors[:source_file]).to be_present
    end

    it 'purge les pièces jointes à la destruction' do
      s = create(:score, project: project)
      file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/dummy.musicxml'),
        'application/vnd.recordare.musicxml+xml'
      )
      s.source_file.attach(file)
      expect(s.source_file).to be_attached

      s.destroy

      expect(
        ActiveStorage::Attachment.where(record_type: 'Score', record_id: s.id)
      ).to be_empty
    end
  end
end

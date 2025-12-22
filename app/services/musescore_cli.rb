require 'open3'
require 'timeout'
require 'shellwords'

class MusescoreCli
  class Error < StandardError; end
  DEFAULT_BIN_CANDIDATES = %w[
    /usr/bin/mscore3
    /usr/bin/mscore
    /usr/local/bin/mscore3
    /usr/local/bin/mscore
  ].freeze

  def initialize(bin: ENV['MUSESCORE_BIN'], wrapper: ENV['MUSESCORE_WRAPPER'])
    @bin     = (bin.presence || detect_binary!)
    @wrapper = wrapper.to_s.strip.presence # ex: "xvfb-run -a"
  end

  # Conversion vers MusicXML compressé (.mxl)
  def to_musicxml(input_path, output_path, timeout_s: 60)
    run!(['-o', output_path], input_path:, label: 'to_musicxml', timeout_s:)
    raise Error, "mxl_not_created: #{output_path}" unless File.exist?(output_path)
    true
  end

  # Rendu MIDI
  def to_midi(input_path, output_path, timeout_s: 30)
    run!(['-o', output_path], input_path:, label: 'to_midi', timeout_s:)
    true
  end

  # Rendu PDF
  def to_pdf(input_path, output_path, timeout_s: 30)
    run!(['-o', output_path], input_path:, label: 'to_pdf', timeout_s:)
    true
  end

  # Rendu PNGs (MuseScore génère page-1.png, page-2.png… si le -o termine par .png)
  def to_pngs(input_path, output_pattern, timeout_s: 45)
    run!(['-o', output_pattern], input_path:, label: 'to_pngs', timeout_s:)
    true
  end

  private

  # Construit argv et exécute la commande de manière sûre (sans shell), avec timeout et logs.
    private

  def run!(extra_args, input_path:, label:, timeout_s:)
    argv = []
    argv.concat(Shellwords.split(@wrapper)) if @wrapper # ex: ["xvfb-run","-a"]
    argv << @bin
    argv << input_path
    argv.concat(Array(extra_args))

    log_info "[MuseScore][#{label}] argv=#{argv.inspect}"

    out = +""
    err = +""
    status = nil

    Open3.popen3(*argv) do |stdin, stdout, stderr, wait_thr|
      stdin.close rescue nil

      t_out = Thread.new { out << stdout.read.to_s }
      t_err = Thread.new { err << stderr.read.to_s }

      # Attente avec timeout sans lever d'exception des threads lecteurs
      unless wait_thr.join(Integer(timeout_s))
        # Timeout : on termine le process proprement puis brutalement si besoin
        begin
          Process.kill('TERM', wait_thr.pid)
        rescue Errno::ESRCH
        end
        # petite latence pour laisser le temps de s'arrêter
        unless wait_thr.join(0.5)
          begin
            Process.kill('KILL', wait_thr.pid)
          rescue Errno::ESRCH
          end
        end
        # On stoppe proprement les threads de lecture
        [t_out, t_err].each { |t| t.kill rescue nil }
        stdout.close rescue nil
        stderr.close rescue nil

        log_error "[MuseScore][#{label}] TIMEOUT after #{timeout_s}s argv=#{argv.inspect}"
        raise Error, "#{label}_timeout"
      end

      # Process terminé dans les temps
      status = wait_thr.value
      # On laisse les threads finir leur lecture
      [t_out, t_err].each { |t| t.join rescue nil }
      stdout.close rescue nil
      stderr.close rescue nil
    end

    log_info  "[MuseScore][#{label}] out=#{out.strip}" if out.present?
    unless status&.success?
      log_error "[MuseScore][#{label}] err=#{err.strip}"
      raise Error, "musescore_failed(#{label})"
    end

    true
  end

  def detect_binary!
    # 1) ENV candidates (si fournis ailleurs dans l’app)
    env_candidates = [
      ENV['MUSESCORE_BIN'],
      `which mscore3 2>/dev/null`.strip.presence,
      `which mscore  2>/dev/null`.strip.presence,
      `which musescore3 2>/dev/null`.strip.presence,
      `which musescore  2>/dev/null`.strip.presence
    ].compact

    candidates = (env_candidates + DEFAULT_BIN_CANDIDATES).uniq
    bin = candidates.find { |p| p.present? && File.exist?(p) }

    raise Error, 'MuseScore CLI introuvable; définis MUSESCORE_BIN' unless bin
    bin
  end

  def log_info(msg)  = Rails.logger.info(msg)
  def log_error(msg) = Rails.logger.error(msg)
end

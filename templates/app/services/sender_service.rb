# Sender.net newsletter sync. Production-only; dev/test short-circuit.
class SenderService
  API_BASE_URL = "https://api.sender.net/v2"

  def self.enabled? = Rails.env.production?

  def self.subscribe(email:, fields: {})
    return { success: true, skipped: true } unless enabled?
    group_id = ENV["SENDER_GROUP_ID"]
    if group_id.blank?
      Rails.logger.error("SenderService: SENDER_GROUP_ID missing — opt-in for #{email} dropped")
      return { success: false }
    end
    uri = URI("#{API_BASE_URL}/subscribers")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json",
      "Authorization" => "Bearer #{ENV["SENDER_API_TOKEN"]}")
    req.body = { email:, groups: [group_id], trigger_automation: true, fields: }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 10) { |h| h.request(req) }
    success = res.is_a?(Net::HTTPSuccess)
    Rails.logger.error("SenderService: #{res.code} #{res.body}") unless success
    { success: }
  rescue => e
    Rails.logger.error("SenderService: #{e.class}: #{e.message}")
    { success: false }
  end
end

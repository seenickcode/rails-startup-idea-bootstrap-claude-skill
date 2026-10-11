# Thin nil-guarding wrapper over the PostHog client ($posthog, prod-only).
class Analytics
  def self.capture(distinct_id:, event:, properties: {})
    return unless $posthog
    $posthog.capture(distinct_id:, event:, properties:)
  rescue => e
    Rails.logger.error("Analytics: #{e.class}: #{e.message}")
  end
end

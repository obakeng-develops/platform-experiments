require "test_helper"

class ElectricityMeterApiTest < ActionDispatch::IntegrationTest
  setup do
    Ledger.reset!
    Rails.cache.clear
    @utility_id = SecureRandom.uuid
    @meter_id = SecureRandom.uuid

    post "/utilities", params: {
      utility: { id: @utility_id, name: "Cape Town Power", tariff_micros_per_wh: 300 }
    }, as: :json
    assert_response :created

    post "/meters", params: {
      meter: { id: @meter_id, utility_id: @utility_id, reference: "meter-1" }
    }, as: :json
    assert_response :created
  end

  test "a reading moves energy and prepaid money atomically" do
    top_up(3_000)
    reading_id = SecureRandom.uuid

    post_reading(reading_id, 4)
    assert_response :created
    assert_equal "created", response.parsed_body.dig("results", 0, "status")
    assert_equal 1_200, response.parsed_body.dig("results", 0, "charge_micros")

    get "/meters/#{@meter_id}"
    assert_response :success
    assert_equal 4, response.parsed_body["consumption_wh"]
    assert_equal 1_800, response.parsed_body["prepaid_balance_micros"]

    get "/meter_readings/#{reading_id}"
    assert_response :success
  end

  test "replaying a reading has one financial effect" do
    top_up(3_000)
    reading_id = SecureRandom.uuid

    post_reading(reading_id, 4)
    post_reading(reading_id, 4)

    assert_response :created
    assert_equal "exists", response.parsed_body.dig("results", 0, "status")
    get "/meters/#{@meter_id}"
    assert_equal 4, response.parsed_body["consumption_wh"]
    assert_equal 1_800, response.parsed_body["prepaid_balance_micros"]
  end

  test "reusing an id with different data is rejected" do
    top_up(3_000)
    reading_id = SecureRandom.uuid

    post_reading(reading_id, 4)
    post_reading(reading_id, 5)

    assert_response :conflict
    assert_equal "idempotency_conflict", response.parsed_body.dig("error", "code")
  end

  test "insufficient funds posts neither side of a reading" do
    reading_id = SecureRandom.uuid

    post_reading(reading_id, 1)

    assert_response :created
    assert_equal "insufficient_funds", response.parsed_body.dig("results", 0, "status")
    get "/meter_readings/#{reading_id}"
    assert_response :not_found

    get "/meters/#{@meter_id}"
    assert_equal 0, response.parsed_body["consumption_wh"]
    assert_equal 0, response.parsed_body["prepaid_balance_micros"]
  end

  test "event lookup returns the stable public representation" do
    top_up(3_000)
    reading_id = SecureRandom.uuid
    post_reading(reading_id, 4)

    get "/meter_readings/#{reading_id}"

    assert_response :success
    assert_equal({
      "id" => reading_id,
      "type" => "meter_reading",
      "consumption_wh" => 4,
      "charge_micros" => 1_200
    }, response.parsed_body)
  end

  test "invalid quantities are rejected before reaching the ledger" do
    post_reading(SecureRandom.uuid, 0)

    assert_response :unprocessable_entity
    assert_equal "invalid_request", response.parsed_body.dig("error", "code")
  end

  test "provisioning retries return the existing resources" do
    post "/utilities", params: {
      utility: { id: @utility_id, name: "Cape Town Power", tariff_micros_per_wh: 300 }
    }, as: :json
    assert_response :success

    post "/meters", params: {
      meter: { id: @meter_id, utility_id: @utility_id, reference: "meter-1" }
    }, as: :json
    assert_response :success
  end

  private

  def top_up(amount)
    post "/top_ups", params: {
      top_up: { id: SecureRandom.uuid, meter_id: @meter_id, amount_micros: amount }
    }, as: :json
    assert_response :created
  end

  def post_reading(id, consumption_wh)
    post "/meter_readings", params: {
      readings: [ { id:, meter_id: @meter_id, consumption_wh: } ]
    }, as: :json
  end
end

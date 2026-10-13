require "test_helper"

class Payments::SignerTest < ActiveSupport::TestCase
  setup do
    @key = OpenSSL::PKey::RSA.new(2048)
    @private_pem = @key.private_to_pem
    @public_pem = @key.public_to_pem
  end

  test "canonical json sorts keys recursively and is compact" do
    body = { "b" => 1, "a" => { "z" => [ { "d" => 1, "c" => 2 } ], "y" => nil } }

    assert_equal '{"a":{"y":null,"z":[{"c":2,"d":1}]},"b":1}', Payments::Signer.canonical_json(body)
  end

  test "javascript variant writes whole-number floats as integers" do
    assert_equal '{"amount":150000,"fee":5000,"pct":3.33}',
                 Payments::Signer.canonical_json_js({ "pct" => 3.33, "fee" => 5000.0, "amount" => 150000 })
  end

  test "signature round-trips and rejects tampering" do
    sig = Payments::Signer.sign("hello", @private_pem)

    assert_not_includes sig, "\n"
    assert Payments::Signer.valid?("hello", sig, @public_pem)
    assert_not Payments::Signer.valid?("hellO", sig, @public_pem)
    assert_not Payments::Signer.valid?("hello", "not base64!", @public_pem)
  end

  test "matching_variant tries raw, canonical and javascript forms" do
    raw = '{ "fee": 5000.0, "amount": 150000 }'

    assert_equal :raw, Payments::Signer.matching_variant(raw, Payments::Signer.sign(raw, @private_pem), @public_pem)
    assert_equal :canonical, Payments::Signer.matching_variant(raw, Payments::Signer.sign('{"amount":150000,"fee":5000.0}', @private_pem), @public_pem)
    assert_equal :canonical_js, Payments::Signer.matching_variant(raw, Payments::Signer.sign('{"amount":150000,"fee":5000}', @private_pem), @public_pem)
    assert_nil Payments::Signer.matching_variant(raw, Payments::Signer.sign("other", @private_pem), @public_pem)
  end
end

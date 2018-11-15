defmodule TwitterVerify do
  require Logger
  def verify_credentials(access_token, access_token_secret) do
    request(:get, "https://api.twitter.com/1.1/account/verify_credentials.json", access_token, access_token_secret)
  end

  def request(method, url, access_token, access_token_secret) do
    oauth_request(method, url, [],
      Application.get_env(:twitter_verify, :consumer_key),
      Application.get_env(:twitter_verify, :consumer_secret),
      access_token, access_token_secret)
    |> case do
      {:ok, body} ->
        body
      error ->
        case Ejoy.Jiffy.decode(error) do
          {:ok, ret} -> ret
          _ -> error
        end
     end
    |> verify_response()
  end

  def oauth_request(:get, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    Oauth.oauth_get(url, params, consumer_key, consumer_secret, access_token, access_token_secret, [])
  end

  def verify_response(body) when is_map(body) do
    case Map.get(body, :errors, nil) || Map.get(body, :error, nil) do
      nil -> body
      error -> error
    end
  end

  def verify_response(body) do
      body
  end

end

defmodule Oauth do
  def oauth_get(url, params, consumer_key, consumer_secret, access_token, access_token_secret, _options) do
    signed_params = get_signed_params(
      "get", url, params, consumer_key, consumer_secret, access_token, access_token_secret)
    encoded_params = URI.encode_query(signed_params)
    Ejoy.HttpRPC.json_get(url <> "?" <> encoded_params, %{})
  end

  defp get_signed_params(method, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    credentials = OAuther.credentials(
        consumer_key: consumer_key,
        consumer_secret: consumer_secret,
        token: access_token,
        token_secret: access_token_secret
    )
    OAuther.sign(method, url, params, credentials)
  end
end
